import Foundation

extension URL {
    /// Returns `true` if the receiver is equivalent to the given URL,
    /// considering scheme, host, port, normalized path (empty path is treated as "/"), and query.
    func isEquivalent(to other: URL) -> Bool {
        guard let comp1 = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let comp2 = URLComponents(url: other, resolvingAgainstBaseURL: false)
        else {
            return false
        }

        let path1 = comp1.path.isEmpty ? "/" : comp1.path
        let path2 = comp2.path.isEmpty ? "/" : comp2.path

        return comp1.scheme?.lowercased() == comp2.scheme?.lowercased() &&
            comp1.host?.lowercased().replacingOccurrences(of: "www.", with: "") ==
            comp2.host?.lowercased().replacingOccurrences(of: "www.", with: "") &&
            comp1.port == comp2.port &&
            path1 == path2 &&
            comp1.query == comp2.query
    }
}
