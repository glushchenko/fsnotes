//
//  AIService.swift
//  FSNotes
//
//  AI provider abstraction with streaming support for Claude and OpenAI APIs.
//

import Foundation

// MARK: - Data Models

struct ChatMessage {
    enum Role: String {
        case system, user, assistant
    }
    let role: Role
    let content: String
}

// MARK: - AI Provider Protocol

protocol AIProvider {
    func sendMessage(
        messages: [ChatMessage],
        noteContent: String,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping (Result<String, Error>) -> Void
    )
}

// MARK: - Anthropic (Claude) Provider

class AnthropicProvider: AIProvider {
    private let apiKey: String
    private let model: String
    private let endpoint: String

    init(apiKey: String, model: String = "claude-sonnet-4-5-20250514", endpoint: String = "https://api.anthropic.com") {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
    }

    func sendMessage(messages: [ChatMessage], noteContent: String, onToken: @escaping (String) -> Void, onComplete: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(endpoint)/v1/messages") else {
            onComplete(.failure(AIError.invalidURL))
            return
        }

        let systemPrompt = """
        You are a helpful writing assistant integrated into a note-taking app (FSNotes). \
        The user is editing a markdown note. You can help them review, edit, summarize, \
        translate, or transform the note content. When suggesting edits, provide the updated \
        text clearly. Be concise and helpful.

        Current note content:
        ---
        \(noteContent)
        ---
        """

        // Build messages array for Anthropic API
        var apiMessages: [[String: String]] = []
        for msg in messages where msg.role != .system {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "stream": true,
            "system": systemPrompt,
            "messages": apiMessages
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            onComplete(.failure(AIError.serializationFailed))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = jsonData

        let session = URLSession(configuration: .default, delegate: SSEDelegate(onToken: onToken, onComplete: onComplete, format: .anthropic), delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
    }
}

// MARK: - OpenAI Provider

class OpenAIProvider: AIProvider {
    private let apiKey: String
    private let model: String
    private let endpoint: String

    init(apiKey: String, model: String = "gpt-4o", endpoint: String = "https://api.openai.com") {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
    }

    func sendMessage(messages: [ChatMessage], noteContent: String, onToken: @escaping (String) -> Void, onComplete: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(endpoint)/v1/chat/completions") else {
            onComplete(.failure(AIError.invalidURL))
            return
        }

        let systemMessage: [String: String] = [
            "role": "system",
            "content": """
            You are a helpful writing assistant integrated into a note-taking app (FSNotes). \
            The user is editing a markdown note. You can help them review, edit, summarize, \
            translate, or transform the note content. When suggesting edits, provide the updated \
            text clearly. Be concise and helpful.

            Current note content:
            ---
            \(noteContent)
            ---
            """
        ]

        var apiMessages: [[String: String]] = [systemMessage]
        for msg in messages where msg.role != .system {
            apiMessages.append(["role": msg.role.rawValue, "content": msg.content])
        }

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": apiMessages
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            onComplete(.failure(AIError.serializationFailed))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let session = URLSession(configuration: .default, delegate: SSEDelegate(onToken: onToken, onComplete: onComplete, format: .openai), delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
    }
}

// MARK: - SSE Stream Parser

enum SSEFormat {
    case anthropic
    case openai
}

class SSEDelegate: NSObject, URLSessionDataDelegate {
    private var onToken: (String) -> Void
    private var onComplete: (Result<String, Error>) -> Void
    private var format: SSEFormat
    private var buffer = ""
    private var fullResponse = ""

    init(onToken: @escaping (String) -> Void, onComplete: @escaping (Result<String, Error>) -> Void, format: SSEFormat) {
        self.onToken = onToken
        self.onComplete = onComplete
        self.format = format
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        buffer += text

        while let lineEnd = buffer.range(of: "\n") {
            let line = String(buffer[buffer.startIndex..<lineEnd.lowerBound])
            buffer = String(buffer[lineEnd.upperBound...])

            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))

            if jsonStr == "[DONE]" {
                DispatchQueue.main.async {
                    self.onComplete(.success(self.fullResponse))
                }
                return
            }

            guard let jsonData = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

            var token: String?

            switch format {
            case .anthropic:
                if let type = json["type"] as? String {
                    if type == "content_block_delta",
                       let delta = json["delta"] as? [String: Any],
                       let text = delta["text"] as? String {
                        token = text
                    } else if type == "message_stop" {
                        DispatchQueue.main.async {
                            self.onComplete(.success(self.fullResponse))
                        }
                        return
                    } else if type == "error",
                              let error = json["error"] as? [String: Any],
                              let message = error["message"] as? String {
                        DispatchQueue.main.async {
                            self.onComplete(.failure(AIError.apiError(message)))
                        }
                        return
                    }
                }

            case .openai:
                if let choices = json["choices"] as? [[String: Any]],
                   let delta = choices.first?["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    token = content
                }
            }

            if let token = token {
                fullResponse += token
                DispatchQueue.main.async {
                    self.onToken(token)
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.onComplete(.failure(error))
            }
        } else if !fullResponse.isEmpty {
            DispatchQueue.main.async {
                self.onComplete(.success(self.fullResponse))
            }
        }
    }
}

// MARK: - Errors

enum AIError: LocalizedError {
    case invalidURL
    case serializationFailed
    case noAPIKey
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .serializationFailed: return "Failed to serialize request"
        case .noAPIKey: return "No API key configured. Go to Preferences > AI to set one."
        case .apiError(let msg): return "API error: \(msg)"
        }
    }
}

// MARK: - Provider Factory

class AIServiceFactory {
    static func createProvider() -> AIProvider? {
        let apiKey = UserDefaultsManagement.aiAPIKey
        guard !apiKey.isEmpty else { return nil }

        let provider = UserDefaultsManagement.aiProvider
        let model = UserDefaultsManagement.aiModel
        let endpoint = UserDefaultsManagement.aiEndpoint

        switch provider {
        case "openai":
            return OpenAIProvider(
                apiKey: apiKey,
                model: model.isEmpty ? "gpt-4o" : model,
                endpoint: endpoint.isEmpty ? "https://api.openai.com" : endpoint
            )
        default: // "anthropic" or default
            return AnthropicProvider(
                apiKey: apiKey,
                model: model.isEmpty ? "claude-sonnet-4-5-20250514" : model,
                endpoint: endpoint.isEmpty ? "https://api.anthropic.com" : endpoint
            )
        }
    }
}
