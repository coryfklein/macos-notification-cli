import ArgumentParser
import Foundation

struct TestCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "test",
        abstract: "Create test notification scenarios"
    )

    @Argument(help: "Scenario: single, group, multi, expanded, clear")
    var scenario: String

    func run() throws {
        switch scenario {
        case "single":
            try TestScenarios.createSingle()
        case "group":
            try TestScenarios.createGroup()
        case "multi":
            try TestScenarios.createMultipleGroups()
        case "expanded":
            try TestScenarios.createExpandedGroup()
        case "clear":
            try TestScenarios.clearAll()
        default:
            print("Unknown scenario: \(scenario)")
            print("Available scenarios: single, group, multi, expanded, clear")
            throw ExitCode.failure
        }
    }
}

enum TestScenarios {
    /// Send a notification using notificli (default) or terminal-notifier.
    private static func sendNotification(
        title: String,
        message: String,
        tool: NotificationTool = .notificli
    ) throws {
        let process = Process()
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = Pipe()

        switch tool {
        case .notificli:
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/notificli")
            process.arguments = ["-title", title, "-message", message]
        case .terminalNotifier(let group):
            process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/terminal-notifier")
            // Note: -sender causes terminal-notifier to block waiting for interaction.
            // Without it, notifications are attributed to "terminal-notifier" bundle.
            process.arguments = ["-title", title, "-message", message, "-group", group]
        }

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMsg = String(data: errorData, encoding: .utf8) ?? "unknown error"
            print("  Warning: \(tool) error: \(errorMsg.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    enum NotificationTool: CustomStringConvertible {
        case notificli
        case terminalNotifier(group: String)

        var description: String {
            switch self {
            case .notificli: return "notificli"
            case .terminalNotifier: return "terminal-notifier"
            }
        }
    }

    static func createSingle() throws {
        print("Creating single notification...")
        try sendNotification(title: "Test Notification", message: "Single test notification")
        print("Done. Use 'notif list' to see it.")
    }

    static func createGroup() throws {
        // Send 3 notifications from the same app to create a collapsed group.
        print("Creating notification group (3 notifications)...")
        for i in 1...3 {
            try sendNotification(title: "Group Test \(i)", message: "Notification \(i) of 3")
            Thread.sleep(forTimeInterval: 0.5)
        }
        print("Done. Use 'notif list' to see them.")
    }

    static func createMultipleGroups() throws {
        // Use different notification tools to create groups from different app bundle IDs.
        // notificli and terminal-notifier have different bundles, so they group separately.
        print("Creating 2 notification groups...")

        // Group 1: notificli
        for j in 1...3 {
            try sendNotification(
                title: "NotifiCLI Test \(j)",
                message: "Group 1, notification \(j)"
            )
            Thread.sleep(forTimeInterval: 0.3)
        }
        print("  Created group 1 (NotifiCLI)")

        // Group 2: terminal-notifier (each needs a unique group ID to avoid replacement)
        for j in 1...3 {
            try sendNotification(
                title: "Notifier Test \(j)",
                message: "Group 2, notification \(j)",
                tool: .terminalNotifier(group: "notif-test-multi-\(j)")
            )
            Thread.sleep(forTimeInterval: 0.3)
        }
        print("  Created group 2 (terminal-notifier)")

        print("Done. Use 'notif list' to see the groups.")
    }

    static func createExpandedGroup() throws {
        print("Creating notification group and expanding it...")
        try createGroup()

        Thread.sleep(forTimeInterval: 1.5)

        guard AXHelpers.checkAccessibility() else {
            throw AXHelperError.noAccessibilityPermission
        }

        let entries = try NotificationCenterReader.listEntries()
        for entry in entries {
            if case .group(let g) = entry, !g.isExpanded {
                let node = AXNode(element: g.axElement)
                try node.performAction("AXPress")
                print("Expanded group at index \(g.index)")
                return
            }
        }
        print("No collapsed group found to expand.")
    }

    static func clearAll() throws {
        guard AXHelpers.checkAccessibility() else {
            throw AXHelperError.noAccessibilityPermission
        }

        print("Clearing all notifications...")
        let entries = try NotificationCenterReader.listEntries()

        if entries.isEmpty {
            print("No notifications to clear.")
            return
        }

        // Dismiss in reverse order to avoid index shifting
        for entry in entries.reversed() {
            switch entry {
            case .notification(let n):
                let node = AXNode(element: n.axElement)
                if let closeAction = node.actions.first(where: { $0.contains("Close") }) {
                    try? node.performAction(closeAction)
                }
            case .group(let g):
                if g.isExpanded {
                    // Expanded group: use the clear button
                    if let clearBtn = g.clearButton {
                        try? AXNode(element: clearBtn).performAction("AXPress")
                    }
                } else {
                    // Collapsed stack: use "Clear All" action on the stack element
                    let node = AXNode(element: g.axElement)
                    if let clearAction = node.actions.first(where: { $0.contains("Clear All") }) {
                        try? node.performAction(clearAction)
                    }
                }
            }
            Thread.sleep(forTimeInterval: 0.3)
        }

        print("Done.")
    }
}
