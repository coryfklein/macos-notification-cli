import Foundation
import NotifCore

// Minimal test runner (no Xcode/XCTest required)

final class TestRunner {
    var passed = 0
    var failed = 0

    func check(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
        if condition {
            passed += 1
        } else {
            failed += 1
            print("  \u{001B}[31mFAIL\u{001B}[0m \(message) (\(file):\(line))")
        }
    }

    func checkEqual<T: Equatable>(_ a: T, _ b: T, _ message: String, file: String = #file, line: Int = #line) {
        if a == b {
            passed += 1
        } else {
            failed += 1
            print("  \u{001B}[31mFAIL\u{001B}[0m \(message): expected \(b), got \(a) (\(file):\(line))")
        }
    }

    func checkNil<T>(_ value: T?, _ message: String, file: String = #file, line: Int = #line) {
        if value == nil {
            passed += 1
        } else {
            failed += 1
            print("  \u{001B}[31mFAIL\u{001B}[0m \(message): expected nil, got \(value!) (\(file):\(line))")
        }
    }

    func suite(_ name: String, _ body: () -> Void) {
        print("\u{001B}[1m\(name)\u{001B}[0m")
        body()
    }

    func run() {
        suite("Action Name Parsing") {
            checkEqual(NotifParsing.parseActionName("AXPress"), "AXPress",
                        "Plain action names pass through")
            checkEqual(NotifParsing.parseActionName("AXCancel"), "AXCancel",
                        "Plain AXCancel passes through")
            checkEqual(NotifParsing.parseActionName("AXShowMenu"), "AXShowMenu",
                        "Plain AXShowMenu passes through")

            checkEqual(NotifParsing.parseActionName("Name:Close\nTarget:0x0\nSelector:(null)"), "Close",
                        "Extracts Close from metadata")
            checkEqual(NotifParsing.parseActionName("Name:Show Details\nTarget:0x0\nSelector:(null)"), "Show Details",
                        "Extracts Show Details from metadata")
            checkEqual(NotifParsing.parseActionName("Name:Clear All\nTarget:0x0\nSelector:(null)"), "Clear All",
                        "Extracts Clear All from metadata")

            checkEqual(NotifParsing.parseActionName("Name:Close"), "Close",
                        "Name: prefix without metadata")
            checkEqual(NotifParsing.parseActionName("Name:Show"), "Show",
                        "Name: prefix without metadata (Show)")

            checkEqual(NotifParsing.parseActionName(""), "",
                        "Empty string")
            checkEqual(NotifParsing.parseActionName("Name:"), "",
                        "Name: with nothing after")
            checkEqual(NotifParsing.parseActionName("Name:\nTarget:0x0"), "",
                        "Name: with immediate newline")
        }

        suite("App Name Extraction from Description") {
            checkEqual(
                NotifParsing.extractAppNameFromDescription("iTerm2, Alert, Session content here"),
                "iTerm2",
                "Extracts iTerm2"
            )
            checkEqual(
                NotifParsing.extractAppNameFromDescription("NotifiCLI, Dump Test, Check AX tree now, stacked"),
                "NotifiCLI",
                "Extracts NotifiCLI from stacked"
            )
            checkEqual(
                NotifParsing.extractAppNameFromDescription("terminal-notifier, Test Title, Test message"),
                "terminal-notifier",
                "Extracts terminal-notifier"
            )
            checkEqual(
                NotifParsing.extractAppNameFromDescription("Safari"),
                "Safari",
                "No commas returns whole string"
            )
            checkNil(
                NotifParsing.extractAppNameFromDescription(""),
                "Empty description returns nil"
            )
            checkEqual(
                NotifParsing.extractAppNameFromDescription("  Mail , subject"),
                "Mail",
                "Trims whitespace"
            )
        }

        suite("Stacked Description Detection") {
            check(
                NotifParsing.isStackedDescription("NotifiCLI, Title, Body, stacked"),
                "Detects stacked suffix"
            )
            check(
                NotifParsing.isStackedDescription("iTerm2, Alert, Session content, stacked"),
                "Detects stacked suffix (iTerm2)"
            )
            check(
                !NotifParsing.isStackedDescription("NotifiCLI, Title, Body"),
                "Non-stacked returns false"
            )
            check(
                !NotifParsing.isStackedDescription(""),
                "Empty returns false"
            )
        }

        // Summary
        print("")
        let total = passed + failed
        print("\u{001B}[1mResults:\u{001B}[0m \(total) tests, \u{001B}[32m\(passed) passed\u{001B}[0m", terminator: "")
        if failed > 0 {
            print(", \u{001B}[31m\(failed) failed\u{001B}[0m")
            exit(1)
        } else {
            print("")
        }
    }
}

TestRunner().run()
