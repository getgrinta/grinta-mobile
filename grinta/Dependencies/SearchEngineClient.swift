import ComposableArchitecture
import Foundation

enum SearchEngine {
    case startPage
    case duckDuckGo
    case brave
    case ecosia
    case google
    case bing

    var baseURL: String {
        switch self {
        case .startPage:
            "https://www.startpage.com/do/search"
        case .duckDuckGo:
            "https://duckduckgo.com/"
        case .brave:
            "https://search.brave.com/search"
        case .ecosia:
            "https://www.ecosia.org/search"
        case .google:
            "https://www.google.com/search"
        case .bing:
            "https://www.bing.com/search"
        }
    }

    var queryParameter: String {
        switch self {
        case .startPage, .google, .bing, .ecosia:
            "q"
        case .duckDuckGo:
            "q"
        case .brave:
            "q"
        }
    }
}

@DependencyClient
struct SearchEngineClient {
    var searchURL: @Sendable (SearchEngine, SearchQuery) -> URL?
}

extension SearchEngineClient: DependencyKey {
    static let liveValue = Self(
        searchURL: { engine, query in
            var components = URLComponents(string: engine.baseURL)
            components?.queryItems = [
                URLQueryItem(name: engine.queryParameter, value: query.raw),
            ]
            return components?.url
        }
    )

    static let testValue = Self(
        searchURL: unimplemented("\(Self.self).searchURL", placeholder: URL(string: "www.google.com"))
    )
}

extension DependencyValues {
    var searchEngine: SearchEngineClient {
        get { self[SearchEngineClient.self] }
        set { self[SearchEngineClient.self] = newValue }
    }
}
