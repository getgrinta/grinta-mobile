import Foundation

final class LLMStreamingClient {
    private let endpoint: String
    private var urlSession: URLSession!
    private let apiKey: String

    final class SessionHandler: NSObject, URLSessionDataDelegate {
        let output: (@Sendable (String) -> Void)?

        init(output: @Sendable @escaping (String) -> Void) {
            self.output = output
        }

        func urlSession(_: URLSession, dataTask _: URLSessionDataTask, didReceive data: Data) {
            guard let chunk = String(data: data, encoding: .utf8) else { return }
            processStream(data: chunk)
        }

        private func processStream(data: String) {
            let lines = data.components(separatedBy: "\n")

            for line in lines {
                if line.starts(with: "data:") {
                    let jsonData = line.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)

                    if jsonData == "[DONE]" {
                        print("\nStream Ended.")
                        return
                    }

                    guard let chunkData = jsonData.data(using: .utf8) else { continue }

                    do {
                        let message = try JSONDecoder().decode(ChatCompletionStreamChunk.self, from: chunkData)

                        if let content = message.choices.first?.delta.content {
                            output?(content)
                        }
                    } catch {
                        print("JSON Parsing Error: \(error)")
                    }
                }
            }
        }
    }

    var output: (@Sendable (String) -> Void)?

    private var handler: SessionHandler!

    init(endpoint: String, apiKey: String) {
        self.endpoint = endpoint
        self.apiKey = apiKey

        let config = URLSessionConfiguration.default
        let handler = SessionHandler { [output] out in
            output?(out)
        }
        urlSession = URLSession(configuration: config, delegate: handler, delegateQueue: nil)
    }

    func startStreamWithMessage(_ message: String) {
        let request = RequestBuilder().createLLMStreamRequest(
            endpoint: endpoint,
            message: message,
            bearer: apiKey
        )
        let task = urlSession.dataTask(with: request)
        task.resume()
    }

    func sendMessage(_ message: String) async throws -> String {
        let request = RequestBuilder().createLLMStreamRequest(
            endpoint: endpoint,
            message: message,
            bearer: apiKey
        )
        let (data, response) = try await urlSession.data(for: request)

        guard ((response as? HTTPURLResponse)?.statusCode ?? -1) <= 299 else { return "" }
        guard let string = String(data: data, encoding: .utf8) else { return "" }

        return string
    }
}

struct ChatInput: Encodable {
    let model: String
    let store: Bool
    let stream: Bool
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

struct ChatCompletionStreamChunk: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let delta: Delta
}

struct Delta: Codable {
    let content: String
}
