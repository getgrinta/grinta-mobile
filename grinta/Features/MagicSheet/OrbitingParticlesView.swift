import SwiftUI

private struct OrbitConfiguration {
    let radius: CGFloat
    let rotationDuration: Double
}

struct OrbitingParticle: View {
    let orbitRadius: CGFloat
    let rotationDuration: Double
    let size: CGFloat = 12
    let color: Color

    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = (timeline.date.timeIntervalSince(startDate) * 0.6).remainder(dividingBy: rotationDuration) / rotationDuration
            let angle = progress * 2 * .pi

            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color, radius: 10)
                .offset(x: cos(angle) * orbitRadius,
                        y: sin(angle) * orbitRadius)
        }
    }
}

struct OrbitingParticlesView: View {
    @State private var colorToggle = false

    private static let configurations = [
        OrbitConfiguration(radius: 50, rotationDuration: 1),
        OrbitConfiguration(radius: 80, rotationDuration: 3),
        OrbitConfiguration(radius: 110, rotationDuration: 4),
    ]

    private var currentColor: Color {
        colorToggle ? .fuchsia : .blue
    }

    var body: some View {
        ZStack {
            // Orbit circles
            ForEach(Self.configurations, id: \.radius) { config in
                Circle()
                    .stroke(currentColor.opacity(0.3), lineWidth: 2)
                    .frame(width: config.radius * 2, height: config.radius * 2)
            }

            // Orbiting particles
            ForEach(Self.configurations, id: \.radius) { config in
                OrbitingParticle(
                    orbitRadius: config.radius,
                    rotationDuration: config.rotationDuration,
                    color: currentColor
                )
            }
        }
        .frame(width: 300, height: 300)
        .onAppear {
            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: true)) {
                colorToggle.toggle()
            }
        }
    }
}

struct OrbitingParticlesView_Previews: PreviewProvider {
    static var previews: some View {
        OrbitingParticlesView()
    }
}
