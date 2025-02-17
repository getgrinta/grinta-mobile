import Foundation

struct HistoryItem: Hashable, Codable {
    enum ItemType: Codable {
        case website
        case search
    }

    let query: SearchQuery
    let type: ItemType
}

final class TrieNode {
    var children: [Character: TrieNode] = [:]
    var isEndOfQuery: Bool = false
    var historyItem: HistoryItem?
}

final class SearchHistoryMatcher {
    private let root = TrieNode()

    func buildTrie(from histories: [HistoryItem]) {
        for history in histories {
            insert(history.query.raw, item: history)
        }
    }

    private func insert(_ query: String, item: HistoryItem) {
        var node = root
        for char in query.lowercased().filter({ $0.isLetter || $0.isNumber }) {
            if let child = node.children[char] {
                node = child
            } else {
                let newNode = TrieNode()
                node.children[char] = newNode
                node = newNode
            }
        }
        node.isEndOfQuery = true
        node.historyItem = item
    }

    func search(query: String, limit: Int = 10) -> [HistoryItem] {
        let chars = Array(query.lowercased().filter { $0.isLetter || $0.isNumber })
        var results = [HistoryItem]()
        var seen = Set<HistoryItem>()
        fuzzyMatchAll(node: root, chars: chars, queryIndex: 0, results: &results, limit: limit, seen: &seen)
        return results
    }

    private func fuzzyMatchAll(node: TrieNode,
                               chars: [Character],
                               queryIndex: Int,
                               results: inout [HistoryItem],
                               limit: Int,
                               seen: inout Set<HistoryItem>)
    {
        if queryIndex == chars.count {
            collectTerminalNodes(from: node, results: &results, limit: limit, seen: &seen)
            return
        }

        let currentChar = chars[queryIndex]

        for (key, child) in node.children {
            if key == currentChar {
                fuzzyMatchAll(node: child, chars: chars, queryIndex: queryIndex + 1, results: &results, limit: limit, seen: &seen)
                if results.count >= limit { return }
            }
            fuzzyMatchAll(node: child, chars: chars, queryIndex: queryIndex, results: &results, limit: limit, seen: &seen)
            if results.count >= limit { return }
        }
    }

    private func collectTerminalNodes(from node: TrieNode,
                                      results: inout [HistoryItem],
                                      limit: Int,
                                      seen: inout Set<HistoryItem>)
    {
        if node.isEndOfQuery, let item = node.historyItem, !seen.contains(item) {
            results.append(item)
            seen.insert(item)
            if results.count >= limit { return }
        }
        for (_, child) in node.children {
            collectTerminalNodes(from: child, results: &results, limit: limit, seen: &seen)
            if results.count >= limit { return }
        }
    }
}
