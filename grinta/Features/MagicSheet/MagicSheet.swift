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
        var isRecognizingVoice = false

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
        case stoppedRecognizingVoice
        case sheetSizeChanged(CGSize)
        case onAppear
        case presentationDetentChanged
        case voiceRecognitionTapped
        case replaceSearchSuggestions([SearchSuggestion])
        case binding(BindingAction<State>)
        case delegate(Delegate)
    }

    @Dependency(HistoryArchiveClient.self) var historyArchive
    @Dependency(SearchSuggestionClient.self) var searchSuggestionClient
    @Dependency(StartPageClient.self) var startPageClient
    @Dependency(WebsiteMetadataStoreClient.self) var websiteMetadataClient
    @Dependency(SpeechRecognitionClient.self) var speechRecognitionClient

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

            case .stoppedRecognizingVoice:
                state.isRecognizingVoice = false

                let searchQuery = SearchQuery(state.searchText)
                guard searchQuery.isEmpty == false else { return .none }

                let urlToOpen = "https://www.startpage.com/do/search?q=\(searchQuery.percentEncoded())"
                return .merge(
                    .send(.archiveItem(HistoryItem(query: searchQuery, type: .search))),
                    .openURL(.init(urlToOpen)),
                    .send(.clearSearch), .send(.changePresentationDetent(.height(40)))
                )

            case .voiceRecognitionTapped:
                guard state.isRecognizingVoice == false else { return .none }
                state.isRecognizingVoice = true
                return .run(operation: { send in
                    try await speechRecognitionClient.requestAuthorization()

                    for await message in try await speechRecognitionClient.startRecording() {
                        await send(.searchTextChanged(message))
                    }

                    await send(.stoppedRecognizingVoice, animation: .easeInOut)
                }, catch: { _, send in
                    await send(.stoppedRecognizingVoice, animation: .easeInOut)
                })

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
                        .send(.archiveItem(HistoryItem(query: SearchQuery(suggestion.title), type: .website))),
                        .send(.changePresentationDetent(.height(40)), animation: .easeInOut),
                        // .send(.clearSearch),
                        .openURL(.init(suggestion.url))
                    )
                case .search:
                    // Move to separate action
                    let percentEncodedQuery = SearchQuery(suggestion.title).percentEncoded()
                    let urlToOpen = "https://www.startpage.com/do/search?q=\(percentEncodedQuery)"
                    return .merge(
                        .send(.archiveItem(HistoryItem(query: SearchQuery(suggestion.title), type: .search))),
                        .openURL(.init(urlToOpen)),
                        .send(.clearSearch), .send(.changePresentationDetent(.height(40)))
                    )
                }

            case .onAppear:
                return .run { [searchSuggestionClient, state] send in
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

            case .submitSearch:
                let query = SearchQuery(state.searchText)

                let urlToOpen: String

                // If search term is a website url - open website
                // Else open search website with that query
                if query.isWebsiteUrl {
                    urlToOpen = state.searchText
                } else {
                    let percentEncodedQuery = query.percentEncoded()
                    urlToOpen = "https://www.startpage.com/do/search?q=\(percentEncodedQuery)"
                }

                return .concatenate(
                    .merge(
                        .send(.archiveItem(HistoryItem(query: query, type: query.isWebsiteUrl ? .website : .search))),
                        .send(.changePresentationDetent(.height(40))),
                        .openURL(.init(urlToOpen)),
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
    static func openURL(_ query: SearchQuery) -> Self {
        guard let url = query.websiteURL else { return .none }
        return .send(.delegate(.openURL(url)))
    }
}
