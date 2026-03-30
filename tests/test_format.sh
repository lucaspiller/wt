#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"
source "$PROJECT_ROOT/lib/format.sh"

echo "=== lib/format.sh ==="

# --- color functions produce ANSI codes ---

result="$(fmt_green "hello")"
assert_contains "green wraps text" "$result" "hello"
assert_contains "green has escape code" "$result" "[32m"

result="$(fmt_red "error")"
assert_contains "red wraps text" "$result" "error"
assert_contains "red has escape code" "$result" "[31m"

result="$(fmt_yellow "warn")"
assert_contains "yellow wraps text" "$result" "warn"

result="$(fmt_dim "faded")"
assert_contains "dim wraps text" "$result" "faded"

result="$(fmt_bold "strong")"
assert_contains "bold wraps text" "$result" "strong"

# --- status icons ---

result="$(fmt_icon_pass)"
assert_contains "pass icon is green" "$result" "[32m"

result="$(fmt_icon_fail)"
assert_contains "fail icon is red" "$result" "[31m"

result="$(fmt_icon_pending)"
assert_contains "pending icon is yellow" "$result" "[33m"

# --- relative time ---

now="$(date +%s)"
one_hour_ago=$((now - 3600))
result="$(fmt_relative_time "$one_hour_ago")"
assert_contains "1 hour ago" "$result" "1h ago"

two_days_ago=$((now - 172800))
result="$(fmt_relative_time "$two_days_ago")"
assert_contains "2 days ago" "$result" "2d ago"

thirty_seconds_ago=$((now - 30))
result="$(fmt_relative_time "$thirty_seconds_ago")"
assert_contains "just now" "$result" "just now"

test_summary
