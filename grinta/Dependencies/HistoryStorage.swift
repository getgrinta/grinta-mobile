import Foundation

enum StorageError: Error {
    case failedToCreateDirectory
}

final class HistoryStorage {
    private let fileManager = FileManager.default
    private let storageURL: URL
    private let queue: DispatchQueue

    init() throws {
        queue = DispatchQueue(label: "com.grinta.app.history-storage", qos: .userInitiated)

        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw StorageError.failedToCreateDirectory
        }

        let directory = appSupport
            .appendingPathComponent("com.grinta.app", isDirectory: true)
            .appendingPathComponent("History", isDirectory: true)

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        storageURL = directory.appendingPathComponent("history.json")
    }

    func load() throws -> Set<HistoryItem> {
        try queue.sync {
            let data = try Data(contentsOf: storageURL)
            return try JSONDecoder().decode(Set<HistoryItem>.self, from: data)
        }
    }

    func save(_ items: Set<HistoryItem>) throws {
        try queue.sync {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL, options: .atomic)
        }
    }

    // For background saving when atomic write is not needed
    func saveAsync(_ items: Set<HistoryItem>, completion: @escaping @Sendable (Error?) -> Void) {
        queue.async { [storageURL] in
            do {
                let data = try JSONEncoder().encode(items)
                try data.write(to: storageURL)
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }
}
