import Foundation
import WhisperKit

actor TranscriptionService {
    private var whisper: WhisperKit?
    private var loadedModel: String?

    func transcribe(audioURL: URL, model: String, language: String) async throws -> String {
        let whisper = try await loadModel(model)
        let options = DecodingOptions(
            language: language,
            noSpeechThreshold: 0.3,
            logProbThreshold: -1.5,
            firstTokenLogProbThreshold: -2.5,
            compressionRatioThreshold: 3.0
        )
        let results = try await whisper.transcribe(audioPath: audioURL.path, decodeOptions: options)
        return results.map(\.text).joined(separator: " ").trimmingCharacters(in: .whitespaces)
    }

    private func loadModel(_ model: String) async throws -> WhisperKit {
        if let existing = whisper, loadedModel == model {
            return existing
        }
        let kit = try await WhisperKit(model: model)
        self.whisper = kit
        self.loadedModel = model
        return kit
    }
}
