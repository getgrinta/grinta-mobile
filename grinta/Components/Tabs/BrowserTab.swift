import SwiftUI

struct BrowserTab: Identifiable, Hashable {
    struct HistoryItem: Equatable {
        let url: URL
        var snapshot: Image?
    }

    var id: UUID
    let creationTime: Date
    var title: String
    var faviconURL: URL?
    var topBrandColor: Color?
    var bottomBrandColor: Color?
    var wasLoaded = false

    private(set) var history: [HistoryItem] = []
    var currentHistoryIndex: Int

    var url: URL {
        didSet {
            if oldValue.isEquivalent(to: url) == false {
                appendToHistory(url)
                print("Adding url \(url) to history tab \(id)")
            }
        }
    }

    var previousSnapshot: Image? {
        guard currentHistoryIndex > 0 else { return nil }
        return history[currentHistoryIndex - 1].snapshot
    }

    var canGoBack: Bool {
        currentHistoryIndex > 0
    }

    var canGoForward: Bool {
        currentHistoryIndex < history.count - 1
    }

    init(id: UUID, url: URL) {
        creationTime = Date()
        self.url = url
        title = url.absoluteString
        history = [HistoryItem(url: url, snapshot: nil)]
        currentHistoryIndex = 0
        self.id = id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    mutating func handleServerRedirect(to url: URL) {
        print("Before history count \(history.count)")

        print("Current history is \(history)")

        guard history.count > 1 else {
            print("Not removing anything")
            return
        }

        if currentHistoryIndex >= history.count - 2 {
            currentHistoryIndex -= 1
        }

        let toRemove = history[history.count - 2]

        print("Removing \(toRemove)")

        history.remove(at: history.count - 2)

        print("After history count \(history.count)")
    }

    mutating func appendToHistory(_ url: URL) {
        let wentBack = currentHistoryIndex < history.count - 1
        if wentBack {
            print("WENT BACK")
            history.removeSubrange((currentHistoryIndex + 1)...)

            print("NOW HISTORY IS \(history)")
        } else {
            history.append(HistoryItem(url: url, snapshot: nil))
            currentHistoryIndex = history.count - 1
        }
    }

    mutating func updateSnapshot(_ snapshot: Image, forURL url: URL) {
        for (index, _) in history.enumerated() {
            if history[index].url.normalized == url.normalized {
                history[index].snapshot = snapshot
            }
        }
    }

    mutating func goBack() {
        guard canGoBack else { return }

        currentHistoryIndex -= 1
        url = history[currentHistoryIndex].url
    }

    mutating func goForward() {
        guard canGoForward else { return }

        currentHistoryIndex += 1
        url = history[currentHistoryIndex].url
    }
}
