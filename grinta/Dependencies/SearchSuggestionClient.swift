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
            L10n.website
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

enum SuggestionOrigin {
    case suggested
    case history
}

struct SearchSuggestion: Equatable, Identifiable {
    var id: Int {
        var hasher = Hasher()
        hasher.combine(title)
        hasher.combine(type)
        return hasher.finalize()
    }

    let title: String
    let url: String
    let image: ImageResource?
    let imageURL: String?
    let type: SuggestionType
    let origin: SuggestionOrigin
}

@DependencyClient
struct SearchSuggestionClient {
    var suggestions: @Sendable (
        _ startPageClient: StartPageClient,
        _ websiteMetadataClient: WebsiteMetadataStoreClient,
        _ historyArchive: HistoryArchiveClient,
        _ query: SearchQuery
    ) async throws -> AsyncStream<[SearchSuggestion]>
}

enum SearchSuggestionClientError: Error {
    case noResponses
}

extension SearchSuggestionClient: DependencyKey {
    static let liveValue: Self = {
        let remoteSuggestionCache = SuggestionCache()

        return SearchSuggestionClient(
            suggestions: { startPageClient, websiteMetadataClient, historyArchive, query in
                let historyItems = await (try? historyArchive.retrieve()) ?? []
                var metadata: [String: WebsiteMetadata] = [:]

                for historyItem in historyItems where SearchQuery(historyItem.query).isWebsiteUrl {
                    guard let metadataItem = await (try? websiteMetadataClient.retrieve(hostname: historyItem.query)) else { continue }

                    metadata[historyItem.query.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "www.", with: "")] = metadataItem
                }

                return AsyncStream([SearchSuggestion].self) { continuation in
                    continuation.yield(SuggestionComposer.compose(history: historyItems, remote: [], query: query, metadata: metadata))

                    guard !query.isEmpty else {
                        continuation.finish()
                        return
                    }

                    let task = Task<Void, Never> { [metadata] in
                        if let cachedSuggestions = remoteSuggestionCache.retrieve(query: query.term) {
                            continuation.yield(SuggestionComposer.compose(history: historyItems, remote: cachedSuggestions, query: query, metadata: metadata))
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
                                SearchSuggestion(title: $0, url: query.term, image: .search, imageURL: nil, type: .search, origin: .suggested)
                            }

                        remoteSuggestionCache.store(query: query.term, suggestions: searchSuggestions)

                        continuation.yield(SuggestionComposer.compose(history: historyItems, remote: searchSuggestions, query: query, metadata: metadata))

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

enum SuggestionComposer {
    static func compose(
        history: [HistoryItem],
        remote: [SearchSuggestion],
        query: SearchQuery,
        metadata: [String: WebsiteMetadata]
    ) -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []

        if query.isEmpty == false {
            suggestions = [
                SearchSuggestion(title: query.term, url: query.term, image: .sparkles, imageURL: nil, type: .ai, origin: .suggested),
                SearchSuggestion(title: query.term, url: query.term, image: .stickyNote, imageURL: nil, type: .note, origin: .suggested),
            ]
        }

        if query.isWebsiteUrl {
            let metadata = metadata[query.term.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "www.", with: "")]
            suggestions.append(SearchSuggestion(title: metadata?.description ?? query.term, url: query.term, image: metadata == nil ? .globe : nil, imageURL: metadata?.favicon, type: .website, origin: .suggested))
        }

        let searchHistoryMatcher = SearchHistoryMatcher()
        searchHistoryMatcher.buildTrie(from: history)

        let matchingHistoryItems = searchHistoryMatcher.search(query: query.term, limit: 3)
        let historySuggestions = matchingHistoryItems
            .map {
                // Clean this up...
                let metadataItem = metadata[$0.query.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "www.", with: "")]

                return SearchSuggestion(
                    title: metadataItem?.title ?? $0.query,
                    url: $0.query,
                    image: .search,
                    imageURL: metadataItem?.favicon,
                    type: SearchQuery($0.query).isWebsiteUrl ? .website : .search,
                    origin: .history
                )
            }
            .sorted(by: { (a: SearchSuggestion, b: SearchSuggestion) in a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending })
            // display single item + (3 - no. of search suggestions - additional ones)
            .prefix(1 + max(0, 2 - suggestions.count))

        return suggestions + historySuggestions + remote
    }
}
