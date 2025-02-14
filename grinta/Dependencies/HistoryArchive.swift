import ComposableArchitecture

@DependencyClient
struct HistoryArchiveClient {
    var store: @Sendable (_ item: HistoryItem) async throws -> Void
    var retrieve: @Sendable () async throws -> [HistoryItem]
}

extension HistoryArchiveClient: DependencyKey {
    static let liveValue: Self = {
        let archive = HistoryArchive()

        return Self(store: { item in
            archive.store(item: item)
        }, retrieve: {
            archive.retrieve()
        })
    }()
}

private actor HistoryArchive {
    private var items: Set<HistoryItem> = []
    private let capacity = 100

    func store(item: HistoryItem) {
        items.insert(item)
        items = Set(items.prefix(capacity))
    }

    func retrieve() -> [HistoryItem] {
        Array(items)
    }
}
