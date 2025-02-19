import Foundation
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL?
    let id: UUID

    enum ColorPickerRegion {
        case top(CGFloat)
        case bottom(CGFloat)
    }

    private var brandColorClosures: [(region: ColorPickerRegion, closure: @Sendable @MainActor (Color) -> Void)] = []
    private var websiteMetadataClosure: (@Sendable @MainActor (WebsiteMetadata) -> Void)?
    private var snapshotClosure: (@Sendable @MainActor (Image) -> Void)?

    init(url: URL?, id: UUID) {
        self.url = url
        self.id = id
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, brandColorClosures: brandColorClosures, websiteMetadataClosure: websiteMetadataClosure, snapshotClosure: snapshotClosure)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WebViewHolder.shared.webView(for: id, messageHandler: context.coordinator)
        context.coordinator.lastUILoadedURL = url
        context.coordinator.webView = webView
        webView.navigationDelegate = context.coordinator

        if let url {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url else { return }

        webView.navigationDelegate = context.coordinator

        let shouldLoad = context.coordinator.lastUILoadedURL.map { !url.isEquivalent(to: $0) } ?? true
        if shouldLoad {
            context.coordinator.lastUILoadedURL = url
            webView.load(URLRequest(url: url))
        }

        if context.coordinator.webView != webView {
            context.coordinator.lastUILoadedURL = url
            context.coordinator.webView = webView
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: WebView
        let brandColorClosures: [(region: ColorPickerRegion, closure: @Sendable @MainActor (Color) -> Void)]
        let websiteMetadataClosure: (@Sendable @MainActor (WebsiteMetadata) -> Void)?
        let snapshotClosure: (@Sendable @MainActor (Image) -> Void)?
        var lastUILoadedURL: URL?
        var token: NSKeyValueObservation?
        private var lastBrandColorPick: Date = .distantPast

        unowned var webView: WKWebView? {
            didSet {
                guard let webView else { return }

                token?.invalidate()
                token = nil

                // Throttle & cancel previous tasks
                token = webView.observe(\.scrollView.contentOffset, options: [.old, .new]) { [weak self] _, change in
                    guard let self, change.oldValue != change.newValue else { return }

                    // TODO: Improve the throttling
                    let now = Date()
                    if now.timeIntervalSince(lastBrandColorPick) > 0.3 {
                        lastBrandColorPick = now
                        Task {
                            await self.pickBrandColors(webView: webView, onlyBottom: true)
                        }
                    }
                }
            }
        }

        init(
            _ parent: WebView,
            brandColorClosures: [(region: ColorPickerRegion, closure: @Sendable @MainActor (Color) -> Void)],
            websiteMetadataClosure: (@Sendable @MainActor (WebsiteMetadata) -> Void)?,
            snapshotClosure: (@Sendable @MainActor (Image) -> Void)?
        ) {
            self.parent = parent
            self.brandColorClosures = brandColorClosures
            self.websiteMetadataClosure = websiteMetadataClosure
            self.snapshotClosure = snapshotClosure
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            pickBrandColors(webView: webView)
        }

        func webView(_ webView: WKWebView, didCommit _: WKNavigation!) {
            pickBrandColors(webView: webView)
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
                        if case WebViewRegion.top = webViewRegion {
                            print("Picked top color \(color)")
                        }
                        await brandColorClosure.closure(Color(color))
                    case let .failure(failure):
                        print("Failure to pick brand color: \(failure)")
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            guard webView == self.webView else { return }
            pickBrandColors(webView: webView)

            Task { @MainActor [snapshotClosure] in
                try await Task.sleep(for: .milliseconds(500))
                let config = WKSnapshotConfiguration()

                // take smaller dim??
                // fix warnings
                // make only 1 snapshot and pass to colors etc
                config.rect = CGRect(x: 0, y: 0, width: webView.frame.width, height: webView.frame.width * 1.176)
                // Snapshot must be taken on the main thread.
                let (image, error) = await withCheckedContinuation { continuation in
                    webView.takeSnapshot(with: config) { image, error in
                        continuation.resume(returning: (image, error))
                    }
                }

                if let image {
                    snapshotClosure?(Image(uiImage: image))
                }
            }
        }

        func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
            switch UserHandler(rawValue: message.name) {
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

    func onSnapshot(closure: @escaping @Sendable @MainActor (Image) -> Void) -> Self {
        var copy = self
        copy.snapshotClosure = closure
        return copy
    }
}

enum UserHandler: String {
    case source
}
