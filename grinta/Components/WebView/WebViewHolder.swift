import SwiftUI
import WebKit

@MainActor
final class WebViewHolder: ObservableObject {
    static let shared = WebViewHolder()
    private var webViews: [BrowserTab.ID: WKWebView] = [:]

    func webView(for tabId: BrowserTab.ID, messageHandler: any WKScriptMessageHandler, coordinator: WebView.Coordinator, isIncognito: Bool = false, zoomLevel _: CGFloat = 1.0) -> WKWebView {
        if let view = webViews[tabId] {
            return view
        }

        let configuration = createConfiguration(messageHandler: messageHandler, isIncognito: isIncognito)

        setupNavigationHandler(configuration: configuration, messageHandler: messageHandler)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true

        #if DEBUG
            webView.isInspectable = true
        #endif

        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(coordinator, action: #selector(WebView.Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        // webView.scrollView.minimumZoomScale = 0.5
        // webView.scrollView.maximumZoomScale = 2.0
        // webView.scrollView.zoomScale = zoomLevel

        webViews[tabId] = webView
        return webView
    }

    private func createConfiguration(messageHandler: any WKScriptMessageHandler, isIncognito: Bool) -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.websiteDataStore = isIncognito ? .nonPersistent() : .default()
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile

        let sourceScript = WKUserScript(
            source: """
            window.webkit.messageHandlers.\(UserHandler.source.rawValue).postMessage(document.documentElement.outerHTML);
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(sourceScript)
        configuration.userContentController.add(messageHandler, name: UserHandler.source.rawValue)

        return configuration
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

        let historySource = """
        (function() {
            function sendHistoryChange() {
                window.webkit.messageHandlers.historyChanged.postMessage({
                    url: window.location.href,
                    state: history.state
                });
            }

            // Override pushState.
            var originalPushState = history.pushState;
            history.pushState = function() {
                originalPushState.apply(history, arguments);
                sendHistoryChange();
            };

            // Override replaceState.
            var originalReplaceState = history.replaceState;
            history.replaceState = function() {
                originalReplaceState.apply(history, arguments);
                sendHistoryChange();
            };

            // Listen for popstate events.
            window.addEventListener('popstate', function() {
                sendHistoryChange();
            });
        })();
        """
        let historyUserScript = WKUserScript(source: historySource,
                                             injectionTime: .atDocumentEnd,
                                             forMainFrameOnly: false)
        configuration.userContentController.addUserScript(historyUserScript)

        // Register the message handler.
        configuration.userContentController.add(messageHandler, name: UserHandler.historyChanged.rawValue)
    }
}
