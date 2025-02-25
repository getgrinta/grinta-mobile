import SwiftUI

struct BrowserTab: Identifiable, Hashable, Codable {
    let id: UUID
    var url: URL
    var title: String
    var metadata: WebsiteMetadata?
    var hasPreviousHistory = false
    var zoomLevel: Settings.ZoomLevel
    var wasLoaded = false
    var topBrandColor: Color = .clear
    var bottomBrandColor: Color = .clear
    let creationTime: Date
    var isIncognito = false
    var isDesktopSite = false

    private(set) var snapshotPerURL: [URL: Image] = [:]

    var currentSnapshot: Image? {
        snapshotPerURL[url]
    }

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case title
        case metadata
        case topBrandColor
        case bottomBrandColor
        case creationTime
        case zoomLevel
        case isDesktopSite
    }

    init(
        id: UUID = UUID(),
        url: URL,
        isIncognito: Bool = false,
        isDesktopSite: Bool = false,
        zoomLevel: Settings.ZoomLevel = .default
    ) {
        self.id = id
        self.url = url
        self.isIncognito = isIncognito
        self.isDesktopSite = isDesktopSite
        self.zoomLevel = zoomLevel
        creationTime = Date()
        title = url.absoluteString
    }

    mutating func updateSnapshot(_ snapshot: Image, forURL url: URL) {
        snapshotPerURL[url] = snapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        metadata = try container.decodeIfPresent(WebsiteMetadata.self, forKey: .metadata)
        hasPreviousHistory = false
        wasLoaded = false
        creationTime = try container.decode(Date.self, forKey: .creationTime)

        if let topColorComponents = try container.decodeIfPresent([CGFloat].self, forKey: .topBrandColor) {
            topBrandColor = Color(.sRGB, red: topColorComponents[0], green: topColorComponents[1], blue: topColorComponents[2], opacity: topColorComponents[3])
        }

        if let bottomColorComponents = try container.decodeIfPresent([CGFloat].self, forKey: .bottomBrandColor) {
            bottomBrandColor = Color(.sRGB, red: bottomColorComponents[0], green: bottomColorComponents[1], blue: bottomColorComponents[2], opacity: bottomColorComponents[3])
        }

        if let zoomLevelRaw = try container.decodeIfPresent(Int.self, forKey: .zoomLevel) {
            zoomLevel = Settings.ZoomLevel(rawValue: zoomLevelRaw) ?? .default
        } else {
            zoomLevel = .default
        }

        isDesktopSite = try container.decodeIfPresent(Bool.self, forKey: .isDesktopSite) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encode(creationTime, forKey: .creationTime)

        if let components = UIColor(topBrandColor).cgColor.components {
            try container.encode(components, forKey: .topBrandColor)
        }

        if let components = UIColor(bottomBrandColor).cgColor.components {
            try container.encode(components, forKey: .bottomBrandColor)
        }

        try container.encode(zoomLevel.rawValue, forKey: .zoomLevel)
        try container.encode(isDesktopSite, forKey: .isDesktopSite)
    }

    static func == (lhs: BrowserTab, rhs: BrowserTab) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
