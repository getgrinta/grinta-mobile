import Dependencies
import Foundation
import IdentifiedCollections
import SwiftUI

struct TabPersistenceClient {
    var saveTabs: @Sendable ([BrowserTab]) async throws -> Void
    var loadTabs: @Sendable () async throws -> [BrowserTab]
    var saveSnapshot: @Sendable (BrowserTab.ID, Image) async throws -> Void
    var loadSnapshot: @Sendable (BrowserTab.ID) async throws -> Image?
    var loadTabsWithSnapshots: @Sendable () async throws -> [BrowserTab]
}

enum TabPersistenceClientError: Error {
    case couldNotSerializeImage
}

extension TabPersistenceClient: DependencyKey {
    static var liveValue: Self {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let snapshotsDirectory = documentsDirectory.appendingPathComponent("snapshots")
        let tabsURL = documentsDirectory.appendingPathComponent("tabs.json")

        let loadTabs: @Sendable () async throws -> [BrowserTab] = {
            guard FileManager.default.fileExists(atPath: tabsURL.path) else { return [] }
            let data = try Data(contentsOf: tabsURL)
            return try JSONDecoder().decode([BrowserTab].self, from: data)
        }

        let loadSnapshot: @Sendable (BrowserTab.ID) async throws -> Image? = { tabId in
            let snapshotURL = snapshotsDirectory.appendingPathComponent("\(tabId).jpg")
            guard FileManager.default.fileExists(atPath: snapshotURL.path),
                  let data = try? Data(contentsOf: snapshotURL),
                  let uiImage = UIImage(data: data)
            else { return nil }
            return Image(uiImage: uiImage)
        }

        let directoriesInitialized = LockIsolated(false)
        let initializeDirectories: @Sendable () throws -> Void = {
            try directoriesInitialized.withValue { isInitialized in
                guard isInitialized == false else { return }
                try FileManager.default.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)
                isInitialized = true
            }
        }

        return Self(
            saveTabs: { tabs in
                try initializeDirectories()
                let encodedTabData = try JSONEncoder().encode(tabs)
                try encodedTabData.write(to: tabsURL)
            },
            loadTabs: loadTabs,
            saveSnapshot: { tabId, image in
                try initializeDirectories()

                guard let data = await image.jpgData() else { throw TabPersistenceClientError.couldNotSerializeImage }
                let fileName = "\(tabId).jpg"
                let snapshotURL = snapshotsDirectory.appendingPathComponent(fileName)
                try data.write(to: snapshotURL)
            },
            loadSnapshot: loadSnapshot,
            loadTabsWithSnapshots: {
                let loadedTabs = try await loadTabs()
                var tabsWithSnapshots = IdentifiedArrayOf(uniqueElements: loadedTabs)

                try await withThrowingTaskGroup(of: (BrowserTab.ID, Image?).self) { group in
                    for tab in loadedTabs {
                        group.addTask {
                            let snapshot = try await loadSnapshot(tab.id)
                            return (tab.id, snapshot)
                        }
                    }

                    for try await (tabId, snapshot) in group {
                        if let snapshot, let url = tabsWithSnapshots[id: tabId]?.url {
                            tabsWithSnapshots[id: tabId]?.updateSnapshot(snapshot, forURL: url)
                        }
                    }
                }

                return tabsWithSnapshots.elements
            }
        )
    }

    static var testValue: Self {
        Self(
            saveTabs: { _ in },
            loadTabs: { [] },
            saveSnapshot: { _, _ in },
            loadSnapshot: { _ in nil },
            loadTabsWithSnapshots: { [] }
        )
    }
}

extension DependencyValues {
    var tabPersistence: TabPersistenceClient {
        get { self[TabPersistenceClient.self] }
        set { self[TabPersistenceClient.self] = newValue }
    }
}

private extension Image {
    @MainActor
    func jpgData() -> Data? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage?.jpegData(compressionQuality: 0.7)
    }
}
