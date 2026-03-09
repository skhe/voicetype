import Foundation
import SwiftUI
import KeyboardShortcuts

enum VoiceTypeError: LocalizedError {
    case timeout(Double)
    var errorDescription: String? {
        switch self {
        case .timeout(let s): return "操作超时（超过 \(Int(s)) 秒）"
        }
    }
}

// Actor that ensures a CheckedContinuation is resumed exactly once.
// Used by withHardTimeout to guarantee hard-timeout semantics regardless
// of whether the work task cooperates with Swift cooperative cancellation.
private actor ContinuationResolver<T: Sendable> {
    private var continuation: CheckedContinuation<T, Error>?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<T, Error>) {
        guard let c = continuation else { return }
        continuation = nil
        c.resume(with: result)
    }
}

enum RecordingStatus {
    case idle
    case starting     // transient: audioRecorder.start() in flight
    case recording
    case transcribing
    case postProcessing
    case error(String)

    var description: String {
        switch self {
        case .idle: return "空闲"
        case .starting: return "准备录音…"
        case .recording: return "录音中…"
        case .transcribing: return "转录中…"
        case .postProcessing: return "后处理中…"
        case .error(let msg): return "错误: \(msg)"
        }
    }

    var systemImageName: String {
        switch self {
        case .idle: return "mic"
        case .starting: return "mic"
        case .recording: return "mic.fill"
        case .transcribing: return "waveform"
        case .postProcessing: return "sparkles"
        case .error: return "exclamationmark.triangle"
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var status: RecordingStatus = .idle
    @Published var lastTranscription: String = ""

    // API key backed by Keychain; empty string means unset
    @Published var openAIKey: String = KeychainManager.load(key: "openAIKey") ?? "" {
        didSet {
            if openAIKey.isEmpty {
                KeychainManager.delete(key: "openAIKey")
            } else {
                KeychainManager.save(key: "openAIKey", value: openAIKey)
            }
        }
    }

    @Published var autoPaste: Bool = UserDefaults.standard.bool(forKey: "autoPaste") {
        didSet { UserDefaults.standard.set(autoPaste, forKey: "autoPaste") }
    }

    @Published var enablePostProcessing: Bool = {
        UserDefaults.standard.object(forKey: "enablePostProcessing") as? Bool ?? true
    }() {
        didSet { UserDefaults.standard.set(enablePostProcessing, forKey: "enablePostProcessing") }
    }

    @Published var whisperModel: String = UserDefaults.standard.string(forKey: "whisperModel") ?? "large-v3" {
        didSet { UserDefaults.standard.set(whisperModel, forKey: "whisperModel") }
    }

    // ISO 639-1 language code; default Chinese
    @Published var language: String = UserDefaults.standard.string(forKey: "language") ?? "zh" {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
    }

    private let audioRecorder = AudioRecorder()
    private let transcriptionService = TranscriptionService()
    private let postProcessor = PostProcessor()
    private let clipboardManager = ClipboardManager()

    // Toggle mode: press once to start, press again to stop.
    // Tracks the edge case where the second press arrives while .start() is still in flight.
    private var stopRequestedDuringStart = false

    init() {
        setupHotkey()
        NotificationManager.requestPermission()
    }

    private func setupHotkey() {
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch self.status {
                case .idle:
                    await self.startRecording()
                case .starting, .recording:
                    await self.stopRecording()
                default:
                    break
                }
            }
        }
    }

    func startRecording() async {
        guard case .idle = status else { return }
        stopRequestedDuringStart = false
        status = .starting

        do {
            try await audioRecorder.start()
        } catch {
            status = .error(error.localizedDescription)
            scheduleReset()
            return
        }

        // Key was already released while we were waiting for audioRecorder.start()
        if stopRequestedDuringStart {
            stopRequestedDuringStart = false
            await finishRecording()
            return
        }

        status = .recording
    }

    func stopRecording() async {
        switch status {
        case .starting:
            // Mark that stop was requested; startRecording() will handle it after .start() returns
            stopRequestedDuringStart = true
        case .recording:
            await finishRecording()
        default:
            break
        }
    }

    private func finishRecording() async {
        do {
            let audioURL = try await audioRecorder.stop()
            status = .transcribing

            let t0 = Date()
            print("[VoiceType] transcribing start")
            let rawText = try await withTimeout(seconds: 120) {
                try await self.transcriptionService.transcribe(audioURL: audioURL, model: self.whisperModel, language: self.language)
            }
            print("[VoiceType] transcribing done (\(String(format: "%.1f", Date().timeIntervalSince(t0)))s)")

            let finalText: String
            if enablePostProcessing && !openAIKey.isEmpty {
                status = .postProcessing
                let t1 = Date()
                print("[VoiceType] postProcessing start")
                finalText = try await withTimeout(seconds: 30) {
                    try await self.postProcessor.process(rawText: rawText, apiKey: self.openAIKey, language: self.language)
                }
                print("[VoiceType] postProcessing done (\(String(format: "%.1f", Date().timeIntervalSince(t1)))s)")
            } else {
                finalText = rawText
            }

            lastTranscription = finalText
            clipboardManager.copy(finalText)

            if autoPaste {
                try? await Task.sleep(nanoseconds: 100_000_000)
                clipboardManager.paste()
            }

            NotificationManager.show(text: finalText)
            status = .idle

            try? FileManager.default.removeItem(at: audioURL)
        } catch {
            print("[VoiceType] finishRecording error: \(error)")
            status = .error(error.localizedDescription)
            scheduleReset()
        }
    }

    // Hard timeout: the caller returns after `seconds` regardless of whether
    // `operation` has finished. The work runs in a detached task that may
    // continue briefly in the background, but the UI state is unblocked immediately.
    private func withTimeout<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let resolver = ContinuationResolver(continuation)

            // Work task — detached so it is not bound to the parent task's lifetime.
            Task.detached {
                do {
                    let result = try await operation()
                    await resolver.resume(with: .success(result))
                } catch {
                    await resolver.resume(with: .failure(error))
                }
            }

            // Timer task — fires unconditionally after `seconds`.
            Task.detached {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                await resolver.resume(with: .failure(VoiceTypeError.timeout(seconds)))
            }
        }
    }

    private func scheduleReset() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if case .error = self.status { self.status = .idle }
        }
    }
}

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.space, modifiers: .option))
}
