import ComposableArchitecture
import RegexBuilder
import SwiftUI
import WebURL

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
        case submitSearch
        case sheetSizeChanged(CGSize)
        case presentationDetentChanged
        case replaceSearchSuggestions([SearchSuggestion])
        case binding(BindingAction<State>)
        case delegate(Delegate)
    }

    @Dependency(SearchSuggestionClient.self) var searchSuggestionClient
    @Dependency(StartPageClient.self) var startPageClient

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
                state.searchText = query.term
                state.searchBarAccessoriesVisible = query.isEmpty

                return .merge(
                    //.cancel(id: "search_suggestions"),
                        .run { [searchSuggestionClient] send in
                    //try await withTaskCancellation(id: "wow") {
                        for await suggestions in try await searchSuggestionClient.suggestions(startPageClient: startPageClient, query: query) {
                            await send(.replaceSearchSuggestions(suggestions))
                        }
                    //}
                }
                // .debounce(id: "search_suggestions", for: .seconds(1), scheduler: DispatchQueue.main)
                .cancellable(id: "search_suggestions", cancelInFlight: true)
                    )
            case let .replaceSearchSuggestions(suggestions):
                state.searchSuggestions = suggestions
                return .none

            case .miniViewExpandTapped:
                return .send(.changePresentationDetent(.medium))

            case .sheetSizeChanged(let size):
                return .none

            case let .changePresentationDetent(detent):
                state.presentationDetent = detent
                return .send(.presentationDetentChanged)

            case .clearSearch:
                state.searchText = ""
                state.searchSuggestions = []
                return .none

            case let .performSuggestion(suggestion):
                switch suggestion.type {
                case .ai:
                    return .none
                case .note:
                    return .none
                case .website:
                    return .merge(
                        .send(.changePresentationDetent(.height(40))),
                        .send(.clearSearch),
                        .openURL(suggestion.title)
                    )
                case .search:
                    return .none
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

                return .merge(
                    .send(.changePresentationDetent(.height(40))),
                    .openURL(urlToOpen),
                    .run { _ in
                        await UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)
                    }
                )

            case .binding:
                return .none

            case .delegate:
                return .none
            }
        }
    }
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
