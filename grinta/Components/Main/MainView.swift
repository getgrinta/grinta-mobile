import ComposableArchitecture
import SFSafeSymbols
import SwiftUI

struct MainView: View {
    @Bindable var store: StoreOf<Main>

    @State private var showSheet = true
    @State private var settingsPresented = false
    @State private var isDraggingBack = false
    @Namespace private var namespace

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                StatusBarCoverView(
                    color: store.currentTab?.topBrandColor ?? .neutral300,
                    safeAreaInsets: proxy.safeAreaInsets
                )

                ZStack {
                    if store.currentTab == nil {
                        TabPickerView(namespace: namespace, onSelectedTab: { tab in
                            store.send(.selectTab(tab.id), animation: .spring)
                        }, onCloseTab: { tab in
                            store.send(.closeTab(tab.id))
                        }, tabs: store.tabs.elements, selectedTabId: store.currentTabId)
                            .background(Color(UIColor(white: 0.2, alpha: 1)))
                    }

                    if let currentTab = store.currentTab {
                        ZStack {
                            // Show previous snapshot while dragging back
                            if isDraggingBack, currentTab.canGoBack,
                               let previousSnapshot = currentTab.previousSnapshot
                            {
                                previousSnapshot
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .clipped()
                            }

                            WebView(url: currentTab.url, id: currentTab.id)
                                .onBrandColorChange(region: .top(20)) { color in
                                    store.send(.brandColorChange(.top, color, currentTab.id), animation: .easeInOut)
                                }
                                .onBrandColorChange(region: .bottom(20)) { color in
                                    store.send(.brandColorChange(.bottom, color, currentTab.id), animation: .easeInOut)
                                }
                                .onNavigation { phase in
                                    store.send(.webViewNavigationChanged(currentTab.id, phase))
                                }
                                .onSnapshot { image in
                                    print("on snapshot for tab id \(currentTab.id)")
                                    store.send(.receivedTabSnapshot(id: currentTab.id, image))
                                }
                                .onNavigationFinished { url in
                                    store.send(.navigationFinished(currentTab.id, url))
                                }
                                .onWebsiteMetadata { metadata in
                                    store.send(.websiteMetadataFetched(currentTab.id, metadata))
                                }
                                .modifier(EdgeNavigationGesture(
                                    canGoBack: currentTab.canGoBack,
                                    canGoForward: currentTab.canGoForward,
                                    onBack: { store.send(.goBack(currentTab.id)) },
                                    onForward: { store.send(.goForward(currentTab.id)) },
                                    isDraggingBack: $isDraggingBack
                                ))
                                .if(store.displaySnapshotOverlay == false || currentTab.wasLoaded) {
                                    $0.matchedGeometryEffect(id: currentTab.id, in: namespace)
                                        .transition(.scale)
                                        .animation(.easeInOut, value: currentTab.id)
                                }

                            // Web view image overlay for smooth matched geometry
                            // in case the tab was created from storage
                            // Covers up the initial loading
                            if let snapshot = store.currentTab?.previousSnapshot, store.displaySnapshotOverlay, currentTab.wasLoaded == false {
                                snapshot
                                    .resizable()
                                    .clipped()
                                    .matchedGeometryEffect(id: currentTab.id, in: namespace)
                                    .transition(.scale)
                                    .animation(.easeInOut, value: currentTab.id)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Don't go below bottom safe area inset
                // which is reserved for the bottom bar
                .containerRelativeFrame(.vertical, alignment: .top) { length, _ in
                    length - proxy.safeAreaInsets.bottom
                }

                BottomBarBackgroundView(color: store.currentTab?.bottomBrandColor ?? .neutral400)
            }
            .sheet(isPresented: $showSheet) {
                MagicSheetView(store: store.scope(state: \.magicSheet, action: \.magicSheet))
                    .sheet(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
                        SettingsView(store: store)
                            .presentationDetents([.height(200)])
                    }
            }
            .ignoresSafeArea(.all)
        }
    }
}

private struct BottomBarBackgroundView: View {
    let color: Color

    var body: some View {
        color
    }
}

private struct StatusBarCoverView: View {
    let color: Color
    let safeAreaInsets: EdgeInsets

    var body: some View {
        color
            .frame(height: safeAreaInsets.top)
    }
}

#Preview {
    MainView(
        store: Store(initialState: Main.State()) {
            Main()
        }
    )
}
