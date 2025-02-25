import ComposableArchitecture
import SFSafeSymbols
import SwiftUI

struct SettingsView: View {
    let store: StoreOf<Settings>

    var body: some View {
        ScrollView {
            HStack {
                Button {
                    store.send(.shareCurrentWebsiteTapped)
                } label: {
                    Image(systemSymbol: .squareAndArrowUp)
                }

                Button {
                    store.send(.copyCurrentWebsiteURLTapped)
                } label: {
                    Image(systemSymbol: .link)
                }
            }
        }
    }
}

#Preview("Settings") {
    SettingsView(store: .init(initialState: Settings.State()) {
        Settings()
    })
}
