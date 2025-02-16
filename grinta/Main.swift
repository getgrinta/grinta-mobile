import ComposableArchitecture
import Dependencies
import SFSafeSymbols
import SwiftUI

@Reducer
struct Main {
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case magicSheet(MagicSheet.Action)
        case websiteMetadataFetched(WebsiteMetadata)
    }

    @ObservableState
    struct State {
        var magicSheet = MagicSheet.State()
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

            case let .magicSheet(action):
                switch action {
                case let .delegate(.openURL(url)):
                    state.currentURL = url
                    return .none

                default:
                    return .none
                }

            case let .websiteMetadataFetched(metadata):
                return .run { _ in
                    print("FETCHED storing \(metadata) at hostname \(metadata.host.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "www.", with: ""))")
                    try await websiteMetadataClient.store(item: metadata, hostname: metadata.host.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "").replacingOccurrences(of: "www.", with: ""))
                }
            }
        }

        Scope(state: \.magicSheet, action: \.magicSheet) {
            MagicSheet()
        }
    }
}
