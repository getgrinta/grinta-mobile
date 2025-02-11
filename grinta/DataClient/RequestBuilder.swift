import Foundation

struct RequestBuilder {

    func createLLMStreamRequest(endpoint: String, message: String, bearer: String) -> URLRequest {
        let components = URLComponents(string: endpoint)!

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let input = ChatInput(
            model: "gpt-4o",
            store: false,
            stream: true,
            messages: [.init(role: "user", content: message)]
        )
        request.httpBody = try? JSONEncoder().encode(input)
        return request
    }
}
