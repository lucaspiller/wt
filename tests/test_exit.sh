#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

WT_BIN="$PROJECT_ROOT/bin/wt"

echo "=== wt exit ==="

# --- outputs repo root from main repo ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

stdout="$("$WT_BIN" exit 2>/dev/null)"
assert_eq "outputs repo root" "$REPO_DIR" "$stdout"

cleanup_test_repo "$REPO_DIR"

# --- outputs repo root from inside worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

"$WT_BIN" inside-wt >/dev/null 2>&1
cd "$REPO_DIR/.worktrees/inside-wt"

stdout="$("$WT_BIN" exit 2>/dev/null)"
assert_eq "outputs repo root from worktree" "$REPO_DIR" "$stdout"

cleanup_test_repo "$REPO_DIR"

test_summary
