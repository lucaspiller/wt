#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== commands/cd.sh ==="

# --- creates a new worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

stdout="$(bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "test-feature" "" 2>/dev/null)"
assert_dir_exists "worktree directory created" "$REPO_DIR/.worktrees/test-feature"
assert_eq "prints worktree path" "$REPO_DIR/.worktrees/test-feature" "$stdout"

branch_exists="$(git branch --list test-feature)"
assert_contains "branch created" "$branch_exists" "test-feature"

cleanup_test_repo "$REPO_DIR"

# --- switches to existing worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "existing-wt" "" >/dev/null 2>&1

stdout="$(bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "existing-wt" "" 2>/dev/null)"
assert_eq "prints path for existing worktree" "$REPO_DIR/.worktrees/existing-wt" "$stdout"

cleanup_test_repo "$REPO_DIR"

# --- respects --from flag ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

git checkout -b develop >/dev/null 2>&1
git commit --allow-empty -m "develop commit" >/dev/null 2>&1
git checkout main >/dev/null 2>&1

bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "from-develop" "develop" >/dev/null 2>&1

cd "$REPO_DIR/.worktrees/from-develop"
parent_log="$(git log --oneline -1)"
assert_contains "based on develop" "$parent_log" "develop commit"

cleanup_test_repo "$REPO_DIR"

# --- runs create hooks on new worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

mkdir -p .worktrees/hooks/create
cat > .worktrees/hooks/create/01-marker <<'HOOK'
#!/usr/bin/env bash
touch "$1/.created-marker"
HOOK
chmod +x .worktrees/hooks/create/01-marker

bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "hooked-wt" "" >/dev/null 2>&1

assert_file_exists "create hook ran" "$REPO_DIR/.worktrees/hooked-wt/.created-marker"

cleanup_test_repo "$REPO_DIR"

# --- runs switch hooks on existing worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "switch-test" "" >/dev/null 2>&1

mkdir -p .worktrees/hooks/switch
cat > .worktrees/hooks/switch/01-marker <<'HOOK'
#!/usr/bin/env bash
touch "$1/.switched-marker"
HOOK
chmod +x .worktrees/hooks/switch/01-marker

bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "switch-test" "" >/dev/null 2>&1

assert_file_exists "switch hook ran" "$REPO_DIR/.worktrees/switch-test/.switched-marker"

cleanup_test_repo "$REPO_DIR"

# --- uses existing branch without -b ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

git branch existing-branch >/dev/null 2>&1

stdout="$(bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "existing-branch" "" 2>/dev/null)"
assert_dir_exists "worktree from existing branch" "$REPO_DIR/.worktrees/existing-branch"

cleanup_test_repo "$REPO_DIR"

test_summary
