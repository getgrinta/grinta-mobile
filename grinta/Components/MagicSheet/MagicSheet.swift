import ComposableArchitecture
import SwiftUI

@Reducer
struct MagicSheet {
    @ObservableState
    struct State {
        // When heights are finalized - create specific variables for them
        static let presentationDetents: Set<PresentationDetent> = [
            .mini,
            .compact,
            .full,
        ]

        var searchText = ""
        var presentationDetent: PresentationDetent = .full
        var mode: Mode = .full
        var cornerRadius: CGFloat = 48
        var sheetHeight: CGFloat = 400
        var searchBarAccessoriesVisible = true
        var searchSuggestions: [SearchSuggestion] = []
        var isRecognizingVoice = false
        var isSpeechRecognitionAvailable = false
        var loadingProgress: Double = 0

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

        var isLoading: Bool {
            loadingProgress > 0 && loadingProgress < 1
        }
    }

    enum Action: BindableAction {
        enum Delegate {
            case openURL(URL)
            case openSettings
            case openTabs
        }

        case searchTextChanged(String)
        case changePresentationDetent(PresentationDetent)
        case clearSearch
        case miniViewExpandTapped
        case openTabsTapped
        case settingsTapped
        case performSuggestion(SearchSuggestion)
        case appendSearchWithSuggestion(SearchSuggestion)
        case archiveItem(HistoryItem)
        case submitSearch
        case stoppedRecognizingVoice
        case sheetSizeChanged(CGSize)
        case onAppear
        case presentationDetentChanged
        case voiceRecognitionTapped
        case setCornerRadius(CGFloat)
        case replaceSearchSuggestions([SearchSuggestion])
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case updateLoadingProgress(Double)
    }

