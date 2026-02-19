#!/bin/bash
#
# Integration tests for notif CLI.
# Exercises all commands against the real macOS Notification Center.
#
# Prerequisites:
#   - Accessibility permission granted to your terminal app
#   - notificli installed (brew install notificli) with notifications enabled
#   - terminal-notifier installed (brew install terminal-notifier)
#
# WARNING: This script will dismiss all existing notifications before running.

set -uo pipefail
# Note: NOT using set -e; we handle errors ourselves since some notif commands
# may fail as part of the test flow.

cd "$(dirname "$0")"

NOTIF="swift run -q notif"
PASS=0
FAIL=0
TOTAL=0

# Delay after notification actions to let the AX tree settle
SETTLE=2

red()   { printf "\033[31m%s\033[0m" "$1"; }
green() { printf "\033[32m%s\033[0m" "$1"; }
bold()  { printf "\033[1m%s\033[0m" "$1"; }

# Run a notif command, suppressing all output. Returns the exit code.
run_notif() {
    $NOTIF "$@" >/dev/null 2>&1
    return $?
}

assert_output_contains() {
    local description="$1"
    local expected="$2"
    local actual="$3"
    TOTAL=$((TOTAL + 1))

    if echo "$actual" | grep -qF "$expected"; then
        echo "  $(green "PASS") $description"
        PASS=$((PASS + 1))
    else
        echo "  $(red "FAIL") $description"
        echo "    expected to contain: $expected"
        echo "    actual output:"
        echo "$actual" | sed 's/^/      /'
        FAIL=$((FAIL + 1))
    fi
}

assert_output_not_contains() {
    local description="$1"
    local unexpected="$2"
    local actual="$3"
    TOTAL=$((TOTAL + 1))

    if echo "$actual" | grep -qF "$unexpected"; then
        echo "  $(red "FAIL") $description"
        echo "    should NOT contain: $unexpected"
        echo "    actual output:"
        echo "$actual" | sed 's/^/      /'
        FAIL=$((FAIL + 1))
    else
        echo "  $(green "PASS") $description"
        PASS=$((PASS + 1))
    fi
}

assert_output_matches() {
    local description="$1"
    local pattern="$2"
    local actual="$3"
    TOTAL=$((TOTAL + 1))

    if echo "$actual" | grep -qE "$pattern"; then
        echo "  $(green "PASS") $description"
        PASS=$((PASS + 1))
    else
        echo "  $(red "FAIL") $description"
        echo "    expected to match: $pattern"
        echo "    actual output:"
        echo "$actual" | sed 's/^/      /'
        FAIL=$((FAIL + 1))
    fi
}

assert_count_decreased() {
    local description="$1"
    local before="$2"
    local after="$3"
    TOTAL=$((TOTAL + 1))

    if [ "$after" -lt "$before" ]; then
        echo "  $(green "PASS") $description ($before -> $after)"
        PASS=$((PASS + 1))
    else
        echo "  $(red "FAIL") $description ($before -> $after)"
        FAIL=$((FAIL + 1))
    fi
}

