import ComposableArchitecture
import Dependencies
import SFSafeSymbols
import SwiftUI

@Reducer
struct Main {
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case magicSheet(MagicSheet.Action)
    }

    @ObservableState
    struct State {
        var magicSheet = MagicSheet.State()
        var currentURL: URL?
    }

    @Dependency(LLMClient.self) var llmClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .magicSheet(action):
                switch action {
                case let .delegate(.openURL(url)):
                    print("REPLACE to \(url)")
                    state.currentURL = url
                    return .none

                default:
                    return .none
                }
            }
        }

        Scope(state: \.magicSheet, action: \.magicSheet) {
            MagicSheet()
        }
    }
}
