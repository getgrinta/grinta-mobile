import Foundation
import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    private var brandColorClosure: ((Color) -> Void) = { _ in }

    init(url: URL) {
        self.url = url
    }

    init(url: URL, brandColorClosure: @escaping ((Color) -> Void)) {
        self.url = url
        self.brandColorClosure = brandColorClosure
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, brandColorClosure: brandColorClosure)
    }

    func onBrandColorChange(_ closure: @escaping (Color) -> Void) -> Self {
        Self(url: url, brandColorClosure: closure)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Initial load
        guard webView.url != nil else {
            context.coordinator.lastUILoadedURL = url
            webView.load(URLRequest(url: url))
            return
        }

        // Reload only if the url supplied to WebView changes
        // Not if it's different from the current url
        if let lastLoadedURL = context.coordinator.lastUILoadedURL,
            url.isEquivalent(to: lastLoadedURL) == false {
            context.coordinator.lastUILoadedURL = url
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: WebView
        let brandColorClosure: (Color) -> Void
        var lastUILoadedURL: URL?

        init(_ parent: WebView, brandColorClosure: @escaping (Color) -> Void) {
            self.parent = parent
            self.brandColorClosure = brandColorClosure
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            pickTopBrandColor(webView: webView)
        }

        func webView(_ webView: WKWebView, didCommit _: WKNavigation!) {
            pickTopBrandColor(webView: webView)
        }

        private func pickTopBrandColor(webView: WKWebView) {
            WebViewAverageColorCalculator().calculateAverageColor(
                for: webView,
                in: .top(20)
            ) { result in
                switch result {
                case let .success(color):
                    self.brandColorClosure(Color(color))
                case let .failure(failure):
                    print("Failure: \(failure)")
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
            pickTopBrandColor(webView: webView)
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            print("WebView failed with error: \(error.localizedDescription)")
        }
    }
}
