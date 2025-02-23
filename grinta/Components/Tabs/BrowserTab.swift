import SwiftUI

struct BrowserTab: Identifiable, Hashable {
    struct HistoryItem: Equatable {
        let url: URL
    }

    var id: UUID
    let creationTime: Date
    var hasPreviousHistory: Bool
    var title: String
    var faviconURL: URL?
    var topBrandColor: Color?
    var bottomBrandColor: Color?
    var wasLoaded = false

    private(set) var history: [HistoryItem] = []
    private(set) var snapshotPerURL: [URL: Image] = [:]

    var url: URL

    var currentSnapshot: Image? {
        snapshotPerURL[url]
    }

    init(id: UUID, url: URL) {
        creationTime = Date()
        self.url = url
        title = url.absoluteString
        history = [HistoryItem(url: url)]
        self.id = id
        hasPreviousHistory = false
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    mutating func updateSnapshot(_ snapshot: Image, forURL url: URL) {
        snapshotPerURL[url] = snapshot
    }
}
