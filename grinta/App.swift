import SwiftUI
import ComposableArchitecture

@main
struct Application: App {
    var body: some Scene {
        WindowGroup {
            MainView(store: Store(
                initialState: Main.State()
            ) {
                Main()
            })
        }
    }
}
