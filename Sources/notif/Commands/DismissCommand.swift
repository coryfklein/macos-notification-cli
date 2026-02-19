import ArgumentParser
import ApplicationServices

struct DismissCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dismiss",
        abstract: "Dismiss a notification or group"
    )

    @Argument(help: "Index of the notification or group to dismiss (e.g., 1, 2.1)")
    var index: String

    func run() throws {
        guard AXHelpers.checkAccessibility() else {
            throw AXHelperError.noAccessibilityPermission
        }

        let (entry, element) = try NotificationCenterReader.findEntry(index: index)
        let node = AXNode(element: element)
        let actions = node.actions

        switch entry {
        case .notification:
            if let closeAction = actions.first(where: { $0.contains("Close") }) {
                try node.performAction(closeAction)
                print("Dismissed notification at index \(index)")
            } else {
                throw AXHelperError.actionFailed(
                    "No dismiss action found. Available: \(actions.joined(separator: ", "))"
                )
            }

        case .group(let g):
            if g.isExpanded {
                // Expanded group: use the clear button
                if let clearBtn = g.clearButton {
                    let clearNode = AXNode(element: clearBtn)
                    try clearNode.performAction("AXPress")
                    print("Dismissed group at index \(index)")
                } else {
                    throw AXHelperError.actionFailed("No clear button found for expanded group")
                }
            } else {
                // Collapsed stack: use "Clear All" action
                if let clearAction = actions.first(where: { $0.contains("Clear All") }) {
                    try node.performAction(clearAction)
                    print("Dismissed group at index \(index)")
                } else {
                    throw AXHelperError.actionFailed(
                        "No 'Clear All' action found. Available: \(actions.joined(separator: ", "))"
                    )
                }
            }
        }
    }
}
