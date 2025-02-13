import ComposableArchitecture
import DeveloperToolsSupport
import Foundation

enum SuggestionType {
    case ai
    case note
    case website
    case search

    var title: String {
        switch self {
        case .ai:
            L10n.aiAsk
        case .note:
            L10n.noteCreate
        case .website:
            L10n.searchWeb
        case .search:
            L10n.search
        }
    }
}

private actor SuggestionCache {
    private var cache: [String: [SearchSuggestion]] = [:]
    private let capacity = 10

    func store(query: String, suggestions: [SearchSuggestion]) {
        if suggestions.count > 0 {
            cache[query] = Array(suggestions.prefix(capacity))
        }
    }

    func retrieve(query: String) -> [SearchSuggestion]? {
        cache[query]
    }
}

struct SearchSuggestion: Equatable, Identifiable {
    var id: Int {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(type)
        return hasher.finalize()
    }

    let title: String
    let image: ImageResource?
    let type: SuggestionType
}

@DependencyClient
struct SearchSuggestionClient {
    var suggestions: @Sendable (_ startPageClient: StartPageClient, _ query: SearchQuery) async throws -> AsyncStream<[SearchSuggestion]>
}

enum SearchSuggestionClientError: Error {
    case noResponses
}
extension SearchSuggestionClient: DependencyKey {
    static let liveValue: Self = {
        let remoteSuggestionCache = SuggestionCache()

        return SearchSuggestionClient(
            suggestions: { startPageClient, query in
                AsyncStream([SearchSuggestion].self) { continuation in
                    guard !query.isEmpty else {
                        continuation.yield([])
                        continuation.finish()
                        return
                    }

                    var suggestions: [SearchSuggestion] = [
                        SearchSuggestion(title: query.term, image: .sparkles, type: .ai),
                        SearchSuggestion(title: query.term, image: .stickyNote, type: .note)
                    ]

                    if query.isWebsiteUrl {
                        suggestions.append(SearchSuggestion(title: query.term, image: .globe, type: .website))
                    }

                    continuation.yield(suggestions)

                    let task = Task<Void, Never> {
                        if let cachedSuggestions = remoteSuggestionCache.retrieve(query: query.term) {
                            continuation.yield(suggestions + cachedSuggestions)
                            continuation.finish()
                            return
                        }

                        try? await Task.sleep(for: .seconds(1))

                        guard Task.isCancelled == false else {
                            continuation.finish()
                            return
                        }

                        let searchResults = await (try? startPageClient.fetchSuggestions(query)) ?? []

                        let searchSuggestions = searchResults
                            .filter { $0.lowercased() != query.term.lowercased() }
                            .map {
                                SearchSuggestion(title: $0, image: .search, type: .search)
                            }

                        remoteSuggestionCache.store(query: query.term, suggestions: searchSuggestions)

                        continuation.yield(suggestions + searchSuggestions)
                        continuation.finish()
                    }

                    continuation.onTermination = { @Sendable _ in
                        task.cancel()
                    }
                }
            }
        )
    }()
}
