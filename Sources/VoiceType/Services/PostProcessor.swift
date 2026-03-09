import Foundation

enum PostProcessorError: LocalizedError {
    case invalidResponse
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "OpenAI 返回了无效响应"
        case .apiError(let msg): return "OpenAI API 错误: \(msg)"
        }
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct OpenAIResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    struct APIError: Codable {
        let message: String
    }
    let choices: [Choice]?
    let error: APIError?
}

actor PostProcessor {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    private let systemPrompt = """
    You are a speech-to-text post-processor. Clean up the raw transcription by:
    1. Remove filler words (um, uh, like, you know, 那个, 嗯, 就是说)
    2. When the speaker corrects themselves mid-sentence, keep ONLY the final intended version
    3. Remove unnecessary repetitions
    4. Add proper punctuation and paragraph breaks
    5. Preserve the speaker's original meaning and tone exactly
    6. Output ONLY the cleaned text, no explanations
    """

    func process(rawText: String, apiKey: String) async throws -> String {
        let request = OpenAIRequest(
            model: "gpt-4o-mini",
            messages: [
                OpenAIMessage(role: "system", content: systemPrompt),
                OpenAIMessage(role: "user", content: "Raw transcription:\n\(rawText)")
            ],
            temperature: 0.2,
            maxTokens: 1024
        )

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            let apiResponse = try? JSONDecoder().decode(OpenAIResponse.self, from: data)
            throw PostProcessorError.apiError(apiResponse?.error?.message ?? "HTTP \(httpResponse.statusCode)")
        }

        let apiResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = apiResponse.choices?.first?.message.content else {
            throw PostProcessorError.invalidResponse
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
