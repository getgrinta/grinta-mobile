import SwiftUI
import WebKit

@MainActor
final class WebViewHolder: ObservableObject {
    static let shared = WebViewHolder()
    private var webViews: [UUID: WKWebView] = [:]

    func webView(for id: UUID, messageHandler: any WKScriptMessageHandler) -> WKWebView {
        if let view = webViews[id] {
            return view
        }

        let configuration = WKWebViewConfiguration()
        let sourceScript = WKUserScript(
            source: """
            window.webkit.messageHandlers.\(UserHandler.source.rawValue).postMessage(document.documentElement.outerHTML);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(sourceScript)
        configuration.userContentController.add(messageHandler, name: UserHandler.source.rawValue)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        // Configure WKWebView as needed
        webViews[id] = webView
        return webView
    }
}
