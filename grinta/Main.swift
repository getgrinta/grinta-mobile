import ComposableArchitecture
import Dependencies
import SFSafeSymbols
import SwiftUI

@Reducer
struct Main {
    @CasePathable
    enum Action: BindableAction {
        case search
        case handleChatMessage(ChatOutput)
        case searchTextChanged(String)
        case binding(BindingAction<State>)
    }

    @ObservableState
    struct State {
        var search = ""
        var output = ""
    }

    @Dependency(LLMClient.self) var llmClient

    var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case let .searchTextChanged(query):
                UIImpactFeedbackGenerator(style: .medium).prepare()
                state.search = query
                return .none

            case let .handleChatMessage(message):
                state.output += message.message
                return .none

            case .search:
                let searchQuery = state.search
                state.search = ""

                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                return .run { send in
                    let messages = try await llmClient.streamChat(endpoint: "https://api.openai.com/v1/chat/completions", bearer: "", input: searchQuery)

                    for await message in messages {
                        await send(.handleChatMessage(message))
                    }
                }
            }
        }
    }
}
