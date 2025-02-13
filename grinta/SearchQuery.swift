import Foundation
import RegexBuilder
import WebURL

struct SearchQuery: ExpressibleByStringLiteral, CustomStringConvertible {
    let term: String

    init(_ string: String) {
        term = string
    }

    init(stringLiteral value: StringLiteralType) {
        term = value.trimmingCharacters(in: .whitespacesAndNewlines)
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

    var isWebsiteUrl: Bool {
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

        let regex = Regex {
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

        return (try? regex.wholeMatch(in: url.hostname ?? "")) != nil
    }
}
