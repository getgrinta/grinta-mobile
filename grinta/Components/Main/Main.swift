import ComposableArchitecture
import Dependencies
import SFSafeSymbols
import SwiftUI

enum BrandColorRegion {
    case top
    case bottom
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
        case selectTab(BrowserTab) // change to accept ID
        case closeTab(BrowserTab) // change to accept ID
        case destination(PresentationAction<Destination.Action>)
        case websiteMetadataFetched(BrowserTab.ID, WebsiteMetadata)
        case webViewNavigationChanged(BrowserTab.ID, WebViewNavigationPhase)
        case receivedTabSnapshot(id: BrowserTab.ID, Image)
        case brandColorChange(BrandColorRegion, Color, BrowserTab.ID)
        case dismissSnapshotOverlay
    }

    @ObservableState
    struct State {
        var magicSheet = MagicSheet.State()
        @Presents var destination: Destination.State?

        var tabs: IdentifiedArrayOf<BrowserTab> = []
        var currentTabId: BrowserTab.ID?
        var displaySnapshotOverlay = false

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

            case let .webViewNavigationChanged(tabId, phase):
                switch phase {
                case .started(let url):
                    state.tabs[id: tabId]?.url = url
                }
                return .none

            case let .brandColorChange(region, color, tabId):
                switch region {
                case .top:
                    state.tabs[id: tabId]?.topBrandColor = color
                case .bottom:
                    state.tabs[id: tabId]?.bottomBrandColor = color
                }
                return .none

            case let .receivedTabSnapshot(id, image):
                state.tabs[id: id]?.snapshot = image
                return .none

            case .dismissSnapshotOverlay:
                state.displaySnapshotOverlay = false
                return .none

            case let .selectTab(tab):
                state.currentTabId = tab.id
                state.displaySnapshotOverlay = true

                // TODO: Add cancellable. might backfire when
                // closing & opening new tab
                return .run { send in
                    try await Task.sleep(for: .milliseconds(500))
                    await send(.dismissSnapshotOverlay)
                }

            case let .closeTab(tab):
                state.tabs.remove(tab)
                return .none

            case .destination:
                return .none

            case let .magicSheet(action):
                switch action {
                case let .delegate(.openURL(url)):
                    let tab = BrowserTab(creationTime: now(), url: url, title: url.absoluteString, snapshot: nil)
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

            case let .websiteMetadataFetched(id, metadata):
                state.tabs[id: id]?.title = metadata.title
                state.tabs[id: id]?.faviconURL = URL(string: metadata.favicon)
                state.tabs[id: id]?.wasLoaded = true
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
