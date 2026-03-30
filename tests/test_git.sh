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

test_summary
