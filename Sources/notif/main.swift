import ArgumentParser

struct Notif: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "notif",
        abstract: "Interact with macOS Notification Center from the command line",
        version: "0.1.0",
        subcommands: [
            ListCommand.self,
            ClickCommand.self,
            DismissCommand.self,
            ExpandCommand.self,
            CollapseCommand.self,
            DumpCommand.self,
            TestCommand.self,
        ],
        defaultSubcommand: ListCommand.self
    )
}

Notif.main()
