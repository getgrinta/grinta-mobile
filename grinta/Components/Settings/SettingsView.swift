import ComposableArchitecture
import SFSafeSymbols
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<Settings>

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

                RoundedView {
                    Button {
                        store.send(.setIncognitoMode(!store.isIncognitoMode))
                    } label: {
                        Image(systemSymbol: store.isIncognitoMode ? .eyesInverse : .eyes)
                            .font(.body)
                            .foregroundStyle(Color.neutral700)
                    }
                }
            }
        }
        .padding(.vertical, 32)
        .sheet(isPresented: $store.isSharePresented.sending(\.setSharePresented)) {
            if !store.shareItems.isEmpty {
                ActivityView(activityItems: store.shareItems)
            }
        }
    }
}

#Preview("Settings") {
    SettingsView(store: .init(initialState: Settings.State(url: URL(string: "https://www.google.com")!)) {
        Settings()
    })
}
