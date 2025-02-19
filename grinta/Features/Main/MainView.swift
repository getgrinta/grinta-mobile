import ComposableArchitecture
import SFSafeSymbols
import SwiftUI

struct MainView: View {
    @Bindable var store: StoreOf<Main>

    @State private var showSheet = true
    @State private var settingsPresented = false
    @State private var topColor = Color.neutral100
    @State private var bottomColor = Color.neutral100

    @Namespace private var namespace

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                StatusBarCoverView(color: topColor, safeAreaInsets: proxy.safeAreaInsets)

                ZStack {
                    if store.currentTab == nil {
                        TabPickerView(namespace: namespace, onSelectedTab: { tab in
                            store.send(.selectTab(tab), animation: .spring)
                        }, tabs: store.tabs.elements, selectedTabId: store.currentTabId)
                    }

                    // Web view image overlay for perfect matched geometry
                    // TODO: Fade out after 0.5s
//                            Image(selectedImage)
//                                .resizable()
//                                .aspectRatio(contentMode: .fill)
//                                .frame(height: 300)
//                                .clipped()
//                                // Option: tap header to dismiss.
//                                .onTapGesture {
//                                    withAnimation(.spring()) {
//                                        self.selectedImage = nil
//                                    }
//                                }

                    if let currentTab = store.currentTab {
                        WebView(url: currentTab.url, id: currentTab.id)
                            .onBrandColorChange(region: .top(20)) { color in
                                withAnimation {
                                    topColor = color
                                }
                            }
                            .onBrandColorChange(region: .bottom(20)) { color in
                                withAnimation {
                                    bottomColor = color
                                }
                            }
                            .onSnapshot { image in
                                print("got snapshot")
                                store.send(.receivedTabSnapshot(id: currentTab.id, image))
                            }
                            .onWebsiteMetadata { metadata in
                                store.send(.websiteMetadataFetched(metadata))
                            }
                            .background(Color.white)
                            .matchedGeometryEffect(id: currentTab.id, in: namespace)
                            .transition(.scale)
                            .animation(.easeInOut, value: currentTab.id)
                    }
                }

                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Don't go below bottom safe area inset
                // which is reserved for the bottom bar
                .containerRelativeFrame(.vertical, alignment: .top) { length, _ in
                    length - proxy.safeAreaInsets.bottom
                }
                // .animation(nil, value: store.currentTab)

                BottomBarBackgroundView(color: bottomColor)
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
