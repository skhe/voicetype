import Foundation

struct TranscriptionDebugEntry: Encodable {
    let timestamp: Date
    let language: String
    let model: String
    let audioSizeBytes: Int64
    let preservedAudioPath: String?
    let rawTranscription: String
    let transcribeDurationSeconds: Double
    let postProcessingEnabled: Bool
    let openAISystemPrompt: String?
    let openAIUserPrompt: String?
    let openAIResponse: String?
    let postProcessDurationSeconds: Double?
    let finalOutput: String
}

actor DebugLogger {
    static let shared = DebugLogger()

    private var logsDirectory: URL {
        get throws {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = appSupport.appendingPathComponent("VoiceType/DebugLogs")
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }
    }

    func save(entry: TranscriptionDebugEntry, audioURL: URL?) {
        guard let dir = try? logsDirectory else { return }
        Task.detached {
            do {
                let dir = dir
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
                let timestamp = formatter.string(from: entry.timestamp)

                // Save JSON log
                let logURL = dir.appendingPathComponent("transcription-\(timestamp).json")
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(entry)
                try data.write(to: logURL)

                // Preserve audio file alongside the log
                if let audioURL, FileManager.default.fileExists(atPath: audioURL.path) {
                    let audioExt = audioURL.pathExtension
                    let audioDestURL = dir.appendingPathComponent("audio-\(timestamp).\(audioExt)")
                    try FileManager.default.copyItem(at: audioURL, to: audioDestURL)
                }

                print("[VoiceType] Debug log saved: \(logURL.lastPathComponent)")
            } catch {
                print("[VoiceType] Debug log save failed: \(error)")
            }
        }
    }
}
