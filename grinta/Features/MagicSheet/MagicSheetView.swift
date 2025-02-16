import ComposableArchitecture
import SwiftUI
import SwiftUIIntrospect

struct VisualEffectBlur: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context _: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_: UIVisualEffectView, context _: Context) {}
}

extension Color {
    static let vibrantBlue = Color(red: 0.4157, green: 0.5098, blue: 0.9843) // #6A82FB [1]
    static let navyBlue = Color(red: 0.0, green: 0.0, blue: 0.5019) // #000080
    static let kashmirBlue = Color(red: 0.3137, green: 0.4275, blue: 0.6039) // #506D9B
    static let biscay = Color(red: 0.1176, green: 0.2275, blue: 0.4627) // #1E3A76
    static let fuchsia = Color(red: 1.0, green: 0.0, blue: 1.0) // #FF00FF
    static let azalea = Color(red: 0.9451, green: 0.6941, blue: 0.7804) // #F1B1C7
}

struct MagicSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var store: StoreOf<MagicSheet>

    @State var sheetHeight: CGFloat = 400 // Can this be optional? 400 is weird
    @State var safeAreaInsets: EdgeInsets = .init(_all: 0)
    @State var cornerRadius: CGFloat = 48
    @FocusState var focusedField: MagicSheet.State.Field?

    let settingsPresented: () -> Void

    var body: some View {
        GeometryReader { viewSize in
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    FullView()
                        .opacity(min(1, max(0, (sheetHeight - CGFloat(80)) / CGFloat(safeAreaInsets.bottom))))
                        .allowsHitTesting(store.mode == .full)

                    MiniView()
                        .opacity(min(1, max(0, CGFloat(2) - sheetHeight / CGFloat(safeAreaInsets.bottom))))
                        .allowsHitTesting(store.mode == .minimized)
                }
            }
            .onAppear {
                safeAreaInsets = viewSize.safeAreaInsets
            }
            .onChange(of: viewSize.size) { _, newSize in
                cornerRadius = max(0, min(48, newSize.height - 120))
                sheetHeight = newSize.height

                store.send(.sheetSizeChanged(newSize))
            }
        }
        .bind($store.focusedField, to: $focusedField)
        .presentationDetents(MagicSheet.State.presentationDetents, selection: $store.presentationDetent)
        .interactiveDismissDisabled()
        .presentationBackground(.thinMaterial)
        .presentationDragIndicator(store.mode == .full ? .visible : .hidden)
        .presentationCornerRadius(cornerRadius)
        .presentationBackgroundInteraction(.enabled)
    }

    private func MiniView() -> some View {
        ZStack {
            RoundedButton {
                store.send(.miniViewExpandTapped)
            } label: {
                Image(systemSymbol: .plus)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.theme)
            }
            .padding(.top, 12)
        }
    }

    @State private var startPoint = UnitPoint(x: -1, y: 0.5)
    @State private var endPoint = UnitPoint(x: 1, y: 0.5)

    @State private var gradientPosition: CGFloat = -1.0

    @ViewBuilder
    private func FullView() -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                MagicRoundedView(isMagicEnabled: store.isRecognizingVoice) {
                    HStack {
                        TextField(
                            L10n.search,
                            text: $store.searchText.sending(\.searchTextChanged).animation(.easeInOut)
                        )
                        .keyboardType(.webSearch)
                        .submitLabel(.go)
                        .introspect(.textField, on: .iOS(.v17, .v18)) { textField in
                            textField.enablesReturnKeyAutomatically = true
                        }
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: MagicSheet.State.Field.search)
                        .textInputAutocapitalization(.never)
                        .onKeyPress { _ in
                            UIImpactFeedbackGenerator().prepare()
                            return .ignored
                        }
                        .onSubmit {
                            store.send(.submitSearch)
                        }
                        .foregroundStyle(.neutral600)
                        .font(.title3)

                        if store.searchBarContainsText {
                            Spacer()
                                .frame(width: 30)
                        }
                    }
                }
                .overlay(alignment: .trailing) {
                    ZStack {
                        Button {
                            store.send(.clearSearch)
                        } label: {
                            Image(systemSymbol: .xCircleFill)
                                .aspectRatio(contentMode: .fit)
                                .font(.headline)
                                .foregroundStyle(.neutral600)
                                .opacity(0.8)
                                .padding(20)
                        }
                        .opacity(store.searchBarContainsText ? 1 : 0)

                        Button {
                            store.send(.voiceRecognitionTapped, animation: .easeInOut)
                        } label: {
                            Image(systemSymbol: .mic)
                                .aspectRatio(contentMode: .fit)
                                .font(.headline)
                                .foregroundStyle(.neutral600)
                                .opacity(0.8)
                                .padding(20)
                        }
                        .opacity((store.searchBarContainsText || store.isRecognizingVoice) ? 0 : 1)
                    }
                }
                .animation(.easeInOut, value: store.searchText.isEmpty)
                .layoutPriority(1)

                if store.searchBarAccessoriesVisible {
                    RoundedButton {} label: {
                        Image(.layoutGrid)
                            .renderingMode(.template)
                            .font(.title3)
                            .foregroundStyle(Color.theme)
                    }
                    .foregroundColor(.neutral400)
                    .font(.title3)
                    .animation(.easeInOut(duration: 0.1), value: store.searchBarAccessoriesVisible)

                    RoundedButton {
                        settingsPresented()
                    } label: {
                        Image(.menu)
                            .renderingMode(.template)
                            .font(.title3)
                            .foregroundStyle(.theme)
                    }
                    .foregroundColor(.neutral400)
                    .font(.title3)
                    .animation(.easeInOut(duration: 0.1), value: store.searchBarAccessoriesVisible)
                }
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)

            ZStack {
                OrbitingParticlesView()
                    .opacity(store.isRecognizingVoice ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: store.isRecognizingVoice)
                List {
                    ForEach(store.searchSuggestions) { suggestion in
                        Button {
                            store.send(.performSuggestion(suggestion))
                        } label: {
                            ListEntryView(suggestion: suggestion, searchText: store.searchText)
                        }
                        .buttonStyle(MagicSheetListButtonStyle())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .opacity(store.isRecognizingVoice ? 0 : 1)
                .animation(.easeInOut(duration: 0.3), value: store.isRecognizingVoice)
            }
        }
    }

    private func ListEntryView(suggestion: SearchSuggestion, searchText: String) -> some View {
        HStack(spacing: 12) {
            if let imageURL = suggestion.imageURL.flatMap({ URL(string: $0) }) {
                AsyncImage(url: imageURL, content: { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .layoutPriority(0)
                        .frame(width: 28)

                }, placeholder: {
                    Image(suggestion.image ?? .globe)
                })
            } else {
                Image(suggestion.origin == .history ? ImageResource.history : (suggestion.image ?? ImageResource.globe))
                    .resizable()
                    .foregroundStyle(.neutral400)
                    .tint(Color.white)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28)
                    .layoutPriority(0)
                    .font(.body)
            }

            Text({
                let isInvertedHighlighting = (suggestion.origin == .history && suggestion.type == .website)
                var attributedString = AttributedString(suggestion.title)
                attributedString.font = .system(.body, weight: isInvertedHighlighting ? .regular : .semibold)
                attributedString.foregroundColor = .neutral600

                if suggestion.title.lowercased() != searchText.lowercased() {
                    if let range = attributedString.range(of: searchText) {
                        attributedString[range].font = .system(.body, weight: isInvertedHighlighting ? .semibold : .regular)
                    }
                }

                return attributedString
            }())
                .lineLimit(2)
                .layoutPriority(1)

            if suggestion.type != .search, suggestion.type != .website {
                Spacer()

                RoundedView {
                    Text(suggestion.type.title)
                        .tint(.neutral600)
                        .font(.body)
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
