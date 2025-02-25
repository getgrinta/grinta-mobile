import ComposableArchitecture
import SwiftUI

@Reducer
struct Settings {
    @ObservableState
    struct State: Equatable {
        var isSharePresented = false
        var url: URL?
        var snapshot: Image?
        var isIncognitoMode = false

        var shareItems: [Any] {
            [url, snapshot as Any].compactMap { $0 }
        }

        var hasCurrentTab: Bool {
            url != nil
        }
    }

    enum Action {
        case shareCurrentWebsiteTapped
        case copyCurrentWebsiteURLTapped
        case setSharePresented(Bool)
        case setIncognitoMode(Bool)
        case helpTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case incognitoModeChanged(Bool)
        case openHelp
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .shareCurrentWebsiteTapped:
                state.isSharePresented = true
                return .none

            case .copyCurrentWebsiteURLTapped:
                if let url = state.url {
                    UIPasteboard.general.url = url
                }
                return .run { @MainActor _ in
                    try await Task.sleep(for: .seconds(0.1))
                    HapticFeedback.light()
                }

            case let .setSharePresented(isPresented):
                state.isSharePresented = isPresented
                return .none

            case let .setIncognitoMode(isOn):
                state.isIncognitoMode = isOn
                return .send(.delegate(.incognitoModeChanged(isOn)))
                
            case .helpTapped:
                return .send(.delegate(.openHelp))

            case .delegate:
                return .none
            }
        }
    }
}
