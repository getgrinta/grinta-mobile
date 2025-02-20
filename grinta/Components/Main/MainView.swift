import ComposableArchitecture
import SFSafeSymbols
import SwiftUI

struct MainView: View {
    @Bindable var store: StoreOf<Main>

    @State private var showSheet = true
    @State private var settingsPresented = false

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
                            store.send(.selectTab(tab), animation: .spring)
                        }, onCloseTab: { tab in
                            store.send(.closeTab(tab))
                        }, tabs: store.tabs.elements, selectedTabId: store.currentTabId)
                            .background(Color(UIColor(white: 0.2, alpha: 1)))
                    }

                    if let currentTab = store.currentTab {
                        WebView(url: currentTab.url, id: currentTab.id)
                            .onBrandColorChange(region: .top(20)) { color in
                                store.send(.brandColorChange(.top, color, currentTab.id), animation: .easeInOut)
                            }
                            .onBrandColorChange(region: .bottom(20)) { color in
                                store.send(.brandColorChange(.bottom, color, currentTab.id), animation: .easeInOut)
                            }
                            .onSnapshot { image in
                                store.send(.receivedTabSnapshot(id: currentTab.id, image))
                            }
                            .onWebsiteMetadata { metadata in
                                store.send(.websiteMetadataFetched(currentTab.id, metadata))
                            }
                            .if(store.displaySnapshotOverlay == false || currentTab.wasLoaded) {
                                $0.matchedGeometryEffect(id: currentTab.id, in: namespace)
                                    .transition(.scale)
                                    .animation(.easeInOut, value: currentTab.id)
                            }

                        // Web view image overlay for smooth matched geometry
                        // in case the tab was created from storage
                        // Covers up the initial loading
                        if let snapshot = store.currentTab?.snapshot, store.displaySnapshotOverlay, currentTab.wasLoaded == false {
                            snapshot
                                .resizable()
                                .clipped()
                                .matchedGeometryEffect(id: currentTab.id, in: namespace)
                                .transition(.scale)
                                .animation(.easeInOut, value: currentTab.id)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Don't go below bottom safe area inset
                // which is reserved for the bottom bar
                .containerRelativeFrame(.vertical, alignment: .top) { length, _ in
                    length - proxy.safeAreaInsets.bottom
                }
                // .animation(nil, value: store.currentTab)

                BottomBarBackgroundView(color: store.currentTab?.bottomBrandColor ?? .neutral400)
            }
            // .animation(nil, value: store.currentTab)
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
