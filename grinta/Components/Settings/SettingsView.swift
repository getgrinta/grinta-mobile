import ComposableArchitecture
import SFSafeSymbols
import SwiftUI

struct SettingsView: View {
    @Bindable var store: StoreOf<Settings>

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    if store.hasCurrentTab {
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
                                HStack {
                                    Image(systemSymbol: store.isIncognitoMode ? .eyesInverse : .eyes)
                                        .font(.body)
                                }
                                .foregroundStyle(Color.neutral700)
                            }
                        }
                    }
                }

                RoundedButton {
                    store.send(.helpTapped)
                } label: {
                    HStack {
                        Text("Help")
                        Spacer()
                        Image(systemSymbol: .chevronRight)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(AppVersion.versionString)
                    .font(.footnote)
                    .foregroundStyle(Color.neutral500)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 20)
        }
        .sheet(isPresented: $store.isSharePresented.sending(\.setSharePresented)) {
            if !store.shareItems.isEmpty {
                ActivityView(activityItems: store.shareItems)
            }
        }
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section("Getting Started") {
                Text("Learn how to use Grinta's features")
            }
            Section("Tips & Tricks") {
                Text("Discover advanced features")
            }
            Section("Privacy & Security") {
                Text("Understanding Incognito Mode")
            }
        }
        .navigationTitle("Help")
    }
}

#Preview("Settings") {
    SettingsView(store: .init(initialState: Settings.State(url: URL(string: "https://www.google.com")!)) {
        Settings()
    })
}
