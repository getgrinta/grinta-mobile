import ComposableArchitecture
import RegexBuilder
import SwiftUI

struct VisualEffectBlur: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context _: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_: UIVisualEffectView, context _: Context) {}
}

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
                        .keyboardType(.webSearch)
                        .submitLabel(.go)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onKeyPress { _ in
                            UIImpactFeedbackGenerator().prepare()
                            return .ignored
                        }
                        .onSubmit {
                            store.send(.submitSearch)
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
                            imageURL: suggestion.imageURL.flatMap { URL(string: $0) },
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
            .transaction { $0.animation = nil }
            .listStyle(.plain)
        }
    }

    private func ListEntryView(image: ImageResource?, imageURL: URL?, title: String, type: String, searchText: String) -> some View {
        HStack(spacing: 12) {
            if let imageURL {
                AsyncImage(url: imageURL, content: { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .layoutPriority(0)
                        .frame(width: 30)

                }, placeholder: {
                    Image(image ?? .globe)
                })
            } else {
                Image(image ?? ImageResource.globe)
                    .resizable()
                    .foregroundStyle(.neutral400)
                    .tint(Color.white)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30)
                    .layoutPriority(0)
                    .font(.title3)
            }

            Text({
                var attributedString = AttributedString(title)
                attributedString.font = .system(size: 20, weight: .semibold)

                if let range = attributedString.range(of: searchText) {
                    attributedString[range].font = .system(size: 20, weight: .regular)
                }

                return attributedString
            }())
                .layoutPriority(1)

            if type.hasPrefix("Search") == false {
                Spacer()

                RoundedView {
                    Text(type)
                        .foregroundColor(.neutral50)
                        .font(.subheadline)
                }
                .layoutPriority(1)
            }
        }
        .frame(minHeight: 38)
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
