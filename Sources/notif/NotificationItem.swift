import ApplicationServices
import Foundation

// MARK: - Domain models

/// Represents an item in the notification center: either a single notification or a group.
enum NotificationEntry: @unchecked Sendable {
    case notification(NotificationInfo)
    case group(NotificationGroupInfo)

    var index: String {
        switch self {
        case .notification(let n): return n.index
        case .group(let g): return g.index
        }
    }
}

/// A single notification.
struct NotificationInfo: @unchecked Sendable {
    let index: String
    let appName: String?
    let title: String?
    let body: String?
    let actions: [String]
    let axElement: AXUIElement
}

/// A group of notifications from the same app.
struct NotificationGroupInfo: @unchecked Sendable {
    let index: String
    let appName: String?
    let isExpanded: Bool
    let actions: [String]
    let notifications: [NotificationInfo]
    /// For collapsed groups: the stack element. For expanded: the collapse button.
    let axElement: AXUIElement
    /// The "Show Less" button (only present when expanded).
    let collapseButton: AXUIElement?
    /// The "Clear" / "Clear All" button.
    let clearButton: AXUIElement?

    init(
        index: String,
        appName: String?,
        isExpanded: Bool,
        actions: [String],
        notifications: [NotificationInfo],
        axElement: AXUIElement,
        collapseButton: AXUIElement? = nil,
        clearButton: AXUIElement? = nil
    ) {
        self.index = index
        self.appName = appName
        self.isExpanded = isExpanded
        self.actions = actions
        self.notifications = notifications
        self.axElement = axElement
        self.collapseButton = collapseButton
        self.clearButton = clearButton
    }
}
