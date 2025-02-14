import ComposableArchitecture

@DependencyClient
struct WebsiteMetadataStoreClient {
    var store: @Sendable (_ item: WebsiteMetadata, _ hostname: String) async throws -> Void
    var retrieve: @Sendable (_ hostname: String) async throws -> WebsiteMetadata?
}

extension WebsiteMetadataStoreClient: DependencyKey {
    static let liveValue: Self = {
        let store = WebsiteMetadataStore()

        return Self(store: { item, hostname in
            store.store(item: item, for: hostname)
        }, retrieve: { hostname in
            store.retrieve(for: hostname)
        })
    }()
}

private actor WebsiteMetadataStore {
    private var items: [String: WebsiteMetadata] = [:]

    func store(item: WebsiteMetadata, for hostname: String) {
        print("Storing \(item) for \(hostname)")
        items[hostname] = item
    }

    func retrieve(for hostname: String) -> WebsiteMetadata? {
        items[hostname]
    }
}