assert_ge() {
    local description="$1"
    local actual="$2"
    local minimum="$3"
    TOTAL=$((TOTAL + 1))

    if [ "$actual" -ge "$minimum" ]; then
        echo "  $(green "PASS") $description ($actual >= $minimum)"
        PASS=$((PASS + 1))
    else
        echo "  $(red "FAIL") $description (expected >= $minimum, got $actual)"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
# Build
echo "$(bold "Building...")"
swift build -q 2>&1
echo ""

# ============================================================
echo "$(bold "=== Setup: Clear all notifications ===")"
run_notif test clear
sleep "$SETTLE"

output=$($NOTIF list 2>&1)
assert_output_contains "Empty after clear" "No notifications" "$output"
echo ""

# ============================================================
echo "$(bold "=== Test: Single notification ===")"
run_notif test single
sleep "$SETTLE"

output=$($NOTIF list 2>&1)
assert_output_contains "Single notification appears" "NotifiCLI" "$output"
assert_output_contains "Shows notification text" "Single test notification" "$output"
assert_output_not_contains "Not shown as group" "group, collapsed" "$output"

output=$($NOTIF list -v 2>&1)
assert_output_contains "Verbose shows actions" "actions:" "$output"
assert_output_contains "Has Close action" "Close" "$output"

run_notif test clear
sleep "$SETTLE"
echo ""

# ============================================================
echo "$(bold "=== Test: Notification group (collapsed) ===")"
run_notif test group
sleep "$SETTLE"

output=$($NOTIF list 2>&1)
assert_output_contains "Group appears" "NotifiCLI" "$output"
assert_output_contains "Shown as collapsed group" "group, collapsed" "$output"

output=$($NOTIF list -v 2>&1)
assert_output_contains "Has Clear All action" "Clear All" "$output"
echo ""

# ============================================================
echo "$(bold "=== Test: Expand group ===")"
run_notif expand 1
sleep "$SETTLE"

output=$($NOTIF list 2>&1)
assert_output_contains "Shown as expanded" "expanded" "$output"
assert_output_matches "Has sub-indices" "\[1\.[0-9]\]" "$output"
assert_output_contains "Shows notification 3" "Notification 3 of 3" "$output"
assert_output_contains "Shows notification 1" "Notification 1 of 3" "$output"
echo ""

# ============================================================
echo "$(bold "=== Test: Dismiss sub-notification ===")"
count_before=$(echo "$output" | grep -c '\[1\.[0-9]\]' || true)

run_notif dismiss 1.1
sleep "$SETTLE"

output=$($NOTIF list 2>&1)
count_after=$(echo "$output" | grep -c '\[1\.[0-9]\]' || true)
assert_count_decreased "Sub-notification count decreased" "$count_before" "$count_after"
echo ""

# ============================================================
echo "$(bold "=== Test: Collapse group ===")"
run_notif collapse 1
sleep "$SETTLE"

output=$($NOTIF list 2>&1)
assert_output_contains "Back to collapsed" "group, collapsed" "$output"
assert_output_not_contains "No sub-indices after collapse" "[1.1]" "$output"
echo ""

# ============================================================
echo "$(bold "=== Test: Click collapsed group (should expand) ===")"
run_notif click 1
sleep "$SETTLE"

output=$($NOTIF list 2>&1)
assert_output_contains "Group expanded after click" "expanded" "$output"

run_notif test clear
sleep "$SETTLE"
echo ""

# ============================================================
echo "$(bold "=== Test: Dismiss collapsed group ===")"
run_notif test group
sleep "$SETTLE"

run_notif dismiss 1
sleep "$SETTLE"

output=$($NOTIF list 2>&1)
assert_output_contains "Empty after dismissing group" "No notifications" "$output"
echo ""

# ============================================================
echo "$(bold "=== Test: Dismiss expanded group ===")"
run_notif test group
sleep "$SETTLE"

run_notif expand 1
sleep "$SETTLE"

run_notif dismiss 1
sleep "$SETTLE"

output=$($NOTIF list 2>&1)
assert_output_contains "Empty after dismissing expanded group" "No notifications" "$output"
echo ""

# ============================================================
echo "$(bold "=== Test: Multiple groups ===")"
run_notif test multi
sleep 5  # extra time for two tools to create notifications

output=$($NOTIF list 2>&1)
assert_output_contains "Has NotifiCLI group" "NotifiCLI" "$output"
assert_output_contains "Has terminal-notifier group" "terminal-notifier" "$output"

group_count=$(echo "$output" | grep -c "collapsed\|expanded" || true)
assert_ge "Multiple groups present" "$group_count" 2

run_notif test clear
sleep "$SETTLE"
echo ""

# ============================================================
echo "$(bold "=== Test: Dump command ===")"
run_notif test single
sleep "$SETTLE"

output=$($NOTIF dump 2>&1)
assert_output_contains "Dump shows AX tree" "AXApplication" "$output"
assert_output_contains "Dump shows NC window" "Notification Center" "$output"
assert_output_contains "Dump shows notification subrole" "AXNotificationCenterAlert" "$output"

run_notif test clear
sleep "$SETTLE"
echo ""

# ============================================================
echo "$(bold "=== Test: List with no notifications ===")"
output=$($NOTIF list 2>&1)
assert_output_contains "Shows no notifications message" "No notifications" "$output"
echo ""

# ============================================================
# Summary
echo "$(bold "=== Results ===")"
echo "  Total: $TOTAL"
echo "  $(green "Passed: $PASS")"
if [ "$FAIL" -gt 0 ]; then
    echo "  $(red "Failed: $FAIL")"
    exit 1
else
    echo "  Failed: 0"
    echo ""
    echo "$(green "All tests passed!")"
fi
