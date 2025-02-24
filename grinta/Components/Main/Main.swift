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
        case selectTab(BrowserTab.ID)
        case closeTab(BrowserTab.ID)
        case destination(PresentationAction<Destination.Action>)
        case websiteMetadataFetched(BrowserTab.ID, WebsiteMetadata)
        case webViewNavigationChanged(BrowserTab.ID, WebViewNavigationPhase)
        case historyChanged(BrowserTab.ID, Bool)
        case receivedTabSnapshot(id: BrowserTab.ID, Image, URL)
        case brandColorChange(BrandColorRegion, Color, BrowserTab.ID)
        case dismissSnapshotOverlay
        case navigationFinished(BrowserTab.ID, URL)
        case showTabsTapped
        case updateSnapshot(BrowserTab.ID, Image, URL)
        case onAppear
        case loadedTabs([BrowserTab])
    }

    @ObservableState
    struct State {
        var magicSheet = MagicSheet.State()
        @Presents var destination: Destination.State?

        var tabs: IdentifiedArrayOf<BrowserTab> = []
        var currentTabId: BrowserTab.ID?
        var displaySnapshotOverlay = false
        var showSheet = true
        var settingsPresented = false

        var currentTab: BrowserTab? {
            guard let currentTabId else { return nil }
            return tabs[id: currentTabId]
        }
    }

    @Dependency(LLMClient.self) var llmClient
    @Dependency(WebsiteMetadataStoreClient.self) var websiteMetadataClient
    @Dependency(HistoryArchiveClient.self) var historyArchive
    @Dependency(\.date) var now
    @Dependency(\.tabPersistence) var tabPersistence

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .run { send in
                    let tabs = try await tabPersistence.loadTabsWithSnapshots()
                    await send(.loadedTabs(tabs))
                }

            case let .loadedTabs(tabs):
                let tabsByNewestLast = tabs.sorted(by: { $0.creationTime < $1.creationTime })
                state.tabs = IdentifiedArrayOf(uniqueElements: tabsByNewestLast)

                if state.currentTabId == nil {
                    state.currentTabId = tabs.last?.id
                }

                return .none

            case let .webViewNavigationChanged(tabId, phase):
                switch phase {
                case let .started(url):
                    state.tabs[id: tabId]?.url = url
                case let .urlChanged(url):
                    state.tabs[id: tabId]?.url = url
                }
                return .run { [tabs = state.tabs] _ in
                    try await tabPersistence.saveTabs(tabs.elements)
                }

            case let .historyChanged(tabId, hasHistory):
                print("History changed hasHistory: \(hasHistory)")
                state.tabs[id: tabId]?.hasPreviousHistory = hasHistory
                return .none

            case .showTabsTapped:
                state.currentTabId = nil
                return .none

            case let .brandColorChange(region, color, tabId):
                // print("Brand color change for tab id: \(tabId)")
                switch region {
                case .top:
                    state.tabs[id: tabId]?.topBrandColor = color
                case .bottom:
                    state.tabs[id: tabId]?.bottomBrandColor = color
                }
                return .run { [tabs = state.tabs] _ in
                    try await tabPersistence.saveTabs(tabs.elements)
                }

            case let .receivedTabSnapshot(id, image, url):
                state.tabs[id: id]?.updateSnapshot(image, forURL: url)
                return .run { [tabs = state.tabs] _ in
                    try await tabPersistence.saveSnapshot(id, image)
                    try await tabPersistence.saveTabs(tabs.elements)
                }

            case let .navigationFinished(tabId, url):
                state.tabs[id: tabId]?.url = url
                return .none

            case let .selectTab(tabId):
                state.currentTabId = tabId
                state.displaySnapshotOverlay = true

                // TODO: Add cancellable. might backfire when
                // closing & opening new tab
                return .run { send in
                    try await Task.sleep(for: .milliseconds(500))
                    await send(.dismissSnapshotOverlay)
                }

            case let .closeTab(tabId):
                state.tabs.remove(id: tabId)
                if state.currentTabId == tabId {
                    state.currentTabId = state.tabs.first?.id
                }
                return .run { [tabs = state.tabs] _ in
                    try await tabPersistence.saveTabs(tabs.elements)
                }

            case .destination:
                return .none

            case let .magicSheet(action):
                switch action {
                case let .delegate(.openURL(url)):
                    let tab = BrowserTab(id: UUID(), url: url)
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
                state.tabs[id: id]?.metadata = metadata
                return .run { [tabs = state.tabs] _ in
                    try await tabPersistence.saveTabs(tabs.elements)
                }

            case let .updateSnapshot(tabId, image, url):
                state.tabs[id: tabId]?.updateSnapshot(image, forURL: url)
                return .none

            case .dismissSnapshotOverlay:
                state.displaySnapshotOverlay = false
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)

        Scope(state: \.magicSheet, action: \.magicSheet) {
            MagicSheet()
        }
    }
}
