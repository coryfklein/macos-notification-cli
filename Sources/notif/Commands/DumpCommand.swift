import ArgumentParser
import ApplicationServices

struct DumpCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "dump",
        abstract: "Dump the raw accessibility tree of Notification Center"
    )

    @Option(name: .long, help: "Maximum depth to traverse (default: 15)")
    var maxDepth: Int = 15

    func run() throws {
        guard AXHelpers.checkAccessibility() else {
            throw AXHelperError.noAccessibilityPermission
        }

        let app = try AXHelpers.notificationCenterApp()
        let tree = AXHelpers.dumpTree(from: app, maxDepth: maxDepth)
        print(tree)
    }
}
