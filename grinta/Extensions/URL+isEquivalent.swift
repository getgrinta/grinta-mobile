import Foundation

extension URL {
    /// Returns `true` if the receiver is equivalent to the given URL,
    /// comparing scheme, host (ignoring "www."), port, normalized path (empty path is treated as "/"),
    /// and query (empty query "?" is treated the same as no query).
    func isEquivalent(to other: URL) -> Bool {
        guard let components1 = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let components2 = URLComponents(url: other, resolvingAgainstBaseURL: false)
        else {
            return false
        }

        let normalizedPath: (String) -> String = { path in
            path.isEmpty ? "/" : path
        }

        let normalizeHost: (String?) -> String? = { host in
            host?.lowercased().replacingOccurrences(of: "www.", with: "")
        }

        let normalizeQuery: (String?) -> String? = { query in
            query.flatMap { $0.isEmpty ? nil : $0 }
        }

        return components1.scheme?.lowercased() == components2.scheme?.lowercased() &&
            normalizeHost(components1.host) == normalizeHost(components2.host) &&
            components1.port == components2.port &&
            normalizedPath(components1.path) == normalizedPath(components2.path) &&
            normalizeQuery(components1.query) == normalizeQuery(components2.query)
    }
}
