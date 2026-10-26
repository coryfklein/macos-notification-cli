import Foundation

/// Pure parsing functions extracted for testability.
public enum NotifParsing {

    /// Parse an AX action name that may contain metadata.
    /// Raw format: "Name:Show Details\nTarget:0x0\nSelector:(null)"
    /// Returns just the human-readable name.
    /// Plain action names like "AXPress" pass through unchanged.
    public static func parseActionName(_ raw: String) -> String {
        if raw.hasPrefix("Name:") {
            let afterPrefix = raw.dropFirst(5)
            if let newlineIdx = afterPrefix.firstIndex(of: "\n") {
                return String(afterPrefix[afterPrefix.startIndex..<newlineIdx])
            }
            return String(afterPrefix)
        }
        return raw
    }

    /// Extract the app name from a notification's AX description field.
    /// On Tahoe, descriptions look like:
    ///   "iTerm2, Alert, Session ... , stacked"
    ///   "NotifiCLI, Dump Test, Check AX tree now, stacked"
    ///   "terminal-notifier, Title, Message"
    /// Returns the first comma-separated segment, trimmed.
    public static func extractAppNameFromDescription(_ description: String) -> String? {
        guard !description.isEmpty else { return nil }
        let firstPart = description.split(separator: ",", maxSplits: 1).first.map(String.init)
        return firstPart?.trimmingCharacters(in: .whitespaces)
    }

    /// Determine if an AX description indicates a stacked (collapsed) group.
    /// Stacked notifications end with ", stacked".
    public static func isStackedDescription(_ description: String) -> Bool {
        description.hasSuffix(", stacked")
    }

    /// Determine if an AX subrole is a single notification.
    /// Tahoe uses "AXNotificationCenterAlert" for every notification; macOS 27
    /// reports on-screen banners as "AXNotificationCenterBanner".
    public static func isNotificationSubrole(_ subrole: String?) -> Bool {
        subrole == "AXNotificationCenterAlert" || subrole == "AXNotificationCenterBanner"
    }

    /// Split a notification's static texts into app name, title and body.
    /// Alerts list the app name first: [app, title, body].
    /// Banners omit it: [title, body] or [title, subtitle, body]; the extra
    /// segments are joined into the body.
    public static func splitStaticTexts(
        _ texts: [String], leadingAppName: Bool
    ) -> (appName: String?, title: String?, body: String?) {
        if leadingAppName {
            let appName = texts.count > 0 ? texts[0] : nil
            let title = texts.count > 1 ? texts[1] : nil
            let body = texts.count > 2 ? texts[2] : nil
            return (appName, title, body)
        }
        let rest = texts.dropFirst()
        return (nil, texts.first, rest.isEmpty ? nil : rest.joined(separator: " — "))
    }
}
