import ArgumentParser
import ApplicationServices

struct ExpandCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "expand",
        abstract: "Expand a collapsed notification group"
    )

    @Argument(help: "Index of the group to expand")
    var index: String

    func run() throws {
        guard AXHelpers.checkAccessibility() else {
            throw AXHelperError.noAccessibilityPermission
        }

        let (entry, element) = try NotificationCenterReader.findEntry(index: index)

        guard case .group(let g) = entry else {
            throw AXHelperError.actionFailed("Entry at index \(index) is not a group")
        }

        if g.isExpanded {
            print("Group at index \(index) is already expanded")
            return
        }

        // For collapsed stacks, AXPress expands them
        let node = AXNode(element: element)
        try node.performAction("AXPress")
        print("Expanded group at index \(index)")
    }
}

struct CollapseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "collapse",
        abstract: "Collapse an expanded notification group"
    )

    @Argument(help: "Index of the group to collapse")
    var index: String

    func run() throws {
        guard AXHelpers.checkAccessibility() else {
            throw AXHelperError.noAccessibilityPermission
        }

        let (entry, _) = try NotificationCenterReader.findEntry(index: index)

        guard case .group(let g) = entry else {
            throw AXHelperError.actionFailed("Entry at index \(index) is not a group")
        }

        if !g.isExpanded {
            print("Group at index \(index) is already collapsed")
            return
        }

        // Use the "Show Less" button to collapse
        if let collapseBtn = g.collapseButton {
            let node = AXNode(element: collapseBtn)
            try node.performAction("AXPress")
            print("Collapsed group at index \(index)")
        } else {
            throw AXHelperError.actionFailed("No collapse button found for group at index \(index)")
        }
    }
}
