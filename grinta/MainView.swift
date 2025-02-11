import ComposableArchitecture
import SFSafeSymbols
import SwiftUI

struct MainView: View {
    @Bindable var store: StoreOf<Main>

    @State private var showSheet = true
    @State private var settingsPresented = false
    @State private var currentURL: URL?
    @State private var sheetColor = Color(uiColor: UIColor(red: 26 / 255, green: 26 / 255, blue: 26 / 255, alpha: 1))

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                StatusBarCoverView(color: sheetColor, safeAreaInsets: proxy.safeAreaInsets)

                Group {
                    if let currentURL {
                        WebView(url: currentURL)
                            .onBrandColorChange { color in
                                withAnimation {
                                    sheetColor = color
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Don't go below bottom safe area inset
                .containerRelativeFrame(.vertical, alignment: .top) { length, _ in
                    length - proxy.safeAreaInsets.bottom
                }
                .animation(nil, value: currentURL)

                BottomBarBackgroundView()
            }
            .animation(nil, value: currentURL)
            .sheet(isPresented: $showSheet) {
                // Replace this API with methods on MagicSheetView
                MagicSheetView(settingsPresented: {
                    settingsPresented = true
                }, openURL: { url in
                    currentURL = url
                })
                .sheet(isPresented: $settingsPresented) {
                    Text("WOW")
                }
            }
            .background(Color(uiColor: UIColor(red: 26 / 255, green: 26 / 255, blue: 26 / 255, alpha: 1)))
            .ignoresSafeArea(.all)
        }
    }
}

private struct BottomBarBackgroundView: View {
    var body: some View {
        // For now white - later replace with non-visible part of webview
        Color.white
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
