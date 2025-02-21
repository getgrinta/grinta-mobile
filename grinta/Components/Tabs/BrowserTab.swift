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
    
    mutating func appendToHistory(_ url: URL) {
        if currentHistoryIndex < history.count - 1 {
            history.removeSubrange((currentHistoryIndex + 1)...)
        }
        
        history.append(HistoryItem(url: url, snapshot: nil))
        currentHistoryIndex = history.count - 1
    }
    
    mutating func updateCurrentSnapshot(_ snapshot: Image) {
        history[currentHistoryIndex].snapshot = snapshot
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

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    init(id: UUID, url: URL) {
        self.creationTime = Date()
        self.url = url
        self.title = url.absoluteString
        self.history = [HistoryItem(url: url, snapshot: nil)]
        self.currentHistoryIndex = 0
        self.id = id
    }
}
