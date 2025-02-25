import Foundation
import UIKit

/// Provides user agent strings for different browsing modes
enum UserAgentProvider {
    /// The default user agent string for mobile browsing
    static var defaultMobileUserAgent: String? {
        nil // Using nil will make WebKit use its default mobile user agent
    }

    /// The user agent string for desktop browsing
    static var desktopUserAgent: String {
        // Get device info
        let osVersion = UIDevice.current.systemVersion
        let webKitVersion = "605.1.15" // This is a common WebKit version for Safari

        // Get app info
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

        // Current date for Chrome version approximation
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yy.MM"
        let chromeVersion = dateFormatter.string(from: Date())

        // Modern desktop Chrome user agent with dynamic version numbers
        return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/\(webKitVersion) (KHTML, like Gecko) Chrome/\(chromeVersion).0.4324.96 Safari/\(webKitVersion) Grinta/\(appVersion) Build/\(buildNumber)"
    }

    /// Returns the appropriate user agent string based on the desktop site preference
    static func userAgent(forDesktopSite isDesktopSite: Bool) -> String? {
        isDesktopSite ? desktopUserAgent : defaultMobileUserAgent
    }
}
