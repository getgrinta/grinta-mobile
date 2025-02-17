import SwiftUI

struct ListEntryView: View {
    let suggestion: SearchSuggestion
    let searchText: String

    var body: some View {
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

            Text(attributedTitle())
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

    private func attributedTitle() -> AttributedString {
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
    }
}
