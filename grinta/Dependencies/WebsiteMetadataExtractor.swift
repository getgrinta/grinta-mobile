import Foundation
import SwiftSoup
import WebKit

struct WebsiteMetadata: Codable, Equatable {
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
    func extractMetadata(from webView: WKWebView) async -> Result<WebsiteMetadata, Error> {
        let js = """
        (() => {
            const title = document.title || "";
            const descriptionMeta = document.querySelector("meta[name='description']");
            const description = descriptionMeta ? descriptionMeta.content : "";
            const faviconLink = document.querySelector("head link[rel*='icon']");
            const favicon = faviconLink ? faviconLink.href : "";
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

    func extractMetadata(fromHTML html: String, host: String) -> Result<WebsiteMetadata, Error> {
        do {
            let document = try SwiftSoup.parse(html)
            let title = try document.title()

            // Try different meta description tags in head
            let description = try document.select("head > meta[name=description], head > meta[property=og:description]").first()?.attr("content") ?? ""

            // Look for favicon in head with different rel attributes
            let faviconSelectors = [
                "head > link[rel='icon']",
                "head > link[rel='shortcut icon']",
                "head > link[rel='apple-touch-icon']",
                "head > link[rel='apple-touch-icon-precomposed']",
                "head > link[rel*='icon']",
                "head > link[type='image/x-icon']",
            ]

            let favicon = try faviconSelectors.lazy
                .compactMap { try document.select($0).first()?.attr("href") }
                .first
                .map { href -> String in
                    if href.hasPrefix("http") {
                        return href
                    } else if href.hasPrefix("//") {
                        return "https:" + href
                    } else {
                        return "https://" + host.trimmingCharacters(in: .init(charactersIn: "/")) + "/" + href.trimmingCharacters(in: .init(charactersIn: "/"))
                    }
                } ?? ""

            let metadata = WebsiteMetadata(title: title, description: description, host: host, favicon: favicon)
            return .success(metadata)
        } catch {
            print(error)
            return .failure(error)
        }
    }
}
