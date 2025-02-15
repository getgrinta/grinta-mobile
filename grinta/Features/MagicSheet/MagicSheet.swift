import ComposableArchitecture
import SwiftUI

@Reducer
struct MagicSheet {
    @ObservableState
    struct State {
        // When heights are finalized - create specific variables for them
        static let presentationDetents: Set<PresentationDetent> = [
            .height(40),
            .height(100),
            .height(200),
            .medium,
        ]

        var searchText = ""
        var presentationDetent: PresentationDetent = .medium
        var mode: Mode = .full
        var searchBarAccessoriesVisible = true
        var searchSuggestions: [SearchSuggestion] = []

        enum Field: Hashable, Sendable {
            case search
        }

        var focusedField: Field? = .search

        enum Mode: Equatable {
            case minimized, full
        }

        var searchBarContainsText: Bool {
            !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    enum Action: BindableAction {
        enum Delegate {
            case openURL(URL)
        }

        case searchTextChanged(String)
        case changePresentationDetent(PresentationDetent)
        case clearSearch
        case miniViewExpandTapped
        case performSuggestion(SearchSuggestion)
        case archiveItem(HistoryItem)
        case submitSearch
        case sheetSizeChanged(CGSize)
        case presentationDetentChanged
        case replaceSearchSuggestions([SearchSuggestion])
        case binding(BindingAction<State>)
        case delegate(Delegate)
    }

    @Dependency(HistoryArchiveClient.self) var historyArchive
    @Dependency(SearchSuggestionClient.self) var searchSuggestionClient
    @Dependency(StartPageClient.self) var startPageClient
    @Dependency(WebsiteMetadataStoreClient.self) var websiteMetadataClient

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.presentationDetent):
                return .send(.presentationDetentChanged)

            case .presentationDetentChanged:
                switch state.presentationDetent {
                case .height(40):
                    state.mode = .minimized
                default:
                    state.mode = .full
                }

                return .none

            case let .searchTextChanged(newText):
                guard state.searchText != newText else { return .none }

                let query = SearchQuery(newText)
                state.searchText = newText
                state.searchBarAccessoriesVisible = query.isEmpty

                return .run { [searchSuggestionClient] send in
                    for await suggestions in try await searchSuggestionClient.suggestions(startPageClient: startPageClient, websiteMetadataClient: websiteMetadataClient, historyArchive: historyArchive, query: query) {
                        await send(.replaceSearchSuggestions(suggestions))
                    }
                }
                .cancellable(id: SearchSuggestionSearchCancelId(), cancelInFlight: true)

            case let .replaceSearchSuggestions(suggestions):
                state.searchSuggestions = suggestions
                return .none

            case .miniViewExpandTapped:
                state.focusedField = .search
                return .merge(
                    .send(.changePresentationDetent(.medium)),
                    .run { [searchSuggestionClient, state] send in
                        let query = SearchQuery(state.searchText)
                        for await suggestions in try await searchSuggestionClient.suggestions(
                            startPageClient: startPageClient,
                            websiteMetadataClient: websiteMetadataClient,
                            historyArchive: historyArchive,
                            query: query
                        ) {
                            await send(.replaceSearchSuggestions(suggestions))
                        }
                    }
                    .cancellable(id: SearchSuggestionSearchCancelId(), cancelInFlight: true)
                )

            case .sheetSizeChanged:
                return .none

            case let .changePresentationDetent(detent):
                state.presentationDetent = detent
                return .send(.presentationDetentChanged)

            case .clearSearch:
                return .send(.searchTextChanged(""))

            case let .performSuggestion(suggestion):
                switch suggestion.type {
                case .ai:
                    return .none
                case .note:
                    return .none
                case .website:
                    return .merge(
                        // .send(.archiveItem(HistoryItem(query: suggestion.title, type: .website))),
                        .send(.changePresentationDetent(.height(40)), animation: .easeInOut),
                        // .send(.clearSearch),
                        .openURL(suggestion.url)
                    )
                case .search:
                    // Move to separate action
                    let percentEncodedQuery = suggestion.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? suggestion.title
                    let urlToOpen = "https://www.startpage.com/do/search?q=\(percentEncodedQuery)"
                    return .merge(
                        // .send(.archiveItem(HistoryItem(query: suggestion.title, type: .search))),
                        .openURL(urlToOpen),
                        .send(.clearSearch), .send(.changePresentationDetent(.height(40)))
                    )
                }

            case .submitSearch:
                let isWebsiteUrl = SearchQuery(state.searchText).isWebsiteUrl

                let urlToOpen: String

                // If search term is a website url - open website
                // Else open search website with that query
                if isWebsiteUrl {
                    urlToOpen = state.searchText
                } else {
                    let percentEncodedQuery = state.searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? state.searchText
                    urlToOpen = "https://www.startpage.com/do/search?q=\(percentEncodedQuery)"
                }

                return .concatenate(
                    .merge(
                        .send(.archiveItem(HistoryItem(query: state.searchText, type: isWebsiteUrl ? .website : .search))),
                        .send(.changePresentationDetent(.height(40))),
                        .openURL(urlToOpen),
                        .run { _ in
                            await UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
                        }
                    ),
                    .run { send in
                        try await Task.sleep(for: .milliseconds(500))
                        await send(.changePresentationDetent(.height(40)))
                    },
                    .send(.clearSearch)
                )

            case let .archiveItem(item):
                return .run { _ in
                    try await historyArchive.store(item: item)
                }

            case .binding:
                return .none

            case .delegate:
                return .none
            }
        }
    }

    private struct SearchSuggestionSearchCancelId: Hashable {}
}

private extension Effect where Action == MagicSheet.Action {
    static func openURL(_ url: String) -> Self {
        var urlString = url
        if !urlString.hasPrefix("http"), !urlString.hasPrefix("https") {
            urlString = "https://www." + urlString
        }

        guard let url = URL(string: urlString) else { return .none }
        return .send(.delegate(.openURL(url)))
    }
}
