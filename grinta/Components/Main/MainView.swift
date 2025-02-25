import ComposableArchitecture
import SFSafeSymbols
import SwiftUI

struct MainView: View {
    @Bindable var store: StoreOf<Main>

    @State private var isDraggingBack = false
    @Namespace private var namespace
    @State var dragCompletion: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                StatusBarCoverView(
                    color: store.currentTab?.topBrandColor ?? .neutral300,
                    safeAreaInsets: proxy.safeAreaInsets
                )

                ZStack {
                    if store.currentTab == nil || isDraggingBack {
                        TabPickerView(
                            namespace: namespace,
                            tabs: store.tabs.elements,
                            applyMatchedGeometry: isDraggingBack == false
                        )
                        .tabSelected { tabId in
                            store.send(.selectTab(tabId), animation: .easeInOut)
                        }
                        .tabClosed { tabId in
                            store.send(.closeTab(tabId), animation: .easeInOut(duration: 0.2))
                        }
                        .contentOpacity(dragCompletion)
                        .background(Color(UIColor(white: 0.2, alpha: 1)))
                    }

                    if let currentTab = store.currentTab {
                        ZStack {
                            WebView(initialURL: currentTab.url, id: currentTab.id)
                                .onBrandColorChange(region: .top(20)) { color in
                                    store.send(.brandColorChange(.top, color, currentTab.id), animation: .easeInOut)
                                }
                                .onBrandColorChange(region: .bottom(20)) { color in
                                    store.send(.brandColorChange(.bottom, color, currentTab.id), animation: .easeInOut)
                                }
                                .onNavigation { phase in
                                    store.send(.webViewNavigationChanged(currentTab.id, phase))
                                }
                                .onSnapshot { image, url in
                                    store.send(.receivedTabSnapshot(id: currentTab.id, image, url))
                                }
                                .onNavigationFinished { url in
                                    store.send(.navigationFinished(currentTab.id, url))
                                }
                                .onHistoryChange { hasHistory in
                                    store.send(.historyChanged(currentTab.id, hasHistory))
                                }
                                .onWebsiteMetadata { metadata in
                                    store.send(.websiteMetadataFetched(currentTab.id, metadata))
                                }
                                .if(store.displaySnapshotOverlay == false || currentTab.wasLoaded) {
                                    $0.matchedGeometryEffect(id: currentTab.id, in: namespace)
                                        .transition(.scale)
                                        .animation(.easeInOut, value: currentTab.id)
                                }
                                .background(currentTab.topBrandColor)
                                .if(currentTab.hasPreviousHistory == false) {
                                    $0.modifier(DragBackNavigationGesture(
                                        canGoBack: true,
                                        onBack: { store.send(.showTabsTapped) },
                                        isDraggingBack: $isDraggingBack
                                    ).dragCompletionChanged { completion in
                                        withAnimation(.easeInOut(duration: 0.5)) {
                                            dragCompletion = completion
                                        }
                                    })
                                }
                                .id(currentTab.id)

                            // Web view image overlay for smooth matched geometry
                            // in case the tab was created from storage
                            // Covers up the initial loading
                            if let snapshot = store.currentTab?.currentSnapshot, store.displaySnapshotOverlay, currentTab.wasLoaded == false {
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
            .sheet(isPresented: $store.showSheet) {
                MagicSheetView(store: store.scope(state: \.magicSheet, action: \.magicSheet))
                    .sheet(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { store in
                        SettingsView(store: store)
                            .presentationDetents([.height(200)])
                            .presentationBackground(.thinMaterial)
                            .presentationDragIndicator(.hidden)
                            .presentationCornerRadius(40)
                            .presentationBackgroundInteraction(.enabled)
                    }
            }
            .ignoresSafeArea(.all)
        }
        .onAppear {
            store.send(.onAppear)
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
