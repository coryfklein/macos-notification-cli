# notif

A CLI tool for interacting with macOS Notification Center via the Accessibility API.

List, click, dismiss, expand, and collapse notifications and notification groups — all from the terminal.

## Requirements

- macOS 13+ (Ventura or later; tested on macOS Tahoe)
- Swift 6.0+
- Accessibility permission granted to your terminal app

## Installation

```bash
git clone https://github.com/coryfklein/macos-notification-cli.git
cd macos-notification-cli
swift build -c release
```

The binary will be at `.build/release/notif`. Optionally copy it to your PATH:

```bash
cp .build/release/notif /usr/local/bin/
```

On first run, you'll need to grant Accessibility permission to your terminal app in **System Settings > Privacy & Security > Accessibility**.

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

## How it works

`notif` uses the macOS Accessibility API (`AXUIElement` from ApplicationServices) to read and interact with the Notification Center process. It navigates the accessibility tree to find notifications, determine their state (individual, collapsed group, expanded group), and perform actions like clicking or dismissing.

The `dump` command is useful for debugging — it prints the entire AX tree so you can see exactly what macOS exposes:

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
