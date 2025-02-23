import Foundation
import SwiftUI
import WebKit

enum WebViewNavigationPhase {
    case started(URL)
}

struct WebView: UIViewRepresentable {
    let url: URL?
    let id: UUID
    var onNavigationFinished: ((URL) -> Void)?

    enum ColorPickerRegion {
        case top(CGFloat)
        case bottom(CGFloat)
    }

    private var brandColorClosures: [(region: ColorPickerRegion, closure: @Sendable @MainActor (Color) -> Void)] = []
    private var websiteMetadataClosure: (@Sendable @MainActor (WebsiteMetadata) -> Void)?
    private var snapshotClosure: (@Sendable @MainActor (Image, URL) -> Void)?
    private var navigationClosure: (@Sendable @MainActor (WebViewNavigationPhase) -> Void)?
    private var serverRedirectClosure: (@Sendable @MainActor (URL) -> Void)?

    init(url: URL?, id: UUID) {
        self.url = url
        self.id = id
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            brandColorClosures: brandColorClosures,
            websiteMetadataClosure: websiteMetadataClosure,
            snapshotClosure: snapshotClosure,
            navigationClosure: navigationClosure,
            serverRedirectClosure: serverRedirectClosure
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WebViewHolder.shared.webView(for: id, messageHandler: context.coordinator)
        context.coordinator.lastUILoadedURL = url
        context.coordinator.navigationClosure = navigationClosure
        context.coordinator.snapshotClosure = snapshotClosure
        context.coordinator.websiteMetadataClosure = websiteMetadataClosure
        context.coordinator.serverRedirectClosure = serverRedirectClosure
        context.coordinator.brandColorClosures = brandColorClosures
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator


        // TODO: Redo this logic - we need to store last url for a _tab_, not the WebView...
        if let url, let webViewURL = webView.url, url.isEquivalent(to: webViewURL) == false {
            webView.load(URLRequest(url: url))
        } else if let url, webView.url == nil {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.dismantle()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url else { return }

        webView.navigationDelegate = context.coordinator

        let shouldLoad = context.coordinator.lastUILoadedURL.map { !url.isEquivalent(to: $0) } ?? true
//        if shouldLoad {
//            context.coordinator.lastUILoadedURL = url
//            webView.load(URLRequest(url: url))
//        }
//
//        if context.coordinator.webView != webView {
//            context.coordinator.lastUILoadedURL = url
//            context.coordinator.webView = webView
//        }

        context.coordinator.navigationClosure = navigationClosure
        context.coordinator.snapshotClosure = snapshotClosure
        context.coordinator.websiteMetadataClosure = websiteMetadataClosure
        context.coordinator.brandColorClosures = brandColorClosures
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var brandColorClosures: [(region: ColorPickerRegion, closure: @Sendable @MainActor (Color) -> Void)]
        var websiteMetadataClosure: (@Sendable @MainActor (WebsiteMetadata) -> Void)?
        var snapshotClosure: (@Sendable @MainActor (Image, URL) -> Void)?
        var navigationClosure: (@Sendable @MainActor (WebViewNavigationPhase) -> Void)?
        var serverRedirectClosure: (@Sendable @MainActor (URL) -> Void)?

        var lastUILoadedURL: URL?
        var token: NSKeyValueObservation?
        var urlObserver: NSKeyValueObservation?
        private var lastBrandColorPick: Date = .distantPast

        unowned var webView: WKWebView? {
            didSet {
                guard let webView else { return }

                token?.invalidate()
                token = nil
                urlObserver?.invalidate()
                urlObserver = nil

                token = webView.observe(\.scrollView.contentOffset, options: [.old, .new]) { [weak self] _, change in
                    guard let self, change.oldValue != change.newValue else { return }

                    // TODO: Improve the throttling
                    let now = Date()

                    Task { @MainActor in
                        if now.timeIntervalSince(self.lastBrandColorPick) > 0.3 {
                            self.lastBrandColorPick = now
                            self.pickBrandColors(webView: webView, onlyBottom: true)
                        }
                    }
                }

                var lastEmittedURL: URL?
                // Add URL observation for SPAs
                urlObserver = webView.observe(\.url, options: [.new]) { [weak self] webView, change in
                    Task { @MainActor in
                        guard let self,
                              let newURL = change.newValue ?? webView.url,
                              self.lastUILoadedURL?.absoluteString != newURL.absoluteString,
                              lastEmittedURL != newURL
                        else { return }


                        lastEmittedURL = newURL
                        self.lastUILoadedURL = newURL
                        self.navigationClosure?(.started(newURL))
                    }
                }
            }
        }

        deinit {
            urlObserver?.invalidate()
        }

        init(
            brandColorClosures: [(region: ColorPickerRegion, closure: @Sendable @MainActor (Color) -> Void)],
            websiteMetadataClosure: (@Sendable @MainActor (WebsiteMetadata) -> Void)?,
            snapshotClosure: (@Sendable @MainActor (Image, URL) -> Void)?,
            navigationClosure: (@Sendable @MainActor (WebViewNavigationPhase) -> Void)?,
            serverRedirectClosure: (@Sendable @MainActor (URL) -> Void)?
        ) {
            self.brandColorClosures = brandColorClosures
            self.websiteMetadataClosure = websiteMetadataClosure
            self.snapshotClosure = snapshotClosure
            self.navigationClosure = navigationClosure
            self.serverRedirectClosure = serverRedirectClosure
        }

        func dismantle() {
            print("DISMANTLE")
            urlObserver?.invalidate()
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            if let url = webView.url {
                navigationClosure?(.started(url))
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if let url = navigationAction.request.url {
                // Handle all navigation types that could indicate a page change
                switch navigationAction.navigationType {
                case .linkActivated, .formSubmitted, .backForward, .reload, .formResubmitted:
                    navigationClosure?(.started(url))
                case .other:
                    // For SPAs and AJAX, check if it's a main frame navigation
                    // or if the URL is different from the current one
                    if navigationAction.targetFrame?.isMainFrame == true {
                        navigationClosure?(.started(url))
                    }
                @unknown default:
                    break
                }
            }
            return .allow
        }

        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            if let webViewURL = webView.url {
                serverRedirectClosure?(webViewURL)
            }
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            if let url = webView.url {
                // Update last URL and notify about navigation
                lastUILoadedURL = url
                navigationClosure?(.started(url))
            }

            // Take snapshot and update colors
            Task { @MainActor [snapshotClosure] in
                try await Task.sleep(for: .milliseconds(500))
                let config = WKSnapshotConfiguration()
                config.rect = CGRect(x: 0, y: 0, width: webView.frame.width, height: webView.frame.height)

                let (image, _) = await withCheckedContinuation { continuation in
                    webView.takeSnapshot(with: config) { image, error in
                        continuation.resume(returning: (image, error))
                    }
                }

                if let image, let url = webView.url {
                    snapshotClosure?(Image(uiImage: image), url)
                }
            }
            
            pickBrandColors(webView: webView)
        }

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            switch UserHandler(rawValue: message.name) {
            case .urlChanged:
                if let urlString = message.body as? String,
                   let url = URL(string: urlString) {
                    Task { @MainActor in
                        navigationClosure?(.started(url))
                    }
                }
            case .source:
                handleSourceUserMessage(message: message)
            default:
                print("Unknown user handler called: \(message.name)")
            }
        }

        private func handleSourceUserMessage(message: WKScriptMessage) {
            guard let htmlString = message.body as? String, let host = webView?.url?.host() else { return }

            Task {
                guard let metadataClosure = websiteMetadataClosure else { return }
                do {
                    let metadata = try WebsiteMetadataExtractor().extractMetadata(fromHTML: htmlString, host: host).get()
                    metadataClosure(metadata)
                } catch {
                    print("Failed to decode metadata: \(error)")
                }
            }
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            print("WebView failed with error: \(error.localizedDescription)")
        }

        private func pickBrandColors(webView: WKWebView, onlyBottom: Bool = false) {
            for brandColorClosure in brandColorClosures {
                let webViewRegion: WebViewRegion = switch brandColorClosure.region {
                case let .bottom(value):
                    .bottom(value)
                case let .top(value):
                    .top(value)
                }

                if case WebViewRegion.top = webViewRegion, onlyBottom == true {
                    continue
                }

                Task.detached(priority: .medium) { [brandColorClosure] in
                    let result = await WebViewAverageColorCalculator().calculateAverageColor(
                        for: webView,
                        in: webViewRegion
                    )

                    switch result {
                    case let .success(color):
                        await brandColorClosure.closure(Color(color))
                    case let .failure(failure):
                        print("Failure to pick brand color: \(failure)")
                    }
                }
            }
        }
    }
}

