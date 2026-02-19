import AppKit
import ApplicationServices
import NotifCore

// MARK: - AXError convenience

enum AXHelperError: Error, CustomStringConvertible {
    case notificationCenterNotRunning
    case noAccessibilityPermission
    case windowNotFound
    case elementNotFound(String)
    case actionFailed(String)
    case attributeError(String)

    var description: String {
        switch self {
        case .notificationCenterNotRunning:
            return "NotificationCenter process is not running"
        case .noAccessibilityPermission:
            return """
                Accessibility permission not granted.
                Go to System Settings > Privacy & Security > Accessibility
                and enable your terminal app (Terminal.app, iTerm2, etc.).
                """
        case .windowNotFound:
            return "Notification Center window not found"
        case .elementNotFound(let msg):
            return "Element not found: \(msg)"
        case .actionFailed(let msg):
            return "Action failed: \(msg)"
        case .attributeError(let msg):
            return "Attribute error: \(msg)"
        }
    }
}

// MARK: - AXNode

/// A lightweight wrapper around an AXUIElement with cached attributes.
struct AXNode: @unchecked Sendable {
    let element: AXUIElement
    let role: String?
    let title: String?
    let nodeDescription: String?
    let subrole: String?

    init(element: AXUIElement) {
        self.element = element
        self.role = AXHelpers.attribute(element, kAXRoleAttribute)
        self.title = AXHelpers.attribute(element, kAXTitleAttribute)
        self.nodeDescription = AXHelpers.attribute(element, kAXDescriptionAttribute)
        self.subrole = AXHelpers.attribute(element, kAXSubroleAttribute)
    }

    var children: [AXNode] {
        AXHelpers.children(of: element)
    }

    /// Raw action names as returned by the AX API.
    var rawActions: [String] {
        AXHelpers.actions(of: element)
    }

    /// Cleaned action names with metadata stripped.
    var actions: [String] {
        AXHelpers.cleanActions(of: element)
    }

    var value: String? {
        AXHelpers.attribute(element, kAXValueAttribute)
    }

    /// Perform an action by its clean name. Matches against both raw and parsed names.
    func performAction(_ action: String) throws {
        // First try exact match against raw action names
        let rawNames = AXHelpers.actions(of: element)
        if rawNames.contains(action) {
            let result = AXUIElementPerformAction(element, action as CFString)
            guard result == .success else {
                throw AXHelperError.actionFailed("\(action) returned \(result.rawValue)")
            }
            return
        }

        // Try matching by parsed name
        for raw in rawNames {
            if AXHelpers.parseActionName(raw) == action {
                let result = AXUIElementPerformAction(element, raw as CFString)
                guard result == .success else {
                    throw AXHelperError.actionFailed("\(action) returned \(result.rawValue)")
                }
                return
            }
        }

        throw AXHelperError.actionFailed(
            "No action matching '\(action)'. Available: \(actions.joined(separator: ", "))"
        )
    }
}

// MARK: - AXHelpers

enum AXHelpers {
    /// Check if we have accessibility permission.
    static func checkAccessibility() -> Bool {
        // Use the string literal directly to avoid Swift 6 concurrency issues
        // with the kAXTrustedCheckOptionPrompt global.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Get an attribute value from an AXUIElement.
    static func attribute<T>(_ element: AXUIElement, _ attr: String) -> T? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
        guard result == .success, let value = value else { return nil }
        return value as? T
    }

    /// Get children of an AXUIElement as AXNodes.
    static func children(of element: AXUIElement) -> [AXNode] {
        guard let kids: CFArray = attribute(element, kAXChildrenAttribute) else {
            return []
        }
        let arr = kids as [AnyObject]
        return arr.compactMap { obj in
            // AXUIElement is a CFTypeRef, need to cast carefully
            let elem = obj as! AXUIElement
            return AXNode(element: elem)
        }
    }

    /// Get action names for an AXUIElement.
    static func actions(of element: AXUIElement) -> [String] {
        var names: CFArray?
        let result = AXUIElementCopyActionNames(element, &names)
        guard result == .success, let names = names else { return [] }
        return names as! [String]
    }

