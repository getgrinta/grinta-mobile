import SwiftUI

struct ProgressIndicator: View {
    let progress: Double
    var height: CGFloat = 2
    var backgroundColor: Color = .clear
    var foregroundColor: Color = .red
    var foregroundColor2: Color = .vibrantBlue

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(backgroundColor)
                    .frame(width: geometry.size.width, height: height)

                LinearGradient(
                    gradient: Gradient(colors: [foregroundColor, foregroundColor2]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geometry.size.width * CGFloat(progress), height: height)
                .animation(.easeInOut(duration: 0.2), value: progress)
            }
        }
        .frame(height: height)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        ProgressIndicator(progress: 0.3)
        ProgressIndicator(progress: 0.5)
        ProgressIndicator(progress: 0.8)
        ProgressIndicator(progress: 1.0)
    }
    .padding()
}
