import Foundation

struct HistoryItem: Hashable {
    enum ItemType {
        case website
        case search
    }

    let query: String
    let type: ItemType
}

final class TrieNode {
    var children: [Character: TrieNode] = [:]
    var isEndOfQuery: Bool = false
    var historyItem: HistoryItem?
}

final class SearchHistoryMatcher {
    private let root = TrieNode()

    // Build the trie using both letters and digits.
    func buildTrie(from histories: [HistoryItem]) {
        for history in histories {
            insert(history.query, item: history)
        }
    }

    private func insert(_ query: String, item: HistoryItem) {
        var node = root
        // Include letters and digits, so that extra characters (like "4") matter.
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

    // Search returns up to 'limit' matching HistoryItems.
    func search(query: String, limit: Int = 10) -> [HistoryItem] {
        // Use the same filtering so that digits are preserved.
        let chars = Array(query.lowercased().filter { $0.isLetter || $0.isNumber })
        var results = [HistoryItem]()
        var seen = Set<HistoryItem>()
        fuzzyMatchAll(node: root, chars: chars, queryIndex: 0, results: &results, limit: limit, seen: &seen)
        return results
    }

    // Recursively search for matches by allowing skips.
    private func fuzzyMatchAll(node: TrieNode,
                               chars: [Character],
                               queryIndex: Int,
                               results: inout [HistoryItem],
                               limit: Int,
                               seen: inout Set<HistoryItem>)
    {
        // If all search characters have been matched,
        // collect all terminal (complete) history items from this subtree.
        if queryIndex == chars.count {
            collectTerminalNodes(from: node, results: &results, limit: limit, seen: &seen)
            return
        }

        let currentChar = chars[queryIndex]

        // Try all children:
        for (key, child) in node.children {
            // If the child's key matches the current search char, "consume" it.
            if key == currentChar {
                fuzzyMatchAll(node: child, chars: chars, queryIndex: queryIndex + 1, results: &results, limit: limit, seen: &seen)
                if results.count >= limit { return }
            }
            // Also allow skipping characters in the stored query.
            fuzzyMatchAll(node: child, chars: chars, queryIndex: queryIndex, results: &results, limit: limit, seen: &seen)
            if results.count >= limit { return }
        }
    }

    // DFS to collect terminal nodes from the given node.
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
