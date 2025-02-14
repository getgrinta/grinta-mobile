import Foundation
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL

    enum ColorPickerRegion {
        case top(CGFloat)
        case bottom(CGFloat)
    }

    private var brandColorClosures: [(region: ColorPickerRegion, closure: @Sendable @MainActor (Color) -> Void)] = []
    private var websiteMetadataClosure: (@Sendable @MainActor (WebsiteMetadata) -> Void)?

    init(url: URL) {
        self.url = url
    }

    init(
        url: URL,
        brandColorClosures: [(region: ColorPickerRegion, closure: @Sendable @MainActor (Color) -> Void)],
        websiteMetadataClosure: (@Sendable @MainActor (WebsiteMetadata) -> Void)?
    ) {
        self.url = url
        self.brandColorClosures = brandColorClosures
        self.websiteMetadataClosure = websiteMetadataClosure
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, brandColorClosures: brandColorClosures, websiteMetadataClosure: websiteMetadataClosure)
    }

    func onBrandColorChange(region: ColorPickerRegion, closure: @escaping @Sendable @MainActor (Color) -> Void) -> Self {
        Self(url: url, brandColorClosures: brandColorClosures + [(region: region, closure: closure)], websiteMetadataClosure: websiteMetadataClosure)
    }

    func onWebsiteMetadata(closure: @escaping @Sendable @MainActor (WebsiteMetadata) -> Void) -> Self {
        Self(url: url, brandColorClosures: brandColorClosures, websiteMetadataClosure: closure)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        context.coordinator.lastUILoadedURL = url
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Reload only if the url supplied to WebView changes
        // Not if it's different from the current url
        guard let lastLoadedURL = context.coordinator.lastUILoadedURL,
              url.isEquivalent(to: lastLoadedURL) == false
        else {
            return
        }

        context.coordinator.lastUILoadedURL = url
        webView.load(URLRequest(url: url))
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        let brandColorClosures: [(region: ColorPickerRegion, closure: @Sendable @MainActor (Color) -> Void)]
        let websiteMetadataClosure: (@Sendable @MainActor (WebsiteMetadata) -> Void)?
        var lastUILoadedURL: URL?
        var token: NSKeyValueObservation?

        unowned var webView: WKWebView? {
            didSet {
                guard let webView else { return }

                token?.invalidate()
                token = nil
                token = webView.observe(\.scrollView.contentOffset, options: [.new]) { _, _ in
                    Task {
                        await self.pickBrandColors(webView: webView, onlyBottom: true)
                    }
                }
            }
        }

        init(
            _ parent: WebView,
            brandColorClosures: [(region: ColorPickerRegion, closure: @Sendable @MainActor (Color) -> Void)],
            websiteMetadataClosure: (@Sendable @MainActor (WebsiteMetadata) -> Void)?
        ) {
            self.parent = parent
            self.brandColorClosures = brandColorClosures
            self.websiteMetadataClosure = websiteMetadataClosure

            print("Creating coordinator with closure: is nil: \(websiteMetadataClosure == nil) ")
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
                        await brandColorClosure.closure(Color(color))
                    case let .failure(failure):
                        print("Failure: \(failure)")
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            pickBrandColors(webView: webView)

            Task<Void, Never> {
                guard let metadataClosure = websiteMetadataClosure else { return }
                guard let metadata = try? await WebsiteMetadataExtractor().extractMetadata(from: webView).get() else { return }
                metadataClosure(metadata)
            }
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            print("WebView failed with error: \(error.localizedDescription)")
        }
    }
}
