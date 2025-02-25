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
        var zoomLevel: ZoomLevel = .default

        var shareItems: [Any] {
            [url, snapshot as Any].compactMap { $0 }
        }

        var hasCurrentTab: Bool {
            url != nil
        }
    }

    enum ZoomLevel: Int, CaseIterable {
        case fiftyPercent = 50
        case seventyFivePercent = 75
        case `default` = 100
        case oneHundredFiftyPercent = 150
        case twoHundredPercent = 200
        case twoHundredFiftyPercent = 250
        case threeHundredPercent = 300

        var displayText: String {
            "\(rawValue)%"
        }

        var next: ZoomLevel {
            let currentIndex = Self.allCases.firstIndex(of: self)!
            let nextIndex = (currentIndex + 1) % Self.allCases.count
            return Self.allCases[nextIndex]
        }

        var previous: ZoomLevel {
            let currentIndex = Self.allCases.firstIndex(of: self)!
            let previousIndex = (currentIndex - 1 + Self.allCases.count) % Self.allCases.count
            return Self.allCases[previousIndex]
        }
    }

    enum Action {
        case shareCurrentWebsiteTapped
        case copyCurrentWebsiteURLTapped
        case setSharePresented(Bool)
        case setIncognitoMode(Bool)
        case increaseZoom
        case decreaseZoom
        case helpTapped
        case delegate(Delegate)
    }

    enum Delegate: Equatable {
        case incognitoModeChanged(Bool)
        case openHelp
        case zoomChanged(ZoomLevel)
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

            case .increaseZoom:
                state.zoomLevel = state.zoomLevel.next
                return .send(.delegate(.zoomChanged(state.zoomLevel)))

            case .decreaseZoom:
                state.zoomLevel = state.zoomLevel.previous
                return .send(.delegate(.zoomChanged(state.zoomLevel)))

            case .helpTapped:
                return .send(.delegate(.openHelp))

            case .delegate:
                return .none
            }
        }
    }
}
