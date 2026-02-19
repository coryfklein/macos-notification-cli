import ArgumentParser
import ApplicationServices
import Foundation

struct ClickCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "click",
        abstract: "Click/activate a notification"
    )

    @Argument(help: "Index of the notification to click (e.g., 1, 2.1)")
    var index: String

    func run() throws {
        guard AXHelpers.checkAccessibility() else {
            throw AXHelperError.noAccessibilityPermission
        }

        let (entry, element) = try NotificationCenterReader.findEntry(index: index)

        switch entry {
        case .notification(let n):
            let node = AXNode(element: element)
            try node.performAction("AXPress")
            print("Clicked notification: \(n.appName ?? "unknown") — \(n.title ?? "")")

        case .group(let g):
            if g.isExpanded {
                // Expanded group: click the first notification in it
                guard let first = g.notifications.first else {
                    throw AXHelperError.elementNotFound("Expanded group has no notifications")
                }
                let node = AXNode(element: first.axElement)
                try node.performAction("AXPress")
                print("Clicked notification: \(first.appName ?? "unknown") — \(first.title ?? "")")
            } else {
                // Collapsed group: expand, wait for AX tree to settle, then click first notification
                let node = AXNode(element: element)
                try node.performAction("AXPress")
                Thread.sleep(forTimeInterval: 0.5)

                // Re-read entries to find the now-expanded group
                let entries = try NotificationCenterReader.listEntries()
                for e in entries {
                    if case .group(let expanded) = e, expanded.isExpanded,
                       expanded.appName == g.appName,
                       let first = expanded.notifications.first {
                        let firstNode = AXNode(element: first.axElement)
                        try firstNode.performAction("AXPress")
                        print("Clicked notification: \(first.appName ?? "unknown") — \(first.title ?? "")")
                        return
                    }
                }
                // Fallback: couldn't find expanded group (maybe only had one notification)
                print("Expanded group but could not find notification to click")
            }
        }
    }
}
