import ComposableArchitecture

@Reducer
struct Settings {
    struct State {
        let setting = true
    }

    enum Action {
        enum Delegate {
            case shareCurrentWebsite
            case copyCurrentWebsiteURL
        }

        case shareCurrentWebsiteTapped
        case copyCurrentWebsiteURLTapped
        case delegate(Delegate)
    }
}
