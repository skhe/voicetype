import Foundation
import AVFoundation

enum AudioRecorderError: LocalizedError {
    case permissionDenied
    case setupFailed(String)
    case notRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "麦克风权限被拒绝。请在系统设置中允许 VoiceType 使用麦克风。"
        case .setupFailed(let msg):
            return "录音配置失败: \(msg)"
        case .notRecording:
            return "当前未在录音"
        }
    }
}

actor AudioRecorder {
    private var engine: AVAudioEngine?
    private var outputFile: AVAudioFile?
    private var outputURL: URL?
    private var isRecording = false

    func start() async throws {
        let permission = await requestMicrophonePermission()
        guard permission else { throw AudioRecorderError.permissionDenied }

        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: 16000,
                                   channels: 1,
                                   interleaved: false)!

        // Resample from native input format to 16kHz mono
        let inputFormat = input.outputFormat(forBus: 0)
        guard let converter = AVAudioConverter(from: inputFormat, to: format) else {
            throw AudioRecorderError.setupFailed("无法创建音频转换器")
        }

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        let outputFile = try AVAudioFile(forWriting: tmpURL,
                                          settings: format.settings,
                                          commonFormat: .pcmFormatFloat32,
                                          interleaved: false)
        self.outputURL = tmpURL
        self.outputFile = outputFile
        self.engine = engine

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }
            Task {
                await self.convertAndWrite(buffer: buffer, converter: converter, format: format)
            }
        }

        try engine.start()
        isRecording = true
    }

    func stop() async throws -> URL {
        guard isRecording, let engine, let outputURL else {
            throw AudioRecorderError.notRecording
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        outputFile = nil
        self.engine = nil
        isRecording = false
        return outputURL
    }

    private func convertAndWrite(buffer: AVAudioPCMBuffer,
                                  converter: AVAudioConverter,
                                  format: AVAudioFormat) {
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) *
                                           format.sampleRate /
                                           buffer.format.sampleRate)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format,
                                                      frameCapacity: frameCount) else { return }
        var error: NSError?
        var consumedAll = false
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if consumedAll {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            consumedAll = true
            return buffer
        }
        if error == nil {
            try? outputFile?.write(from: convertedBuffer)
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                continuation.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            default:
                continuation.resume(returning: false)
            }
        }
    }
}
