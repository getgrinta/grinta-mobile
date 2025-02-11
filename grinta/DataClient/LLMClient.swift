import ComposableArchitecture
import Foundation

struct ChatOutput {
    let message: String
}

enum ClientError: Error {
    case invalidURL
    case dataDecodingFailed
}

@DependencyClient
struct LLMClient {
    var chat: @Sendable (_ endpoint: String, _ bearer: String, _ input: String) async throws -> ChatOutput
    var streamChat: @Sendable (_ endpoint: String, _ bearer: String, _ input: String) async throws -> AsyncStream<ChatOutput>
}

enum LLMClientError: Error {
    case noResponses
}

extension LLMClient: DependencyKey {
    static let liveValue: Self = {
        return Self(
            chat: { endpoint, bearer, input in
                let client = LLMStreamingClient(endpoint: endpoint, apiKey: bearer)
                return ChatOutput(message: try await client.sendMessage(input))
            },
            streamChat: { endpoint, bearer, input in
                let client = LLMStreamingClient(endpoint: endpoint, apiKey: bearer)

                return AsyncStream(ChatOutput.self) { continuation in
                    client.output = { message in
                        continuation.yield(ChatOutput(message: message))
                    }

                    client.startStreamWithMessage(input)
                }
            }
        )
    }()
}
