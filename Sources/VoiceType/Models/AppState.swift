import Foundation
import SwiftUI
import KeyboardShortcuts

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

            let rawText = try await transcriptionService.transcribe(audioURL: audioURL, model: whisperModel)

            let finalText: String
            if enablePostProcessing && !openAIKey.isEmpty {
                status = .postProcessing
                finalText = try await postProcessor.process(rawText: rawText, apiKey: openAIKey)
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
            status = .error(error.localizedDescription)
            scheduleReset()
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
