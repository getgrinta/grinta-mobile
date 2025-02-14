import Foundation
import WebKit

struct WebsiteMetadata: Decodable {
    let title: String
    let description: String
    let host: String
    let favicon: String
}

enum WebsiteMetadataExtractorError: Error {
    case invalidResult
}

@MainActor
final class WebsiteMetadataExtractor {
    /// Extracts website metadata (title, description, and favicon) from the head of the document.
    /// - Parameter webView: A WKWebView instance that has loaded a webpage.
    /// - Returns: A Result containing a WebsiteMetadata struct, or an error.
    func extractMetadata(from webView: WKWebView) async -> Result<WebsiteMetadata, Error> {
        // JavaScript to extract the title, description, and favicon.
        let js = """
        (() => {
            const title = document.title || "";
            const descriptionMeta = document.querySelector("meta[name='description']");
            const description = descriptionMeta ? descriptionMeta.content : "";
            const faviconLink = document.querySelector("head link[rel*='icon']");
            const favicon = faviconLink ? faviconLink.href : "";
            // location.origin returns the scheme, host, and port.
            const host = location.origin || (location.protocol + '//' + location.host);
            return { title, description, favicon, host };
        })();
        """

        do {
            let result = try await ((webView.evaluateJavaScript(js)) as? [String: Any]) ?? [:]
            let data = try JSONSerialization.data(withJSONObject: result)

            return Result {
                do {
                    return try JSONDecoder().decode(WebsiteMetadata.self, from: data)
                } catch {
                    throw WebsiteMetadataExtractorError.invalidResult
                }
            }
        } catch {
            return .failure(error)
        }
    }
}
