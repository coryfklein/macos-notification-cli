# notif

A macOS Notification Center CLI — list, click, dismiss, expand, and collapse notifications from the command line.

There are plenty of tools for *sending* notifications from a script ([terminal-notifier](https://github.com/julienXX/terminal-notifier), `osascript`, etc.), but almost nothing for the other direction: reading, dismissing, or interacting with notifications that are already on screen. `notif` fills that gap. It lets you manage macOS notifications programmatically — automate notification workflows, dismiss notifications in bulk from a script, or click a pending notification without touching the mouse.

## Features

- **List pending notifications** in your terminal, including collapsed and expanded groups
- **Click/activate notifications** from the command line, with automatic group expansion
- **Dismiss notifications** individually, by group, or all at once
- **Expand and collapse** notification groups programmatically
- **Dump the raw Accessibility tree** for debugging and reverse-engineering Notification Center
- **Create test scenarios** to exercise specific notification states
- Works with any app's notifications — Slack, Mail, iMessage, whatever is in Notification Center

## Requirements

- macOS 13+ (Ventura or later; tested on macOS Tahoe)
- Accessibility permission granted to your terminal app

## Installation

### Homebrew

```bash
brew install coryfklein/tap/notif
```

### From source

Requires Swift 6.0+ (included with Xcode Command Line Tools).

```bash
git clone https://github.com/coryfklein/macos-notification-cli.git
cd macos-notification-cli
swift build -c release
cp .build/release/notif /usr/local/bin/
```

### Setup

On first run, grant Accessibility permission to your terminal app in **System Settings > Privacy & Security > Accessibility**.

## Usage

```
notif list [-v]           List all notifications and groups
notif click <index>       Click/activate a notification
notif dismiss <index>     Dismiss a notification or group
notif expand <index>      Expand a collapsed notification group
notif collapse <index>    Collapse an expanded notification group
notif dump [--max-depth]  Dump raw AX accessibility tree (for debugging)
notif test <scenario>     Create test notification scenarios
```

### Listing notifications

```
$ notif list
[1] Slack (group, collapsed)
[2] Mail: Meeting tomorrow — Don't forget to prepare the slides
```

With `-v` for verbose output (shows available actions):

```
$ notif list -v
[1] Slack (group, collapsed)
     actions: AXPress, Show Details, Clear All
[2] Mail: Meeting tomorrow — Don't forget to prepare the slides
     actions: AXPress, Show Details, Close
```

### Index scheme

Notifications and groups are numbered top-to-bottom starting at 1. When a group is expanded, individual notifications get sub-indices:

```
$ notif expand 1
$ notif list
[1] Slack (3 notifications, expanded)
  [1.1] Slack: #general — Anyone up for lunch?
  [1.2] Slack: #engineering — Deploy complete
  [1.3] Slack: DM — Hey, got a minute?
[2] Mail: Meeting tomorrow — Don't forget to prepare the slides
```

### Clicking grouped notifications

When you click a collapsed group, `notif` automatically expands it and clicks the first notification inside:

```
$ notif click 1
Clicked notification: Slack — #general — Anyone up for lunch?
```

### Test scenarios

Create notifications for testing (requires [notificli](https://github.com/saihgupr/NotifiCLI) and optionally [terminal-notifier](https://github.com/julienXX/terminal-notifier)):

```
notif test single    # One notification
notif test group     # One collapsed group (3 notifications)
notif test multi     # Multiple groups from different apps
notif test expanded  # One expanded group
notif test clear     # Dismiss all notifications
```

## Alfred workflow

An [Alfred](https://www.alfredapp.com/) workflow is included with three keywords:

| Keyword | Action |
|---------|--------|
| `cn` | Click the topmost notification (expands groups automatically) |
| `dismiss` | Dismiss all notifications |
| `notifications` | List all current notifications (shown in Large Type) |

### Installing the workflow

1. Install `notif`: `brew install coryfklein/tap/notif`
2. Download [`Notif.alfredworkflow`](https://github.com/coryfklein/macos-notification-cli/raw/main/Notif.alfredworkflow) and double-click to import into Alfred
3. Grant Accessibility permission to **Alfred** in System Settings > Privacy & Security > Accessibility

## How it works

`notif` uses the macOS Accessibility API (`AXUIElement` from the ApplicationServices framework) to read and interact with the Notification Center process. It navigates the accessibility tree to find notifications, determine their state (individual, collapsed group, expanded group), and perform actions like clicking or dismissing. Written in Swift with [swift-argument-parser](https://github.com/apple/swift-argument-parser).

The macOS Notification Center accessibility hierarchy is complex and underdocumented — it changes between OS versions, uses different structures for single notifications vs. groups, and flattens expanded groups into sibling elements rather than nesting them. The `dump` command is useful for debugging this:

```
$ notif dump --max-depth 5
AXApplication title="Notification Center"
  AXWindow title="Notification Center" subrole="AXSystemDialog"
    AXGroup subrole="AXHostingView"
      AXGroup
        AXScrollArea
          AXGroup
            AXGroup desc="Slack, #general, Anyone up for lunch?, stacked" subrole="AXNotificationCenterAlertStack"
```

## License

MIT
