import ComposableArchitecture
import SwiftUI
import SwiftUIIntrospect

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
        .onAppear {
            store.send(.onAppear)
        }
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
}

private struct MagicSheetListButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
