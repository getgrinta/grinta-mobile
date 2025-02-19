import ComposableArchitecture

@Reducer
struct Settings {
    struct State {
        let setting = true
    }

    enum Action {
        case dummy
    }
}
