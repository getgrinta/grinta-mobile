import SFSafeSymbols
import SwiftUI

struct TabPickerView: View {
    let namespace: Namespace.ID

    var onSelectedTab: (BrowserTab) -> Void
    var onCloseTab: (BrowserTab) -> Void
    let tabs: [BrowserTab]
    let selectedTabId: BrowserTab.ID?

    var body: some View {
        if tabs.isEmpty == false {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(tabs) { tab in
                        Button {
                            onSelectedTab(tab)
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 4) {
                                    if let faviconURL = tab.faviconURL {
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
                                        .font(.caption)
                                        .lineLimit(1)
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Button {
                                        onCloseTab(tab)
                                    } label: {
                                        Image(systemSymbol: .xmark)
                                            .resizable()
                                            .frame(width: 8, height: 8)
                                    }
                                    .padding(.trailing, 4)
                                    .layoutPriority(1)
                                }
                                .padding(.horizontal, 6)
                                .background(Color.neutral200)
                                .foregroundStyle(Color.neutral600)

                                if let image = tab.snapshot {
                                    image
                                        .resizable()
                                        .aspectRatio(0.85, contentMode: .fit)

                                } else {
                                    Color.neutral100
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipped()
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .matchedGeometryEffect(id: tab.id, in: namespace)
                    }
                }
                .padding()
            }
        } else {
            ZStack {
                Text("No tabs yet ;(")
            }
        }
    }
}

struct BrowserTab: Identifiable, Hashable {
    var id = UUID()

    let creationTime: Date
    let url: URL
    var title: String
    var snapshot: Image?
    var faviconURL: URL?
    var topBrandColor: Color?
    var bottomBrandColor: Color?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview("Default") {
    @Previewable @Namespace var ns

    TabPickerView(namespace: ns, onSelectedTab: { _ in }, onCloseTab: { _ in }, tabs: [
        .init(creationTime: Date(), url: URL(string: "https://www.wp.pl")!, title: "Hello", snapshot: Image(.image1),
              faviconURL: URL(string: "https://allegro.pl/favicon.ico")!),
    ], selectedTabId: nil)
}
