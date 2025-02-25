import SFSafeSymbols
import SwiftUI

struct TabPickerView: View {
    private var onSelectedTab: ((BrowserTab.ID) -> Void)?
    private var onCloseTab: ((BrowserTab.ID) -> Void)?
    var contentOpacity: CGFloat = 1

    let namespace: Namespace.ID
    let tabs: [BrowserTab]
    let lastSelectedTabId: BrowserTab.ID?
    let applyMatchedGeometry: Bool

    init(
        namespace: Namespace.ID,
        tabs: [BrowserTab],
        lastSelectedTabId: BrowserTab.ID? = nil,
        applyMatchedGeometry: Bool
    ) {
        self.namespace = namespace
        self.tabs = tabs
        self.lastSelectedTabId = lastSelectedTabId
        self.applyMatchedGeometry = applyMatchedGeometry
    }

    var body: some View {
        if tabs.isEmpty == false {
            GeometryReader { proxy in
                ScrollView {
                    let halfWidth = (proxy.size.width / 2) - 20

                    let columns = [
                        GridItem(.fixed(halfWidth)),
                        GridItem(.fixed(halfWidth)),
                    ]

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(tabs) { tab in
                            Button {
                                onSelectedTab?(tab.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    TabHeader(tab: tab)
                                        .background(tab.isIncognito ? Color.black : Color.neutral200)
                                        .foregroundColor(tab.isIncognito ? .white : Color.neutral600)
                                    TabContent(tab: tab, width: halfWidth)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    if tab.id == lastSelectedTabId {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.vibrantBlue, lineWidth: 3)
                                    }
                                }
                            }
                            .opacity(contentOpacity)
                            .animation(.easeInOut, value: UUID())
                            .if(applyMatchedGeometry) {
                                $0.matchedGeometryEffect(id: tab.id, in: namespace)
                            }
                        }
                    }
                    .padding()
                }
            }
        } else {
            ZStack {
                Text("You don't have any tabs yet")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func TabContent(tab: BrowserTab, width: CGFloat) -> some View {
        if let image = tab.currentSnapshot {
            image
                .resizable()
                .scaledToFill()
                .frame(width: width)
                .frame(height: 215, alignment: .top)
        } else {
            Color.neutral100
                .frame(height: 215)
                .clipped()
        }
    }

    private func TabHeader(tab: BrowserTab) -> some View {
        HStack(spacing: 4) {
            if let metadata = tab.metadata, let faviconURL = URL(string: metadata.favicon) {
                AsyncImage(url: faviconURL, content: { image in
                    image
                        .resizable()
                        .cornerRadius(6)
                }, placeholder: {
                    EmptyView()
                })
                .frame(width: 16, height: 16)
                .aspectRatio(contentMode: .fill)
                .layoutPriority(1)
            }

            Text(tab.title)
                .padding(.vertical, 6)
                .font(.caption2)
                .lineLimit(1)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onCloseTab?(tab.id)
            } label: {
                Image(systemSymbol: .xmark)
                    .resizable()
                    .frame(width: 10, height: 10)
                    .foregroundStyle(Color.neutral500)
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 10)
            .layoutPriority(1)
        }
        .frame(minHeight: 26)
        .padding(.leading, 6)
    }
}

extension TabPickerView {
    func tabSelected(_ closure: @escaping (BrowserTab.ID) -> Void) -> Self {
        var copy = self
        copy.onSelectedTab = closure
        return copy
    }

    func tabClosed(_ closure: @escaping (BrowserTab.ID) -> Void) -> Self {
        var copy = self
        copy.onCloseTab = closure
        return copy
    }

    func contentOpacity(_ opacity: CGFloat) -> Self {
        var copy = self
        copy.contentOpacity = opacity
        return copy
    }
}

#Preview("Default") {
    @Previewable @Namespace var ns

    @Previewable var tabs: [BrowserTab] = {
        var tabs = [
            BrowserTab(id: UUID(), url: URL(string: "https://www.bbc.co.uk")!),
            BrowserTab(id: UUID(), url: URL(string: "https://www.reddit.com")!),
            BrowserTab(id: UUID(), url: URL(string: "https://www.chip.pl")!),
            BrowserTab(id: UUID(), url: URL(string: "https://www.ebay.de")!),
            BrowserTab(id: UUID(), url: URL(string: "https://www.wp.pl")!),
            BrowserTab(id: UUID(), url: URL(string: "https://www.google.com")!),
            BrowserTab(id: UUID(), url: URL(string: "https://www.apple.com")!),
        ]
        tabs[0].title = "DJI Drone - Mini 3 - Sale"

        return tabs
    }()

    TabPickerView(namespace: ns, tabs: tabs, lastSelectedTabId: tabs[0].id, applyMatchedGeometry: true)
}
