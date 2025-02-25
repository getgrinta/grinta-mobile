import SwiftUI

struct ProgressIndicator: View {
    let progress: Double
    var height: CGFloat = 2
    var backgroundColor: Color = .clear
    var foregroundColor: Color = .blue

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(backgroundColor)
                    .frame(width: geometry.size.width, height: height)

                LinearGradient(
                    gradient: Gradient(colors: [foregroundColor, foregroundColor.opacity(0.7)]),
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
        ProgressIndicator(progress: 0.3, foregroundColor: .blue)
        ProgressIndicator(progress: 0.5, foregroundColor: .green)
        ProgressIndicator(progress: 0.8, foregroundColor: .orange)
        ProgressIndicator(progress: 1.0, foregroundColor: .red)
    }
    .padding()
}
