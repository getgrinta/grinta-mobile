import ComposableArchitecture
import SFSafeSymbols
import SwiftUI

struct SettingsView: View {
    let store: StoreOf<Settings>

    var body: some View {
        VStack(spacing: 16) {
            Text("Current Website")
                .font(.headline)
                .foregroundStyle(Color.neutral700)
            
            HStack(spacing: 12) {
                RoundedButton {
                    store.send(.shareCurrentWebsiteTapped)
                } label: {
                    Image(systemSymbol: .squareAndArrowUp)
                        .font(.body)
                        .foregroundStyle(Color.neutral700)
                }
                
                RoundedButton {
                    store.send(.copyCurrentWebsiteURLTapped)
                } label: {
                    Image(systemSymbol: .link)
                        .font(.body)
                        .foregroundStyle(Color.neutral700)
                }
            }
        }
        .padding(.vertical, 32)
    }
}

#Preview("Settings") {
    SettingsView(store: .init(initialState: Settings.State()) {
        Settings()
    })
}
