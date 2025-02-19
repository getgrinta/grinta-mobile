import ComposableArchitecture
import Dependencies
import SFSafeSymbols
import SwiftUI

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
        case selectTab(BrowserTab)
        case destination(PresentationAction<Destination.Action>)
        case websiteMetadataFetched(WebsiteMetadata)
        case receivedTabSnapshot(id: BrowserTab.ID, Image)
    }

    @ObservableState
    struct State {
        var magicSheet = MagicSheet.State()
        @Presents var destination: Destination.State?

        var tabs: IdentifiedArrayOf<BrowserTab> = []
        var currentTabId: BrowserTab.ID?

        var currentTab: BrowserTab? {
            guard let currentTabId else { return nil }
            return tabs[id: currentTabId]
        }
    }

    @Dependency(LLMClient.self) var llmClient
    @Dependency(WebsiteMetadataStoreClient.self) var websiteMetadataClient
    @Dependency(\.date) var now

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .receivedTabSnapshot(id, image):
                state.tabs[id: id]?.snapshot = image
                return .none

            case let .selectTab(tab):
                state.currentTabId = tab.id
                return .none

            case .destination:
                return .none

            case let .magicSheet(action):
                switch action {
                case let .delegate(.openURL(url)):
                    let tab = BrowserTab(creationTime: now(), title: url.absoluteString, url: url, snapshot: nil)
                    state.tabs.append(tab)
                    state.currentTabId = tab.id
                    return .none

                case .delegate(.openSettings):
                    state.destination = .settings(Settings.State())
                    return .none

                case .delegate(.openTabs):
                    state.currentTabId = nil
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
