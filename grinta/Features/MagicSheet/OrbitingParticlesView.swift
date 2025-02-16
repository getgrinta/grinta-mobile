import SwiftUI

struct OrbitingParticle: View {
    let orbitRadius: CGFloat
    let rotationDuration: Double
    let size: CGFloat = 12
    let color: Color

    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate) * 0.6
            let angle = (elapsed.truncatingRemainder(dividingBy: rotationDuration) / rotationDuration) * 2 * Double.pi

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
    @State private var colorToggle: Bool = false
    var body: some View {
        ZStack {
            Circle()
                .stroke((colorToggle ? Color.fuchsia : Color.blue).opacity(0.3), lineWidth: 2)
                .frame(width: 100, height: 100)
            Circle()
                .stroke((colorToggle ? Color.fuchsia : Color.blue).opacity(0.3), lineWidth: 2)
                .frame(width: 160, height: 160)
            Circle()
                .stroke((colorToggle ? Color.fuchsia : Color.blue).opacity(0.3), lineWidth: 2)
                .frame(width: 220, height: 220)
            OrbitingParticle(orbitRadius: 50, rotationDuration: 1, color: colorToggle ? Color.fuchsia : Color.blue)
            OrbitingParticle(orbitRadius: 80, rotationDuration: 3, color: colorToggle ? Color.fuchsia : Color.blue)
            OrbitingParticle(orbitRadius: 110, rotationDuration: 4, color: colorToggle ? Color.fuchsia : Color.blue)
        }
        .frame(width: 300, height: 300)
        .onAppear {
            // Trigger the color toggle animation.
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
