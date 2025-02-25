import Foundation

enum AppVersion {
    static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        #if DEBUG
            return "Grinta \(version) (\(build)) (DEBUG)"
        #else
            return "Grinta \(version) (\(build))"
        #endif
    }
}