extension WebView {
    func onBrandColorChange(region: ColorPickerRegion, closure: @escaping @Sendable @MainActor (Color) -> Void) -> Self {
        var copy = self
        copy.brandColorClosures += [(region: region, closure: closure)]
        return copy
    }

    func onWebsiteMetadata(closure: @escaping @Sendable @MainActor (WebsiteMetadata) -> Void) -> Self {
        var copy = self
        copy.websiteMetadataClosure = closure
        return copy
    }

    func onSnapshot(closure: @escaping @Sendable @MainActor (Image, URL) -> Void) -> Self {
        var copy = self
        copy.snapshotClosure = closure
        return copy
    }

    func onServerRedirect(closure: @escaping @Sendable @MainActor (URL) -> Void) -> Self {
        var copy = self
        copy.serverRedirectClosure = closure
        return copy
    }

    func onNavigation(closure: @escaping @Sendable @MainActor (WebViewNavigationPhase) -> Void) -> Self {
        var copy = self
        copy.navigationClosure = closure
        return copy
    }

    func onNavigationFinished(closure: @escaping @Sendable @MainActor (URL) -> Void) -> Self {
        var copy = self
        copy.onNavigationFinished = closure
        return copy
    }
}

enum UserHandler: String {
    case source
    case urlChanged
}
