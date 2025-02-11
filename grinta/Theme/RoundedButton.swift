import SwiftUI

struct RoundedButton<Embedded: View>: View {
    let action: () -> Void
    let label: () -> Embedded

    var body: some View {
        Button(action: action, label: {
            RoundedView {
                label()
            }
        })
    }
}
