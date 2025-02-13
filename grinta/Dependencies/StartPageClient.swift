import ComposableArchitecture
import Foundation

struct WebsiteMetadata: Decodable {
    let title: String?
    let description: String?
    let url: String
}

enum StartPageClientError: Error {
    case invalidURL
    case networkError(Error)
    case dataDecodingFailed
}

// Codable struct for StartPage suggestions response
struct StartPageSuggestions: Decodable {
    let query: String
    let suggestions: [String]

    // Custom decoding to map JSON array to structured data
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.query = try container.decode(String.self)
        self.suggestions = try container.decode([String].self)
    }
}

@DependencyClient
struct StartPageClient {
    var fetchMetadata: @Sendable (_ query: SearchQuery) async throws -> [WebsiteMetadata]
    var fetchSuggestions: @Sendable (_ query: SearchQuery) async throws -> [String]
}

extension StartPageClient: DependencyKey {
    static let liveValue: Self = .init(
        fetchMetadata: { query in
            guard let url = URL(string: "https://www.startpage.com/sp/search?query=\(query)") else {
                throw StartPageClientError.invalidURL
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw StartPageClientError.networkError(NSError(domain: "StartPageClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil))
            }

            do {
                let metadata = try JSONDecoder().decode([WebsiteMetadata].self, from: data)
                return metadata
            } catch {
                throw StartPageClientError.dataDecodingFailed
            }
        },
        fetchSuggestions: { query in
            guard let url = URL(string: "https://www.startpage.com/osuggestions?q=\(query)") else {
                throw StartPageClientError.invalidURL
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw StartPageClientError.networkError(NSError(domain: "StartPageClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: nil))
            }

            do {
                let decodedResponse = try JSONDecoder().decode(StartPageSuggestions.self, from: data)
                return decodedResponse.suggestions
            } catch {
                throw StartPageClientError.dataDecodingFailed
            }
        }
    )
}
