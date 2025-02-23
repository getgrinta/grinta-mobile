import ComposableArchitecture
import SwiftUI

struct MagicSheetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var store: StoreOf<MagicSheet>

    @State var safeAreaInsets = EdgeInsets(.zero)
    @FocusState var focusedField: MagicSheet.State.Field?

    var body: some View {
        GeometryReader { viewSize in
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    FullView()
                        .opacity(min(1, max(0, (store.sheetHeight - CGFloat(80)) / CGFloat(safeAreaInsets.bottom))))
                        .allowsHitTesting(store.mode == .full)

                    MiniView()
                        .opacity(min(1, max(0, CGFloat(2) - store.sheetHeight / CGFloat(safeAreaInsets.bottom))))
                        .allowsHitTesting(store.mode == .minimized)
                }
                .preference(key: SizePreferenceKey.self, value: viewSize.size)
            }
            .onAppear {
                safeAreaInsets = viewSize.safeAreaInsets
            }
            .onPreferenceChange(SizePreferenceKey.self) { value in
                Task { @MainActor in
                    store.send(.sheetSizeChanged(value))
                }
            }
        }
        .bind($store.focusedField, to: $focusedField)
        .presentationDetents(MagicSheet.State.presentationDetents, selection: $store.presentationDetent)
        .interactiveDismissDisabled()
        .presentationBackground(.thinMaterial)
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(CGFloat(store.cornerRadius))
        .presentationBackgroundInteraction(.enabled)
        .onAppear {
            store.send(.onAppear)
        }
    }

    @State var someVal: UUID? = nil

    private func MiniView() -> some View {
        ZStack {
            RoundedButton {
                store.send(.miniViewExpandTapped)
                someVal = UUID()
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
        let shouldDisplayMic =
            store.isSpeechRecognitionAvailable &&
            store.searchBarContainsText == false &&
            store.isRecognizingVoice == false

        VStack(spacing: 8) {
            HStack(alignment: .center) {
                MagicRoundedView(isMagicEnabled: store.isRecognizingVoice) {
                    HStack {
                        AutoSelectTextField(
                            L10n.search,
                            text: $store.searchText.sending(\.searchTextChanged).animation(.easeInOut)
                        )
                        .autoselect(value: someVal)
                        .submitLabel(.go)
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
                        .keyboardType(.webSearch)
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
                        .opacity(shouldDisplayMic ? 1 : 0)
                    }
                }
                .animation(.easeInOut, value: store.searchText.isEmpty)
                .layoutPriority(1)

                if store.searchBarAccessoriesVisible {
                    RoundedButton {
                        store.send(.openTabsTapped, animation: .easeInOut)
                    } label: {
                        Image(.layoutGrid)
                            .renderingMode(.template)
                            .font(.title3)
                            .foregroundStyle(Color.theme)
                    }
                    .foregroundColor(.neutral400)
                    .font(.title3)
                    .animation(.easeInOut(duration: 0.1), value: store.searchBarAccessoriesVisible)

                    RoundedButton {
                        store.send(.settingsTapped)
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
            .padding(.top, 16)
            .padding(.horizontal, 16)

            ZStack {
                OrbitingParticlesView()
                    .opacity(store.isRecognizingVoice ? 1 : 0)
                    .animation(.easeInOut(duration: 0.3), value: store.isRecognizingVoice)

                ScrollView {
                    ForEach(store.searchSuggestions) { suggestion in
                        HStack(spacing: 0) {
                            Button {
                                store.send(.performSuggestion(suggestion))
                            } label: {
                                ListEntryView(suggestion: suggestion, searchText: store.searchText)
                                    .background(Color.clear)
                            }
                            .buttonStyle(MagicSheetListButtonStyle())

                            if suggestion.type == .search {
                                Button {
                                    store.send(.appendSearchWithSuggestion(suggestion))
                                } label: {
                                    Image(systemSymbol: .arrowUpLeft)
                                        .resizable()
                                        .foregroundStyle(.theme)
                                        .tint(.theme)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 12)
                                        .font(.callout)
                                        .padding(.vertical, 12)
                                        .padding(.leading, 12)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
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

private struct SizePreferenceKey: PreferenceKey {
    typealias Value = CGSize
    static let defaultValue: Value = .zero

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = nextValue()
    }
}
