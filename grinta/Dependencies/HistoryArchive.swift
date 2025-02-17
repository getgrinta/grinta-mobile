import ComposableArchitecture
import Foundation

@DependencyClient
struct HistoryArchiveClient {
    var store: @Sendable (_ item: HistoryItem) async throws -> Void
    var retrieve: @Sendable () async throws -> [HistoryItem]
}

extension HistoryArchiveClient: DependencyKey {
    static let liveValue: Self = {
        let archive = HistoryArchive()

        return Self(
            store: { item in
                try await withCheckedThrowingContinuation { continuation in
                    archive.store(item: item) { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                }
            },
            retrieve: {
                try await withCheckedThrowingContinuation { continuation in
                    archive.retrieve { result in
                        continuation.resume(with: result)
                    }
                }
            }
        )
    }()
}

private final class HistoryArchive: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.grinta.app.history-archive", qos: .userInitiated)
    private var items: Set<HistoryItem> = []
    private let capacity = 100
    private let storage: HistoryStorage

    init() {
        do {
            storage = try! HistoryStorage()
            items = try storage.load()
        } catch {
            items = []
        }
    }

    func store(item: HistoryItem, completion: @escaping @Sendable (Error?) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                completion(nil)
                return
            }

            items.insert(item)
            items = Set(items.prefix(capacity))

            // Use async save to avoid blocking
            storage.saveAsync(items) { error in
                completion(error)
            }
        }
    }

    func retrieve(completion: @escaping @Sendable (Result<[HistoryItem], Error>) -> Void) {
        queue.async { [weak self] in
            guard let self else {
                completion(.success([]))
                return
            }
            completion(.success(Array(items)))
        }
    }
}
