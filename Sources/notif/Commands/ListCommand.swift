import ArgumentParser
import Foundation

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all notifications and groups"
    )

    @Flag(name: .shortAndLong, help: "Show detailed information including actions")
    var verbose = false

    func run() throws {
        guard AXHelpers.checkAccessibility() else {
            throw AXHelperError.noAccessibilityPermission
        }

        let entries = try NotificationCenterReader.listEntries()

        if entries.isEmpty {
            print("No notifications.")
            return
        }

        for entry in entries {
            switch entry {
            case .notification(let n):
                printNotification(n, indent: "")
            case .group(let g):
                printGroup(g)
            }
        }
    }

    private func printNotification(_ n: NotificationInfo, indent: String) {
        let app = n.appName ?? "Unknown"
        let title = n.title ?? ""
        let body = n.body ?? ""

        var line = "\(indent)[\(n.index)] \(app)"
        if !title.isEmpty { line += ": \(title)" }
        if !body.isEmpty { line += " — \(body)" }
        print(line)

        if verbose {
            print("\(indent)     actions: \(n.actions.joined(separator: ", "))")
        }
    }

    private func printGroup(_ g: NotificationGroupInfo) {
        let app = g.appName ?? "Unknown"
        let state = g.isExpanded ? "expanded" : "collapsed"

        if g.isExpanded {
            print("[\(g.index)] \(app) (\(g.notifications.count) notifications, \(state))")
            for n in g.notifications {
                printNotification(n, indent: "  ")
            }
        } else {
            print("[\(g.index)] \(app) (group, \(state))")
        }

        if verbose {
            print("     actions: \(g.actions.joined(separator: ", "))")
        }
    }
}