    /// Find the PID of the NotificationCenter process.
    static func findNotificationCenterPID() -> pid_t? {
        let apps = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.notificationcenterui"
        )
        return apps.first?.processIdentifier
    }

    /// Get the AXUIElement for the NotificationCenter application.
    static func notificationCenterApp() throws -> AXUIElement {
        guard let pid = findNotificationCenterPID() else {
            throw AXHelperError.notificationCenterNotRunning
        }
        return AXUIElementCreateApplication(pid)
    }

    /// Get the children that represent notification entries.
    /// macOS Tahoe has two layouts:
    ///   Single notification:   ScrollArea > AXGroup (the notification itself)
    ///   Multiple notifications: ScrollArea > AXGroup (container) > AXGroup children
    /// Returns the scroll area node — the caller should use `notificationEntryNodes()`
    /// to get the actual entries.
    /// Returns nil when Notification Center window doesn't exist (no notifications).
    static func notificationEntryNodes() throws -> [AXNode]? {
        let app = try notificationCenterApp()
        let appNode = AXNode(element: app)

        guard let window = appNode.children.first(where: { $0.title == "Notification Center" }) else {
            return nil
        }

        // Navigate: AXGroup (AXHostingView) > AXGroup > AXScrollArea
        guard let hostingView = window.children.first(where: {
            $0.role == "AXGroup" && $0.subrole == "AXHostingView"
        }) else {
            throw AXHelperError.elementNotFound("hosting view group under window")
        }
        guard let innerGroup = hostingView.children.first(where: { $0.role == "AXGroup" }) else {
            throw AXHelperError.elementNotFound("inner group")
        }
        guard let scrollArea = innerGroup.children.first(where: { $0.role == "AXScrollArea" }) else {
            throw AXHelperError.elementNotFound("scroll area")
        }

        let scrollChildren = scrollArea.children.filter { $0.role == "AXGroup" }
        guard let firstChild = scrollChildren.first else {
            return []
        }

        // Determine layout: is the first child a notification/stack itself,
        // or a container that holds notifications?
        let isNotification = firstChild.subrole == "AXNotificationCenterAlert"
            || firstChild.subrole == "AXNotificationCenterAlertStack"

        if isNotification {
            // Single-notification layout: scroll area children ARE the entries
            return scrollChildren
        } else {
            // Multi-notification layout: first child is a container group
            return firstChild.children
        }
    }

    /// Parse an action name — delegates to shared NotifParsing.
    static func parseActionName(_ raw: String) -> String {
        NotifParsing.parseActionName(raw)
    }

    /// Get cleaned action names for an AXUIElement.
    static func cleanActions(of element: AXUIElement) -> [String] {
        return actions(of: element).map(parseActionName)
    }

    /// Recursively dump the AX tree as indented text.
    static func dumpTree(from element: AXUIElement, depth: Int = 0, maxDepth: Int = 15) -> String {
        let node = AXNode(element: element)
        let indent = String(repeating: "  ", count: depth)
        var line = indent

        // Role
        line += node.role ?? "???"

        // Title
        if let t = node.title, !t.isEmpty {
            line += " title=\"\(t)\""
        }

        // Description
        if let d = node.nodeDescription, !d.isEmpty {
            line += " desc=\"\(d)\""
        }

        // Subrole
        if let s = node.subrole, !s.isEmpty {
            line += " subrole=\"\(s)\""
        }

        // Value
        if let v = node.value, !v.isEmpty {
            // Truncate long values
            let truncated = v.count > 80 ? String(v.prefix(80)) + "..." : v
            line += " value=\"\(truncated)\""
        }

        // Actions
        let acts = node.actions
        if !acts.isEmpty {
            line += " actions=[\(acts.joined(separator: ", "))]"
        }

        var output = line + "\n"

        // Recurse into children
        if depth < maxDepth {
            for child in node.children {
                output += dumpTree(from: child.element, depth: depth + 1, maxDepth: maxDepth)
            }
        }

        return output
    }
}
