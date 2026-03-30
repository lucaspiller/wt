#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

WT_BIN="$PROJECT_ROOT/bin/wt"

echo "=== wt rm ==="

# --- removes a clean worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

"$WT_BIN" clean-wt >/dev/null 2>&1

assert_dir_exists "worktree exists before rm" "$REPO_DIR/.worktrees/clean-wt"

"$WT_BIN" rm clean-wt >/dev/null 2>&1

assert_eq "worktree dir removed" "false" "$([ -d "$REPO_DIR/.worktrees/clean-wt" ] && echo true || echo false)"

cleanup_test_repo "$REPO_DIR"

# --- refuses to remove worktree with uncommitted changes ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

"$WT_BIN" dirty-wt >/dev/null 2>&1

echo "dirty file" > "$REPO_DIR/.worktrees/dirty-wt/untracked.txt"

stderr="$("$WT_BIN" rm dirty-wt 2>&1 || true)"
assert_contains "errors on dirty worktree" "$stderr" "uncommitted changes"
assert_dir_exists "worktree still exists" "$REPO_DIR/.worktrees/dirty-wt"

cleanup_test_repo "$REPO_DIR"

# --- refuses to remove worktree with unpushed commits ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

"$WT_BIN" unpushed-wt >/dev/null 2>&1

cd "$REPO_DIR/.worktrees/unpushed-wt"
echo "new file" > somefile.txt
git add somefile.txt >/dev/null 2>&1
git commit -m "unpushed commit" >/dev/null 2>&1
cd "$REPO_DIR"

stderr="$("$WT_BIN" rm unpushed-wt 2>&1 || true)"
assert_contains "errors on unpushed commits" "$stderr" "unpushed"
assert_dir_exists "worktree still exists" "$REPO_DIR/.worktrees/unpushed-wt"

cleanup_test_repo "$REPO_DIR"

# --- --force removes dirty worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

"$WT_BIN" force-wt >/dev/null 2>&1

echo "dirty" > "$REPO_DIR/.worktrees/force-wt/untracked.txt"

"$WT_BIN" rm force-wt --force >/dev/null 2>&1

assert_eq "worktree removed with force" "false" "$([ -d "$REPO_DIR/.worktrees/force-wt" ] && echo true || echo false)"

cleanup_test_repo "$REPO_DIR"

# --- errors if worktree doesn't exist ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

stderr="$("$WT_BIN" rm nonexistent 2>&1 || true)"
assert_contains "errors on missing worktree" "$stderr" "does not exist"

cleanup_test_repo "$REPO_DIR"

# --- removes branch along with worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

"$WT_BIN" branch-cleanup >/dev/null 2>&1

"$WT_BIN" rm branch-cleanup >/dev/null 2>&1

branch_exists="$(git branch --list branch-cleanup)"
assert_eq "branch also removed" "" "$branch_exists"

cleanup_test_repo "$REPO_DIR"

# --- outputs repo root so shell wrapper can cd there ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

"$WT_BIN" cd-back-wt >/dev/null 2>&1

stdout="$("$WT_BIN" rm cd-back-wt 2>/dev/null)"
assert_eq "rm outputs repo root" "$REPO_DIR" "$stdout"

cleanup_test_repo "$REPO_DIR"

test_summary
