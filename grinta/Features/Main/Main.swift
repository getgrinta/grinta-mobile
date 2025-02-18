import ComposableArchitecture
import Dependencies
import SFSafeSymbols
import SwiftUI

struct Tab: Identifiable, Hashable {
    var id = UUID()

    let creationTime: Date
    let title: String
    let url: URL
    let snapshot: Image?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

@Reducer
struct Main {
    @Reducer
    enum Destination {
        case settings(Settings)
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case magicSheet(MagicSheet.Action)
        case destination(PresentationAction<Destination.Action>)
        case websiteMetadataFetched(WebsiteMetadata)
    }

    @ObservableState
    struct State {
        var magicSheet = MagicSheet.State()
        @Presents var destination: Destination.State?
        
        var currentURL: URL?
    }

    @Dependency(LLMClient.self) var llmClient
    @Dependency(WebsiteMetadataStoreClient.self) var websiteMetadataClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .destination:
                return .none

            case let .magicSheet(action):
                switch action {
                case let .delegate(.openURL(url)):
                    state.currentURL = url
                    return .none

                case .delegate(.openSettings):
                    state.destination = .settings(.init())
                    return .none

                default:
                    return .none
                }

            case let .websiteMetadataFetched(metadata):
                return .run { _ in
                    try await websiteMetadataClient.store(item: metadata, hostname: SearchQuery(metadata.host).canonicalHost)
                }
            }
        }
        .ifLet(\.$destination, action: \.destination)

        Scope(state: \.magicSheet, action: \.magicSheet) {
            MagicSheet()
        }
    }
}
