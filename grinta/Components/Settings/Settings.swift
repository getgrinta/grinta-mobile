import ComposableArchitecture

@Reducer
struct Settings {
    struct State: Equatable {
        let setting = true
    }

    enum Action {
        enum Delegate: Equatable {
            case shareCurrentWebsite
            case copyCurrentWebsiteURL
        }

        case shareCurrentWebsiteTapped
        case copyCurrentWebsiteURLTapped
        case delegate(Delegate)
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .shareCurrentWebsiteTapped:
                return .send(.delegate(.shareCurrentWebsite))
                
            case .copyCurrentWebsiteURLTapped:
                return .send(.delegate(.copyCurrentWebsiteURL))
                
            case .delegate:
                return .none
            }
        }
    }
}
