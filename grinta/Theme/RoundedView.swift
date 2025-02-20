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

struct MagicRoundedView<Embedded: View>: View {
    @State private var gradientPosition: CGFloat = -1.0
    private let isMagicEnabled: Bool
    private let embedded: () -> Embedded

    init(isMagicEnabled: Bool, @ViewBuilder embedded: @escaping () -> Embedded) {
        self.isMagicEnabled = isMagicEnabled
        self.embedded = embedded
    }

    var body: some View {
        embedded()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.neutral600.opacity(0.1))
            .mask(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: isMagicEnabled ? [Color.blue, Color.fuchsia, Color.blue] : [Color.neutral200, Color.neutral200, Color.neutral200]),
                        startPoint: UnitPoint(x: gradientPosition, y: gradientPosition),
                        endPoint: UnitPoint(x: gradientPosition + 1, y: gradientPosition + 1)
                    ),
                    lineWidth: isMagicEnabled ? 2 : 1
                )
                .onChange(of: isMagicEnabled) { _, newValue in
                    if newValue {
                        gradientPosition = -1.0
                        withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                            gradientPosition = 1.0
                        }
                    }
                }
                .opacity(0.5)
            )
            .animation(.easeInOut, value: isMagicEnabled)
    }
}

extension View {
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
