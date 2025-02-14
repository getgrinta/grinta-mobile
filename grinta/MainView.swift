import ComposableArchitecture
import SFSafeSymbols
import SwiftUI

struct MainView: View {
    @Bindable var store: StoreOf<Main>

    @State private var showSheet = true
    @State private var settingsPresented = false
    @State private var topColor = Color(uiColor: UIColor(red: 26 / 255, green: 26 / 255, blue: 26 / 255, alpha: 1))
    @State private var bottomColor = Color(uiColor: UIColor(red: 26 / 255, green: 26 / 255, blue: 26 / 255, alpha: 1))

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                StatusBarCoverView(color: topColor, safeAreaInsets: proxy.safeAreaInsets)

                Group {
                    if let currentURL = store.currentURL {
                        WebView(url: currentURL)
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
                            .onWebsiteMetadata { metadata in
                                store.send(.websiteMetadataFetched(metadata))
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Don't go below bottom safe area inset
                // which is reserved for the bottom bar
                .containerRelativeFrame(.vertical, alignment: .top) { length, _ in
                    length - proxy.safeAreaInsets.bottom
                }
                .animation(nil, value: store.currentURL)

                BottomBarBackgroundView(color: bottomColor)
            }
            .animation(nil, value: store.currentURL)
            .sheet(isPresented: $showSheet) {
                // Replace closures with specialized methods on MagicSheetView
                MagicSheetView(store: store.scope(state: \.magicSheet, action: \.magicSheet), settingsPresented: {
                    settingsPresented = true
                })
            }
            .background(Color(uiColor: UIColor(red: 26 / 255, green: 26 / 255, blue: 26 / 255, alpha: 1)))
            .ignoresSafeArea(.all)
        }
    }
}

private struct BottomBarBackgroundView: View {
    let color: Color

    var body: some View {
        color
            .animation(nil, value: true)
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
