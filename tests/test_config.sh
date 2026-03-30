#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"
source "$PROJECT_ROOT/lib/config.sh"

echo "=== lib/config.sh ==="

# --- defaults when no config file ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

unset WT_BASE_BRANCH WT_BASE_PATH 2>/dev/null || true
wt_load_config "$REPO_DIR"
assert_eq "default base path" ".worktrees" "$WT_BASE_PATH"

cleanup_test_repo "$REPO_DIR"

# --- config file values ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

mkdir -p .worktrees
cat > .worktrees/config <<'CONF'
WT_BASE_BRANCH=develop
WT_BASE_PATH=.wt
CONF

unset WT_BASE_BRANCH WT_BASE_PATH 2>/dev/null || true
wt_load_config "$REPO_DIR"
assert_eq "config file base branch" "develop" "$WT_BASE_BRANCH"
assert_eq "config file base path" ".wt" "$WT_BASE_PATH"

cleanup_test_repo "$REPO_DIR"

# --- env vars override config file ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

mkdir -p .worktrees
cat > .worktrees/config <<'CONF'
WT_BASE_BRANCH=develop
CONF

export WT_BASE_BRANCH=release
wt_load_config "$REPO_DIR"
assert_eq "env overrides config file" "release" "$WT_BASE_BRANCH"
unset WT_BASE_BRANCH

cleanup_test_repo "$REPO_DIR"

test_summary
