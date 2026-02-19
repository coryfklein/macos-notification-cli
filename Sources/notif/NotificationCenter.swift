import ApplicationServices
import Foundation
import NotifCore

// MARK: - NotificationCenter reader

/// Reads and interprets the macOS Notification Center state via the Accessibility API.
///
/// macOS Tahoe notification container children can be:
///
/// **Collapsed group:**
///   AXGroup subrole="AXNotificationCenterAlertStack" (actions: AXPress, Show Details, Clear All)
///
/// **Expanded group** (flat sequence, not nested):
///   AXHeading desc="AppName"
///   AXButton desc="Confirm Show Less"
///   AXButton desc="Clear"
///   AXGroup subrole="AXNotificationCenterAlert" (first notification)
///   AXGroup subrole="AXNotificationCenterAlert" (second notification)
///   ... more alerts until next heading or stack ...
///
/// **Standalone notification:**
///   AXGroup subrole="AXNotificationCenterAlert" (not preceded by an AXHeading)
enum NotificationCenterReader {

    /// Get all top-level entries (notifications and groups) from Notification Center.
    static func listEntries() throws -> [NotificationEntry] {
        guard let entryNodes = try AXHelpers.notificationEntryNodes() else {
            return []
        }

        let children = entryNodes
        var entries: [NotificationEntry] = []
        var entryIndex = 1
        var i = 0

        while i < children.count {
            let node = children[i]

            if node.subrole == "AXNotificationCenterAlertStack" {
                // Collapsed group
                let appName = extractAppNameFromDescription(node) ?? extractAppName(from: node)
                let group = NotificationGroupInfo(
                    index: "\(entryIndex)",
                    appName: appName,
                    isExpanded: false,
                    actions: node.actions,
                    notifications: [],
                    axElement: node.element
                )
                entries.append(.group(group))
                entryIndex += 1
                i += 1

            } else if node.role == "AXHeading" {
                // Start of an expanded group. Collect the heading, buttons, and alerts.
                let headingDesc = node.nodeDescription ?? ""
                let appName = headingDesc.isEmpty ? nil : headingDesc

                // Find the collapse and clear buttons
                var collapseButton: AXUIElement? = nil
                var clearButton: AXUIElement? = nil
                var notifications: [NotificationInfo] = []
                var subIndex = 1
                i += 1

                while i < children.count {
                    let child = children[i]
                    if child.role == "AXButton" {
                        if let desc = child.nodeDescription {
                            if desc.contains("Show Less") {
                                collapseButton = child.element
                            } else if desc == "Clear" {
                                clearButton = child.element
                            }
                        }
                        i += 1
                    } else if child.subrole == "AXNotificationCenterAlert" {
                        let notif = buildNotification(child, index: "\(entryIndex).\(subIndex)")
                        notifications.append(notif)
                        subIndex += 1
                        i += 1
                    } else {
                        // Hit something else (next heading, stack, etc.) — stop
                        break
                    }
                }

                // Use the collapse button element as the group's axElement for collapse action.
                // Fall back to clear button or first notification.
                let groupElement = collapseButton ?? clearButton ?? notifications.first?.axElement

                if let element = groupElement {
                    var actions = ["AXPress"]  // collapse via the button
                    if clearButton != nil { actions.append("Clear") }
                    let group = NotificationGroupInfo(
                        index: "\(entryIndex)",
                        appName: appName,
                        isExpanded: true,
                        actions: actions,
                        notifications: notifications,
                        axElement: element,
                        collapseButton: collapseButton,
                        clearButton: clearButton
                    )
                    entries.append(.group(group))
                    entryIndex += 1
                }

            } else if node.subrole == "AXNotificationCenterAlert" {
                // Standalone notification (not part of an expanded group)
                let notif = buildNotification(node, index: "\(entryIndex)")
                entries.append(.notification(notif))
                entryIndex += 1
                i += 1

            } else {
                // Skip unknown elements (empty groups, etc.)
                i += 1
            }
        }

        return entries
    }

    /// Find an entry by its index string (e.g., "1" or "2.1").
    static func findEntry(index: String) throws -> (entry: NotificationEntry, axElement: AXUIElement) {
        let entries = try listEntries()

        let parts = index.split(separator: ".").map(String.init)

        guard let topIdx = Int(parts[0]), topIdx >= 1, topIdx <= entries.count else {
            throw AXHelperError.elementNotFound("No entry at index \(index)")
        }

        let entry = entries[topIdx - 1]

        if parts.count == 1 {
            switch entry {
            case .notification(let n):
                return (entry, n.axElement)
            case .group(let g):
                return (entry, g.axElement)
            }
        }

        // Sub-index: must be a group
        guard case .group(let group) = entry else {
            throw AXHelperError.elementNotFound("Entry \(parts[0]) is not a group, cannot use sub-index")
        }

        guard let subIdx = Int(parts[1]), subIdx >= 1, subIdx <= group.notifications.count else {
            throw AXHelperError.elementNotFound(
                "No notification at index \(index) (group has \(group.notifications.count) notifications)"
            )
        }

        let notif = group.notifications[subIdx - 1]
        return (.notification(notif), notif.axElement)
    }

    // MARK: - Builders

    private static func buildNotification(_ node: AXNode, index: String) -> NotificationInfo {
        let textContent = extractTextContent(from: node)
        let appName = extractAppNameFromDescription(node) ?? textContent.appName

        return NotificationInfo(
            index: index,
            appName: appName,
            title: textContent.title,
            body: textContent.body,
            actions: node.actions,
            axElement: node.element
        )
    }

    // MARK: - Text extraction

    private static func extractAppNameFromDescription(_ node: AXNode) -> String? {
        guard let desc = node.nodeDescription else { return nil }
        return NotifParsing.extractAppNameFromDescription(desc)
    }

    private static func extractTextContent(from node: AXNode) -> (appName: String?, title: String?, body: String?) {
        var texts: [String] = []
        collectStaticTexts(node, into: &texts, maxDepth: 5)

        let appName = texts.count > 0 ? texts[0] : nil
        let title = texts.count > 1 ? texts[1] : nil
        let body = texts.count > 2 ? texts[2] : nil
        return (appName, title, body)
    }

    private static func extractAppName(from node: AXNode) -> String? {
        var texts: [String] = []
        collectStaticTexts(node, into: &texts, maxDepth: 3)
        return texts.first
    }

    private static func collectStaticTexts(_ node: AXNode, into texts: inout [String], maxDepth: Int, depth: Int = 0) {
        if depth > maxDepth { return }

        if node.role == "AXStaticText" {
            if let v = node.value, !v.isEmpty {
                texts.append(v)
            }
        }

        for child in node.children {
            collectStaticTexts(child, into: &texts, maxDepth: maxDepth, depth: depth + 1)
        }
    }
}
