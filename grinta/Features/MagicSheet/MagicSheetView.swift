import ComposableArchitecture
import RegexBuilder
import SwiftUI

struct MagicSheetView: View {
    @Bindable var store: StoreOf<MagicSheet>

    @State var sheetHeight: CGFloat = 400 // Can this be optional? 400 is weird
    @State var cornerRadius: CGFloat = 48

    let settingsPresented: () -> Void

    var body: some View {
        GeometryReader { viewSize in
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    FullView()
                        .opacity(min(1, max(0, (sheetHeight - CGFloat(80)) / CGFloat(40))))
                        .allowsHitTesting(store.mode == .full)

                    MiniView()
                        .opacity(min(1, max(0, CGFloat(2) - sheetHeight / CGFloat(50))))
                        .allowsHitTesting(store.mode == .minimized)
                }
            }
            .onChange(of: viewSize.size) { _, newSize in
                cornerRadius = max(0, min(48, newSize.height - 120))
                sheetHeight = newSize.height

                store.send(.sheetSizeChanged(newSize))
            }
        }
        .presentationDetents(MagicSheet.State.presentationDetents, selection: $store.presentationDetent)
        .interactiveDismissDisabled()
        .presentationBackground(.thinMaterial)
        .presentationDragIndicator(store.mode == .full ? .visible : .hidden)
        .presentationCornerRadius(cornerRadius)
        .ignoresSafeArea(.all)
        .presentationBackgroundInteraction(.enabled)
    }

    private func MiniView() -> some View {
        ZStack {
            RoundedButton {
                store.send(.miniViewExpandTapped)
            } label: {
                Image(systemSymbol: .plus)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.themeSecondary)
            }
            .padding(.top, 12)
        }
    }

    @ViewBuilder
    private func FullView() -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                RoundedView {
                    HStack {
                        TextField(
                            L10n.search,
                            text: $store.searchText.sending(\.searchTextChanged).animation(.easeInOut)
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onKeyPress { _ in
                            UIImpactFeedbackGenerator().prepare()
                            return .ignored
                        }
                        .onKeyPress(.return) {
                            store.send(.submitSearch)
                            return .handled
                        }
                        .foregroundColor(.neutral200)
                        .font(.title3)

                        if store.searchBarContainsText {
                            Spacer()
                                .frame(width: 30)
                        }
                    }
                }
                .overlay(alignment: .trailing) {
                    if store.searchBarContainsText {
                        Button {
                            store.send(.clearSearch)
                        } label: {
                            Image(systemSymbol: .xCircleFill)
                                .aspectRatio(contentMode: .fit)
                                .font(.headline)
                                .foregroundColor(.neutral300)
                                .opacity(0.8)
                                .padding(20)
                        }
                    }
                }
                .animation(.easeInOut, value: store.searchText.isEmpty)
                .layoutPriority(1)

                if store.searchBarAccessoriesVisible {
                    RoundedButton {} label: {
                        Image(.layoutGrid)
                            .font(.title3)
                            .foregroundStyle(.themePrimary)
                    }
                    .foregroundColor(.neutral400)
                    .font(.title3)
                    .animation(.easeInOut(duration: 0.1), value: store.searchBarAccessoriesVisible)

                    RoundedButton {
                        settingsPresented()
                    } label: {
                        Image(.menu)
                            .font(.title3)
                            .foregroundStyle(.themeSecondary)
                    }
                    .foregroundColor(.neutral400)
                    .font(.title3)
                    .animation(.easeInOut(duration: 0.1), value: store.searchBarAccessoriesVisible)
                }
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)

            List {
                ForEach(store.searchSuggestions) { suggestion in
                    Button {
                        store.send(.performSuggestion(suggestion))
                    } label: {
                        ListEntryView(
                            image: suggestion.image,
                            title: suggestion.title,
                            type: suggestion.type.title,
                            searchText: store.searchText
                        )
                    }
                    .buttonStyle(MagicSheetListButtonStyle())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
    }

    private func ListEntryView(image: ImageResource?, title: String, type: String, searchText: String) -> some View {
        HStack(spacing: 12) {
            Image(image ?? ImageResource.globe)
                .resizable()
                .foregroundStyle(Color.white)
                .tint(Color.white)
                .aspectRatio(contentMode: .fit)
                .frame(width: 30)
                .layoutPriority(0)
                .font(.title3)

            Text({
                var attributedString = AttributedString(title)
                attributedString.font = .system(size: 20, weight: .semibold)

                if let range = attributedString.range(of: searchText) {
                    attributedString[range].font = .system(size: 20, weight: .regular)
                }

                return attributedString
            }())
                .layoutPriority(1)

            Spacer()

            RoundedView {
                Text(type)
                    .foregroundColor(.neutral50)
                    .font(.subheadline)
            }
            .layoutPriority(1)
        }
    }
}

private struct MagicSheetListButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

private struct ListItem: Identifiable {
    var id: String { title + type }
    let title: String
    let image: ImageResource
    let type: String
    let action: () -> Void
}
