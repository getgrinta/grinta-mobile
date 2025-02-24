import Foundation
import RegexBuilder
import WebURL

struct SearchQuery: ExpressibleByStringLiteral, CustomStringConvertible, Codable, Hashable {
    private let term: String
    let websiteURL: URL?
    /// Hostname with stripped scheme and www
    let canonicalHost: String
    let isWebsiteUrl: Bool

    /// Raw query
    var raw: String {
        term
    }

    init(_ string: String) {
        term = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let term = string.trimmingCharacters(in: .whitespacesAndNewlines)

        websiteURL = {
            var urlString = term
            if !urlString.hasPrefix("http"), !urlString.hasPrefix("https") {
                urlString = "https://www." + urlString
            }

            return URL(string: urlString)
        }()

        isWebsiteUrl = {
            var webURLString = term
            if webURLString.hasPrefix("https://") == false, webURLString.hasPrefix("http://") == false {
                webURLString = "https://\(webURLString)"
            }

            guard let url = WebURL(webURLString),
                  let hostname = url.hostname,
                  hostname.hasSuffix(".") == false
            else {
                return false
            }

            return (try? Self.regex.wholeMatch(in: url.hostname ?? "")) != nil
        }()

        canonicalHost =
            term.replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "www.", with: "")
    }

    init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }

    func percentEncoded(withAllowedCharacters allowedCharacters: CharacterSet = .urlQueryAllowed) -> String {
        term.addingPercentEncoding(withAllowedCharacters: allowedCharacters) ?? term
    }

    var description: String {
        term
    }

    var isEmpty: Bool {
        term.isEmpty
    }

    public func trimmingCharacters(in _: CharacterSet) -> String {
        term
    }

    private nonisolated(unsafe) static let regex = Regex {
        Optionally {
            "http"
            Optionally { "s" }
            "://"
        }

        Optionally { "www." }
        OneOrMore { .any }
        "."
        Repeat(2...) { .any }
    }
}