    @Dependency(HistoryArchiveClient.self) var historyArchive
    @Dependency(SpeechRecognitionClient.self) var speechRecognitionClient
    @Dependency(SuggestionAggregator.self) var suggestionAggregator
    @Dependency(RemoteSuggestionClient.self) var searchSuggestionClient
    @Dependency(WebsiteMetadataStoreClient.self) var websiteMetadataClient
    @Dependency(SearchEngineClient.self) var searchEngine
    @Dependency(\.mainRunLoop) var runLoop

    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.presentationDetent):
                return .send(.presentationDetentChanged)

            case .settingsTapped:
                return .send(.delegate(.openSettings))

            case .presentationDetentChanged:
                switch state.presentationDetent {
                case .mini:
                    state.mode = .minimized
                case .compact, .full:
                    state.mode = .full
                default:
                    break
                }

                return .none

            case let .appendSearchWithSuggestion(suggestion):
                return .send(.searchTextChanged("\(state.searchText) \(suggestion.title)"))

            case let .setCornerRadius(cornerRadius):
                state.cornerRadius = cornerRadius
                return .none

            case .stoppedRecognizingVoice:
                state.isRecognizingVoice = false

                let searchQuery = SearchQuery(state.searchText)
                guard searchQuery.isEmpty == false else { return .none }

                guard let urlToOpen = searchEngine.searchURL(.google, searchQuery) else {
                    return .none
                }

                return .merge(
                    .send(.archiveItem(HistoryItem(query: searchQuery, type: .search))),
                    .openWebsite(.init(urlToOpen)),
                    .send(.clearSearch), .send(.changePresentationDetent(.mini))
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

                return .cancel(id: SearchSuggestionSearchCancelId())
                    .concatenate(with: .run { [searchSuggestionClient] send in
                        for await suggestions in try await suggestionAggregator.suggestions(remoteSuggestionClient: searchSuggestionClient, websiteMetadataClient: websiteMetadataClient, historyArchive: historyArchive, query: query) {
                            await send(.replaceSearchSuggestions(suggestions))
                        }
                    }
                    .cancellable(id: SearchSuggestionSearchCancelId(), cancelInFlight: true))

            case let .replaceSearchSuggestions(suggestions):
                state.searchSuggestions = suggestions
                return .none

            case .miniViewExpandTapped:
                state.focusedField = .search
                return .merge(
                    .send(.changePresentationDetent(.full)),
                    .run { [searchSuggestionClient, state] send in
                        let query = SearchQuery(state.searchText)
                        for await suggestions in try await suggestionAggregator.suggestions(
                            remoteSuggestionClient: searchSuggestionClient,
                            websiteMetadataClient: websiteMetadataClient,
                            historyArchive: historyArchive,
                            query: query
                        ) {
                            await send(.replaceSearchSuggestions(suggestions))
                        }
                    }
                    .cancellable(id: SearchSuggestionSearchCancelId(), cancelInFlight: true)
                )

            case let .sheetSizeChanged(size): // Steer the corner radius through the reducer to avoid cyclic layouting
                state.sheetHeight = size.height

                let cornerRadius = state.cornerRadius

                return .run { [cornerRadius] send in
                    guard !Task.isCancelled else { return }
                    let newCornerRadius = max(0, min(40, size.height - 120))

                    if cornerRadius != newCornerRadius {
                        await send(.setCornerRadius(newCornerRadius))
                    }
                }
                .throttle(id: SheetSizeChangeThrottleId(), for: .milliseconds(10), scheduler: runLoop, latest: true)

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
                    let query = SearchQuery(suggestion.title)
                    guard let url = searchEngine.searchURL(.google, query) else {
                        return .none
                    }
                    return .send(.delegate(.openURL(url)))
                case .website:
                    return .merge(
                        .send(.archiveItem(HistoryItem(query: SearchQuery(suggestion.title), type: .website))),
                        .send(.changePresentationDetent(.mini), animation: .easeInOut),
                        .send(.clearSearch),
                        .openWebsite(.init(suggestion.url))
                    )
                case .search:
                    let query = SearchQuery(suggestion.title)
                    guard let url = searchEngine.searchURL(.google, query) else {
                        return .none
                    }

                    return .merge(
                        .send(.archiveItem(HistoryItem(query: SearchQuery(suggestion.title), type: .search))),
                        .openWebsite(url),
                        .send(.clearSearch),
                        .send(.changePresentationDetent(.mini))
                    )
                }

            case .onAppear:
                state.isSpeechRecognitionAvailable = (try? speechRecognitionClient.isAvailable()) ?? false
                return .run { [searchSuggestionClient, state] send in
                    let query = SearchQuery(state.searchText)
                    for await suggestions in try await suggestionAggregator.suggestions(
                        remoteSuggestionClient: searchSuggestionClient,
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

                // If search term is a website url - open website
                // Else open search website with that query
                let urlToOpen = if query.isWebsiteUrl {
                    query.websiteURL
                } else {
                    searchEngine.searchURL(.google, query)
                }

                return .concatenate(
                    .merge(
                        .send(.archiveItem(HistoryItem(query: query, type: query.isWebsiteUrl ? .website : .search))),
                        .send(.changePresentationDetent(.mini)),
                        .openWebsite(urlToOpen),
                        .run { _ in
                            await UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
                        }
                    ),
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

            case .openTabsTapped:
                return .send(.changePresentationDetent(.mini)).concatenate(with: .send(.delegate(.openTabs)))

            case let .updateLoadingProgress(progress):
                state.loadingProgress = progress
                return .none
            }
        }
    }

    private struct SearchSuggestionSearchCancelId: Hashable {}
    private struct SheetSizeChangeThrottleId: Hashable {}
}

private extension PresentationDetent {
    static let mini = PresentationDetent.height(40)
    static let compact = PresentationDetent.height(200)
    static let full = PresentationDetent.medium

    var isMini: Bool { self == Self.mini }
    var isCompact: Bool { self == Self.compact }
    var isFull: Bool { self == Self.full }
}

private extension Effect where Action == MagicSheet.Action {
    static func openWebsite(_ query: SearchQuery) -> Self {
        guard let url = query.websiteURL else { return .none }
        return .send(.delegate(.openURL(url)), animation: .easeInOut)
    }
}

private extension Effect where Action == MagicSheet.Action {
    static func openWebsite(_ url: URL?) -> Self {
        guard let url else { return .none }
        return .send(.delegate(.openURL(url)), animation: .easeInOut)
    }
}
