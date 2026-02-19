# macOS Notification CLI — Design Document

## Problem

macOS Notification Center has no command-line interface. The only way to interact with notifications programmatically is through the Accessibility API, which is underdocumented and has a complex, state-dependent UI hierarchy. Previous attempts using AppleScript hit a wall because:

1. **Hard to iterate**: Testing requires real notifications in specific states, and the feedback loop (make change → trigger notification → try tool → read output) is painfully slow.
2. **Complex UI states**: Notifications aren't a flat list — they form groups that collapse/expand, with UI elements that appear/disappear based on state.
3. **Incomplete understanding**: The AX API hierarchy for NotificationCenter was never fully mapped.

## Goals

Build a Swift CLI tool (`notif`) that:

1. **Lists** current notifications and groups with their state (collapsed/expanded, group vs individual).
2. **Acts** on notifications: click, dismiss, expand groups, dismiss groups.
3. **Creates test scenarios** by sending notifications that produce specific states (e.g., "2 groups, second one expanded").
4. **Dumps** the raw AX tree for debugging — making future development much easier.

## Non-Goals

- Replacing the macOS Notification Center UI.
- Filtering or searching notification content.
- Persistent notification history.

## CLI Interface

```
notif list                     # Show all notifications/groups with indices
notif click <index>            # Activate (click) a notification
notif dismiss <index>          # Dismiss a single notification
notif expand <index>           # Expand a collapsed notification group
notif collapse <index>         # Collapse an expanded notification group
notif dismiss-group <index>    # Dismiss an entire notification group
notif dump                     # Dump raw AX accessibility tree (debug)
notif test <scenario>          # Create a test notification scenario
```

### Index Scheme

Notifications and groups are numbered top-to-bottom starting at 1. The `list` command shows the current indices. When a group is expanded, its individual notifications get sub-indices (e.g., `2.1`, `2.2`).

### Test Scenarios

```
notif test single              # One notification
notif test group               # One collapsed group (3+ notifications from same app)
notif test multi               # Multiple groups from different apps
notif test expanded            # One expanded group
notif test clear               # Dismiss all notifications
```

To create notifications from "different apps", we use `osascript` to send notifications via different application bundles (e.g., `tell application "Terminal"`, `tell application "Script Editor"`). Notifications sent this way are attributed to the sending app, creating separate groups.

## Architecture

### Why Swift?

- **Native AX API access**: The `ApplicationServices` framework provides `AXUIElement` directly — no bridging or shelling out.
- **Swift Package Manager**: Clean dependency management and build system.
- **ArgumentParser**: Apple's own CLI framework for subcommand parsing.
- **Type safety**: The AX API is C-based and error-prone; Swift wrappers make it safer.

### Module Structure

```
Sources/notif/
├── main.swift                    # Entry point, top-level AsyncParsableCommand
├── AXHelpers.swift               # Low-level AXUIElement wrapper utilities
├── NotificationCenter.swift      # High-level notification center model
├── NotificationItem.swift        # Data model for notifications/groups
├── Commands/
│   ├── ListCommand.swift         # `notif list`
│   ├── ClickCommand.swift        # `notif click`
│   ├── DismissCommand.swift      # `notif dismiss`
│   ├── ExpandCommand.swift       # `notif expand` / `notif collapse`
│   ├── DismissGroupCommand.swift # `notif dismiss-group`
│   ├── DumpCommand.swift         # `notif dump`
│   └── TestCommand.swift         # `notif test`
└── TestScenarios.swift           # Notification creation for testing
```

### Core: AXHelpers

A thin Swift wrapper around the C-based AXUIElement API:

```swift
struct AXNode {
    let element: AXUIElement

    var role: String?
    var title: String?
    var description: String?
    var children: [AXNode]
    var actions: [String]

    func performAction(_ action: String) throws
    func attribute<T>(_ attr: String) -> T?
}
```

Key functions:
- `findNotificationCenterPID() -> pid_t` — locate the NotificationCenter process
- `getNotificationCenterRoot() -> AXNode` — get the root AX element
- `traverseTree(from:depth:) -> [AXNode]` — recursive tree walker

### Core: NotificationCenter

Interprets the AX tree into a domain model:

```swift
enum NotificationEntry {
    case notification(Notification)
    case group(NotificationGroup)
}

struct Notification {
    let index: String          // "1" or "2.1"
    let appName: String?
    let title: String?
    let body: String?
    let axElement: AXUIElement // For performing actions
    let actions: [String]
}

struct NotificationGroup {
    let index: String
    let appName: String?
    let count: Int?
    let isExpanded: Bool
    let axElement: AXUIElement
    let notifications: [Notification] // Non-empty only when expanded
    let actions: [String]
}
```

**Heuristics for identifying notification types** (from prior reverse-engineering):
- **Collapsed group**: Has actions including "Clear All" — typically exactly 3 actions (AXPress, Show Details, Clear All).
- **Individual notification**: Has more actions including app-specific ones (e.g., "Close", "Allow", "Reply").
- **Expanded group**: After expansion, the group's children become individual notification elements.

### Core: TestScenarios

Creates notifications by running `osascript` commands that tell different apps to `display notification`. This means:
- Notifications from `Terminal` → one group
- Notifications from `Script Editor` → another group
- Notifications from `Finder` → another group (if supported)

For creating specific states (like "expanded"), the tool will:
1. Send notifications to create the desired groups
2. Use the AX API to expand/collapse as needed

## macOS Notification Center AX Hierarchy

Based on reverse-engineering (macOS Sequoia / Tahoe):

```
Process: NotificationCenter
└── AXWindow "Notification Center"
    └── AXGroup
        └── AXGroup
            └── AXScrollArea
                └── AXGroup (container)
                    ├── AXGroup (top item — could be group or notification)
                    │   ├── actions: [AXPress, Name:Show Details, Name:Clear All]
                    │   │   → This is a COLLAPSED GROUP
                    │   └── OR actions: [AXPress, Name:Close, Name:Options, ...]
                    │       → This is an INDIVIDUAL NOTIFICATION
                    ├── AXGroup (next item)
                    └── ...
```

After expanding a group, the container re-arranges and the expanded group's notifications appear as separate AXGroup children.

## Implementation Plan

### Phase 1: Foundation
1. Set up Swift Package with ArgumentParser dependency
2. Implement `AXHelpers` — AXUIElement wrapper with tree traversal
3. Implement `notif dump` — raw tree output for debugging

### Phase 2: List & Model
4. Implement `NotificationCenter` model — parse AX tree into domain objects
5. Implement `notif list` — human-readable notification listing

### Phase 3: Actions
6. Implement `notif click`, `notif dismiss`, `notif expand`, `notif collapse`, `notif dismiss-group`

### Phase 4: Test Scenarios
7. Implement `notif test` with scenario presets

### Permissions

The tool requires **Accessibility permission** for whatever terminal app runs it (Terminal.app, iTerm2, etc.). On first run, if permission isn't granted, the tool should detect this and print instructions for enabling it in System Settings > Privacy & Security > Accessibility.

## Open Questions

- **macOS version differences**: The AX hierarchy may differ between Sequoia and Tahoe. The `dump` command will be essential for adapting.
- **Notification content access**: Static text children of notification groups may provide title/body, but this needs verification.
- **Timing**: Some actions (expand/collapse) need delays before re-querying the tree. We'll need to experiment with appropriate delays.
