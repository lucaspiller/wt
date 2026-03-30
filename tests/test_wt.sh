#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

WT_BIN="$PROJECT_ROOT/bin/wt"

echo "=== bin/wt ==="

# --- no args shows usage ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

stderr="$("$WT_BIN" 2>&1 || true)"
assert_contains "usage message when no args" "$stderr" "usage"

cleanup_test_repo "$REPO_DIR"

# --- wt <name> creates and outputs path ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

stdout="$("$WT_BIN" dispatch-test 2>/dev/null)"
assert_eq "dispatches to cd" "$REPO_DIR/.worktrees/dispatch-test" "$stdout"
assert_dir_exists "worktree created via dispatch" "$REPO_DIR/.worktrees/dispatch-test"

cleanup_test_repo "$REPO_DIR"

# --- wt cd <name> also works ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

stdout="$("$WT_BIN" cd explicit-test 2>/dev/null)"
assert_eq "explicit cd subcommand" "$REPO_DIR/.worktrees/explicit-test" "$stdout"

cleanup_test_repo "$REPO_DIR"

# --- wt <name> --from <branch> ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

git checkout -b develop >/dev/null 2>&1
git commit --allow-empty -m "on develop" >/dev/null 2>&1
git checkout main >/dev/null 2>&1

stdout="$("$WT_BIN" from-test --from develop 2>/dev/null)"
assert_eq "from flag works via dispatch" "$REPO_DIR/.worktrees/from-test" "$stdout"

cleanup_test_repo "$REPO_DIR"

# --- not in a git repo ---

TMPDIR_NOGIT="$(mktemp -d)"
cd "$TMPDIR_NOGIT"

stderr="$("$WT_BIN" anything 2>&1 || true)"
assert_contains "error outside git repo" "$stderr" "not a git repository"

rm -rf "$TMPDIR_NOGIT"

test_summary
