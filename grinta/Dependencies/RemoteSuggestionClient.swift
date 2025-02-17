import ComposableArchitecture
import Foundation

enum StartPageClientError: Error {
    case invalidURL
    case networkError(Error)
    case dataDecodingFailed
}

struct StartPageSuggestions: Decodable {
    let query: String
    let suggestions: [String]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        query = try container.decode(String.self)
        suggestions = try container.decode([String].self)
    }
}

@DependencyClient
struct RemoteSuggestionClient {
    var fetchSuggestions: @Sendable (_ query: SearchQuery) async throws -> [String]
}

extension RemoteSuggestionClient: DependencyKey {
    static let liveValue: Self = .init(
        fetchSuggestions: { query in
            guard let url = URL(string: "https://www.startpage.com/osuggestions?q=\(query)") else {
                throw StartPageClientError.invalidURL
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            let httpResponse = response as? HTTPURLResponse
            guard let httpResponse, httpResponse.statusCode == 200 else {
                throw StartPageClientError.networkError(NSError(domain: "StartPageClient", code: httpResponse?.statusCode ?? -1, userInfo: nil))
            }

            do {
                let suggestionsResponse = try JSONDecoder().decode(StartPageSuggestions.self, from: data)
                return suggestionsResponse.suggestions
            } catch {
                throw StartPageClientError.dataDecodingFailed
            }
        }
    )
}
