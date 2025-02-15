import SwiftUI

struct RoundedView<Embedded: View>: View {
    let embedded: () -> Embedded

    init(@ViewBuilder embedded: @escaping () -> Embedded) {
        self.embedded = embedded
    }

    var body: some View {
        embedded()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.neutral600.opacity(0.1))
            .mask(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(.neutral600.opacity(0.2), lineWidth: 1)
            )
    }
}
