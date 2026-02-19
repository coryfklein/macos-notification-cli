import ArgumentParser
import ApplicationServices

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
        let node = AXNode(element: element)
        try node.performAction("AXPress")

        switch entry {
        case .notification(let n):
            print("Clicked notification: \(n.appName ?? "unknown") — \(n.title ?? "")")
        case .group(let g):
            print("Clicked group: \(g.appName ?? "unknown")")
        }
    }
}
