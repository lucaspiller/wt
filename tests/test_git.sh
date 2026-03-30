#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"
source "$PROJECT_ROOT/lib/git.sh"

echo "=== lib/git.sh ==="

# --- git_repo_root ---

REPO_DIR="$(setup_test_repo)"

cd "$REPO_DIR"
# Compare canonical paths: macOS often has /var/... (mktemp) vs /private/var/... (git).
expected_root="$(pwd -P)"
result="$(wt_git_repo_root)"
assert_eq "repo root from top level" "$expected_root" "$result"

mkdir -p sub/deep
cd sub/deep
result="$(wt_git_repo_root)"
assert_eq "repo root from nested dir" "$expected_root" "$result"

cleanup_test_repo "$REPO_DIR"

# --- repo root resolves to main repo from inside a worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"
expected_root="$(pwd -P)"

git worktree add .worktrees/inside-wt -b inside-wt main >/dev/null 2>&1
cd .worktrees/inside-wt
result="$(wt_git_repo_root)"
assert_eq "repo root from inside worktree" "$expected_root" "$result"

cleanup_test_repo "$REPO_DIR"

# --- wt_git_main_branch ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

result="$(wt_git_main_branch)"
assert_eq "detects main branch" "main" "$result"

cleanup_test_repo "$REPO_DIR"

# test with master
REPO_DIR="$(mktemp -d)"
cd "$REPO_DIR"
git init -b master . >/dev/null 2>&1
git commit --allow-empty -m "initial" >/dev/null 2>&1

result="$(wt_git_main_branch)"
assert_eq "detects master branch" "master" "$result"

cleanup_test_repo "$REPO_DIR"

# test with dev branch
REPO_DIR="$(mktemp -d)"
cd "$REPO_DIR"
git init -b dev . >/dev/null 2>&1
git commit --allow-empty -m "initial" >/dev/null 2>&1

result="$(wt_git_main_branch)"
assert_eq "detects dev branch" "dev" "$result"

cleanup_test_repo "$REPO_DIR"

# test with remote HEAD (origin/HEAD → origin/dev)
REPO_DIR="$(mktemp -d)"
cd "$REPO_DIR"
git init -b custom-default . >/dev/null 2>&1
git commit --allow-empty -m "initial" >/dev/null 2>&1
# simulate origin/HEAD pointing to custom-default
git remote add origin "$REPO_DIR" >/dev/null 2>&1
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/custom-default >/dev/null 2>&1

result="$(wt_git_main_branch)"
assert_eq "detects branch from remote HEAD" "custom-default" "$result"

cleanup_test_repo "$REPO_DIR"

# test with no recognizable default branch
REPO_DIR="$(mktemp -d)"
cd "$REPO_DIR"
git init -b something-weird . >/dev/null 2>&1
git commit --allow-empty -m "initial" >/dev/null 2>&1

result="$(wt_git_main_branch 2>/dev/null || true)"
assert_eq "unknown branch returns empty" "" "$result"

cleanup_test_repo "$REPO_DIR"

test_summary
