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
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH-mm-ss"
                let datePrefix = formatter.string(from: entry.timestamp)
                // UUID suffix ensures uniqueness even for same-second transcriptions
                let id = "\(datePrefix)-\(UUID().uuidString.prefix(8))"

                // Copy audio first so we can back-fill the path in the JSON log
                var savedAudioPath: String?
                if let audioURL, FileManager.default.fileExists(atPath: audioURL.path) {
                    let audioExt = audioURL.pathExtension
                    let audioDestURL = dir.appendingPathComponent("audio-\(id).\(audioExt)")
                    try FileManager.default.copyItem(at: audioURL, to: audioDestURL)
                    savedAudioPath = audioDestURL.path
                }

                // Rebuild entry with preservedAudioPath filled in
                let finalEntry = TranscriptionDebugEntry(
                    timestamp: entry.timestamp,
                    language: entry.language,
                    model: entry.model,
                    audioSizeBytes: entry.audioSizeBytes,
                    preservedAudioPath: savedAudioPath,
                    rawTranscription: entry.rawTranscription,
                    transcribeDurationSeconds: entry.transcribeDurationSeconds,
                    postProcessingEnabled: entry.postProcessingEnabled,
                    openAISystemPrompt: entry.openAISystemPrompt,
                    openAIUserPrompt: entry.openAIUserPrompt,
                    openAIResponse: entry.openAIResponse,
                    postProcessDurationSeconds: entry.postProcessDurationSeconds,
                    finalOutput: entry.finalOutput
                )

                let logURL = dir.appendingPathComponent("transcription-\(id).json")
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(finalEntry)
                try data.write(to: logURL)

                print("[VoiceType] Debug log saved: \(logURL.lastPathComponent)")
            } catch {
                print("[VoiceType] Debug log save failed: \(error)")
            }
        }
    }
}
