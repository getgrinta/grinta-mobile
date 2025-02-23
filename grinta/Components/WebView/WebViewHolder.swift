import SwiftUI
import WebKit

@MainActor
final class WebViewHolder: ObservableObject {
    static let shared = WebViewHolder()
    private var webViews: [BrowserTab.ID: WKWebView] = [:]

    func webView(for tabId: BrowserTab.ID, messageHandler: any WKScriptMessageHandler, coordinator: WebView.Coordinator) -> WKWebView {
        if let view = webViews[tabId] {
            return view
        }

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        let sourceScript = WKUserScript(
            source: """
            window.webkit.messageHandlers.\(UserHandler.source.rawValue).postMessage(document.documentElement.outerHTML);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(sourceScript)
        configuration.userContentController.add(messageHandler, name: UserHandler.source.rawValue)

        setupNavigationHandler(configuration: configuration, messageHandler: messageHandler)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        // webView.customUserAgent = "Grinta/0.1.0"

        // Set up the refresh control.
         let refreshControl = UIRefreshControl()
        refreshControl.addTarget(coordinator, action: #selector(WebView.Coordinator.handleRefresh(_:)), for: .valueChanged)
         webView.scrollView.refreshControl = refreshControl
         

        webViews[tabId] = webView
        return webView
    }

    // Add observation for hash changes and other SPA navigation
    private func setupNavigationHandler(configuration: WKWebViewConfiguration, messageHandler: any WKScriptMessageHandler) {
        // Inject JavaScript to observe URL changes
        let script = """
            function observeURLChanges() {
                let lastURL = window.location.href;
                const observer = new MutationObserver(() => {
                    if (window.location.href !== lastURL) {
                        lastURL = window.location.href;
                        window.webkit.messageHandlers.urlChanged.postMessage(lastURL);
                    }
                });
                observer.observe(document, { subtree: true, childList: true });

                // Listen for popstate events (back/forward)
                window.addEventListener('popstate', () => {
                    window.webkit.messageHandlers.urlChanged.postMessage(window.location.href);
                });
            }
            observeURLChanges();
        """

        let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(userScript)
        configuration.userContentController.add(messageHandler, name: UserHandler.urlChanged.rawValue)
    }
}
