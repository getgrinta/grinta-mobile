import ComposableArchitecture
import DeveloperToolsSupport
import Foundation

extension SuggestionAggregator: DependencyKey {
    static let liveValue: Self = {
        let remoteSuggestionCache = RemoteSuggestionCache()

        return Self(
            suggestions: { remoteSuggestionClient, websiteMetadataClient, historyArchive, query in
                let historyItems = await (try? historyArchive.retrieve()) ?? []
                var metadata: [String: WebsiteMetadata] = [:]

                for historyItem in historyItems where historyItem.query.isWebsiteUrl {
                    guard let metadataItem = await (try? websiteMetadataClient.retrieve(hostname: historyItem.query.raw)) else { continue }

                    metadata[historyItem.query.canonicalHost] = metadataItem
                }

                return AsyncStream([SearchSuggestion].self) { continuation in
                    continuation.yield(SuggestionComposer.compose(history: historyItems, remote: [], query: query, metadata: metadata))

                    guard !query.isEmpty else {
                        continuation.finish()
                        return
                    }

                    let task = Task<Void, Never> { [metadata] in
                        if let cachedSuggestions = remoteSuggestionCache.retrieve(query: query.raw) {
                            continuation.yield(SuggestionComposer.compose(history: historyItems, remote: cachedSuggestions, query: query, metadata: metadata))
                            continuation.finish()
                            return
                        }

                        try? await Task.sleep(for: .seconds(1))

                        guard Task.isCancelled == false else {
                            continuation.finish()
                            return
                        }

                        let searchResults = await (try? remoteSuggestionClient.fetchSuggestions(query)) ?? []

                        let searchSuggestions = searchResults
                            .filter { $0.lowercased() != query.raw.lowercased() }
                            .map {
                                SearchSuggestion(title: $0, url: query.raw, image: .search, imageURL: nil, type: .search, origin: .suggested)
                            }

                        remoteSuggestionCache.store(query: query.raw, suggestions: searchSuggestions)

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

private enum SuggestionComposer {
    static func compose(
        history: [HistoryItem],
        remote: [SearchSuggestion],
        query: SearchQuery,
        metadata: [String: WebsiteMetadata]
    ) -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []

        if query.isEmpty == false {
            suggestions = [
                SearchSuggestion(title: query.raw, url: query.raw, image: .sparkles, imageURL: nil, type: .ai, origin: .suggested),
                SearchSuggestion(title: query.raw, url: query.raw, image: .stickyNote, imageURL: nil, type: .note, origin: .suggested),
            ]

            if query.isWebsiteUrl {
                let metadata = metadata[query.canonicalHost]
                suggestions.append(SearchSuggestion(title: metadata?.description ?? query.raw, url: query.raw, image: metadata == nil ? .globe : nil, imageURL: metadata?.favicon, type: .website, origin: .suggested))
            } else {
                suggestions.append(SearchSuggestion(title: query.raw, url: query.raw, image: .search, imageURL: nil, type: .search, origin: .suggested))
            }
        }

        let searchHistoryMatcher = SearchHistoryMatcher()
        searchHistoryMatcher.buildTrie(from: history)

        let matchingHistoryItems = searchHistoryMatcher.search(query: query.raw, limit: 10)
        let historySuggestions = matchingHistoryItems
            .map {
                // Clean this up...
                let metadataItem = metadata[$0.query.canonicalHost]

                return SearchSuggestion(
                    title: metadataItem?.title ?? $0.query.raw,
                    url: $0.query.raw,
                    image: .search,
                    imageURL: metadataItem?.favicon,
                    type: $0.query.isWebsiteUrl ? .website : .search,
                    origin: .history
                )
            }
            .sorted(by: { (a: SearchSuggestion, b: SearchSuggestion) in a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending })
            // display single item + (3 - no. of search suggestions - additional ones)
            .prefix(1 + max(0, 2 - suggestions.count))

        return suggestions + historySuggestions + remote
    }
}

struct SearchSuggestion: Equatable, Identifiable, Hashable {
    enum Origin {
        case suggested
        case history
    }

    let title: String
    let url: String
    let image: ImageResource?
    let imageURL: String?
    let type: SuggestionType
    let origin: Origin

    var id: Int {
        var hasher = Hasher()
        hasher.combine(type)
        hasher.combine(url)
        return hasher.finalize()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

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

actor RemoteSuggestionCache {
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

@DependencyClient
struct SuggestionAggregator {
    var suggestions: @Sendable (
        _ remoteSuggestionClient: RemoteSuggestionClient,
        _ websiteMetadataClient: WebsiteMetadataStoreClient,
        _ historyArchive: HistoryArchiveClient,
        _ query: SearchQuery
    ) async throws -> AsyncStream<[SearchSuggestion]>
}
