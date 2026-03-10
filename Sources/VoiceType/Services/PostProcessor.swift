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

struct PostProcessorDetail {
    let text: String
    let systemPrompt: String
    let userPrompt: String
    let rawResponse: String
}

actor PostProcessor {
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    private let chineseSystemPrompt = """
    你是一个语音转文字后处理器。请对原始转录文本进行清理：
    1. 去除填充词（嗯、那个、就是、对对对、然后然后等）
    2. 如果说话者在句子中途进行了更正，只保留最终版本
    3. 去除不必要的重复
    4. 添加适当的标点符号和段落分隔
    5. 完全保留说话者的原意和语气
    6. 只输出清理后的文本，不要任何解释
    """

    private let englishSystemPrompt = """
    You are a speech-to-text post-processor. Clean up the raw transcription by:
    1. Remove filler words (um, uh, like, you know)
    2. When the speaker corrects themselves mid-sentence, keep ONLY the final intended version
    3. Remove unnecessary repetitions
    4. Add proper punctuation and paragraph breaks
    5. Preserve the speaker's original meaning and tone exactly
    6. Output ONLY the cleaned text, no explanations
    """

    func process(rawText: String, apiKey: String, language: String) async throws -> String {
        try await processWithDetail(rawText: rawText, apiKey: apiKey, language: language).text
    }

    func processWithDetail(rawText: String, apiKey: String, language: String) async throws -> PostProcessorDetail {
        let systemPrompt = language == "zh" ? chineseSystemPrompt : englishSystemPrompt
        let userPrompt = "原始转录：\n\(rawText)"
        let request = OpenAIRequest(
            model: "gpt-4o-mini",
            messages: [
                OpenAIMessage(role: "system", content: systemPrompt),
                OpenAIMessage(role: "user", content: userPrompt)
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
        let rawResponse = String(data: data, encoding: .utf8) ?? ""
        return PostProcessorDetail(
            text: content.trimmingCharacters(in: .whitespacesAndNewlines),
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            rawResponse: rawResponse
        )
    }
}
