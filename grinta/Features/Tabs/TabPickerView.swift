import SwiftUI

struct TabPickerView: View {
    let namespace: Namespace.ID

    var onSelectedTab: (BrowserTab) -> Void
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
                            if let image = tab.snapshot {
                                image
                                    .resizable()
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.neutral100, lineWidth: 2)
                                    )
                                    .shadow(radius: 3)
                            } else {
                                Color.neutral100
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipped()
                            }
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
    let title: String
    let url: URL
    var snapshot: Image?

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview("Default") {
    @Previewable @Namespace var ns

    TabPickerView(namespace: ns, onSelectedTab: { _ in }, tabs: [
        .init(creationTime: Date(), title: "Hello", url: URL(string: "https://www.wp.pl")!),
    ], selectedTabId: nil)
}
