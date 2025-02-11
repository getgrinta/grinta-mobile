import RegexBuilder
import SwiftUI

struct MagicSheetView: View {
    private static let presentationDetents: Set<PresentationDetent> = [
        .height(40),
        .height(100),
        .height(200),
        .medium
    ]

    private enum Mode {
        case minimized
        case full
    }

    @State var searchText = ""
    @State var selectedDetent: PresentationDetent = .medium
    @State private var mode: Mode = .full
    @State var searchBarAccessoriesVisible = true
    @State var sheetHeight: CGFloat = 400
    @State var cornerRadius: CGFloat = 48

    let settingsPresented: () -> Void
    let openURL: (URL) -> Void

    private var searchBarContainsText: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    var body: some View {
        GeometryReader { viewSize in
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    FullView()
                        .opacity(min(1, max(0, (sheetHeight - CGFloat(80)) / CGFloat(40))))
                        .allowsHitTesting(mode == .full)

                    MiniView()
                        .opacity(min(1, max(0, CGFloat(2) - sheetHeight / CGFloat(50))))
                        .allowsHitTesting(mode == .minimized)
                }
            }
            .onChange(of: viewSize.size) { _, _ in
                cornerRadius = max(0, min(48, viewSize.size.height - 120))
                sheetHeight = viewSize.size.height
            }
        }
        .presentationDetents(Self.presentationDetents, selection: $selectedDetent)
        .interactiveDismissDisabled()
        .presentationBackground(.thinMaterial)
        .presentationDragIndicator(mode == .full ? .visible : .hidden)
        .presentationCornerRadius(cornerRadius)
        .onChange(of: searchText) { old, new in
            let oldValue = old.isEmpty
            let newValue = new.isEmpty

            if oldValue != newValue {
                withAnimation {
                    searchBarAccessoriesVisible = newValue
                }
            }
        }
        .onChange(of: selectedDetent) { _, new in
            switch new {
            case .height(40):
                mode = .minimized

            default:
                mode = .full
            }
        }
        .ignoresSafeArea(.all)
        .presentationBackgroundInteraction(.enabled)
    }

    private func MiniView() -> some View {
        ZStack {
            RoundedButton {
                selectedDetent = .medium
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
                        TextField("Search", text: $searchText)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .onKeyPress { _ in
                                UIImpactFeedbackGenerator().prepare()
                                return .ignored
                            }
                            .onKeyPress(.return) {
                                performDefaultSearchAction(searchText)
                                return .handled
                            }
                            .foregroundColor(.neutral200)
                            .font(.title3)

                        if searchBarContainsText {
                            Spacer()
                                .frame(width: 30)
                        }
                    }
                }
                .overlay(alignment: .trailing) {
                    if searchBarContainsText {
                        Button {
                            searchText = ""
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
                .animation(.easeInOut, value: searchText.isEmpty)
                .layoutPriority(1)

                if searchBarAccessoriesVisible {
                    RoundedButton {} label: {
                        Image(.layoutGrid)
                            .font(.title3)
                            .foregroundStyle(.themePrimary)
                    }
                    .foregroundColor(.neutral400)
                    .font(.title3)
                    .animation(.easeInOut(duration: 0.1), value: searchBarAccessoriesVisible)

                    RoundedButton {
                        settingsPresented()
                    } label: {
                        Image(.menu)
                            .font(.title3)
                            .foregroundStyle(.themeSecondary)
                    }
                    .foregroundColor(.neutral400)
                    .font(.title3)
                    .animation(.easeInOut(duration: 0.1), value: searchBarAccessoriesVisible)
                }
            }
            .padding(.top, 32)
            .padding(.horizontal, 24)

            List {
                ForEach(suggestedItems()) { listItem in
                    Button {
                        listItem.action()
                        searchText = ""
                    } label: {
                        ListEntryView(image: listItem.image, title: listItem.title, type: listItem.type)
                    }
                    .buttonStyle(MagicSheetListButtonStyle())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
        }
    }

    // Move to DataClient
    private func suggestedItems() -> [ListItem] {
        let searchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard searchText.isEmpty == false else { return [] }

        let regex = Regex {
            OneOrMore(.any)
            "."
            OneOrMore(.any)
        }

        let defaultItems = [
            ListItem(title: searchText, image: .stickyNote, type: "Create Note", action: {}),
        ]

        let urlCanBeSearched = (try? regex.wholeMatch(in: searchText)) != nil

        let searchWebItem = ListItem(title: searchText, image: .globe, type: "Search Web") {
            performDefaultSearchAction(searchText)
        }

        return defaultItems + (urlCanBeSearched ? [searchWebItem] : [])
    }

    private func performDefaultSearchAction(_ searchText: String) {
        var urlString = searchText

        if urlString.hasPrefix("http") == false, urlString.hasPrefix("https") == false {
            urlString = "https://www.\(urlString)"
        }

        if let url = URL(string: urlString) {
            openURL(url)
        }

        UIImpactFeedbackGenerator().impactOccurred(intensity: 0.7)

        selectedDetent = .height(40)
    }

    private func ListEntryView(image: ImageResource, title: String, type: String) -> some View {
        HStack(spacing: 12) {
            Image(image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 30)
                .layoutPriority(0)
                .font(.title3)

            Text(title)
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
