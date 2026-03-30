#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"
source "$PROJECT_ROOT/lib/hooks.sh"

echo "=== lib/hooks.sh ==="

# --- runs hooks in lexicographic order ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

HOOK_DIR="$REPO_DIR/.worktrees/hooks/create"
mkdir -p "$HOOK_DIR"

cat > "$HOOK_DIR/02-second" <<'HOOK'
#!/usr/bin/env bash
echo "second" >> "$1/.hook-log"
HOOK
cat > "$HOOK_DIR/01-first" <<'HOOK'
#!/usr/bin/env bash
echo "first" >> "$1/.hook-log"
HOOK

TARGET="$REPO_DIR/.worktrees/test-wt"
mkdir -p "$TARGET"

wt_run_hooks "$HOOK_DIR" "$TARGET" "$REPO_DIR" 2>/dev/null
assert_file_exists "hook log created" "$TARGET/.hook-log"

first_line="$(head -1 "$TARGET/.hook-log")"
assert_eq "first hook ran first" "first" "$first_line"

second_line="$(tail -1 "$TARGET/.hook-log")"
assert_eq "second hook ran second" "second" "$second_line"

cleanup_test_repo "$REPO_DIR"

# --- warns on hook failure but continues ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

HOOK_DIR="$REPO_DIR/.worktrees/hooks/create"
mkdir -p "$HOOK_DIR"

cat > "$HOOK_DIR/01-fail" <<'HOOK'
#!/usr/bin/env bash
exit 1
HOOK
cat > "$HOOK_DIR/02-succeed" <<'HOOK'
#!/usr/bin/env bash
echo "ran" >> "$1/.hook-log"
HOOK

TARGET="$REPO_DIR/.worktrees/test-wt"
mkdir -p "$TARGET"

stderr="$(wt_run_hooks "$HOOK_DIR" "$TARGET" "$REPO_DIR" 2>&1)"
assert_contains "warning printed for failed hook" "$stderr" "warning"
assert_file_exists "second hook still ran" "$TARGET/.hook-log"

cleanup_test_repo "$REPO_DIR"

# --- hooks receive repo root as $2 ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

HOOK_DIR="$REPO_DIR/.worktrees/hooks/create"
mkdir -p "$HOOK_DIR"

cat > "$HOOK_DIR/01-check-root" <<'HOOK'
#!/usr/bin/env bash
echo "$2" > "$1/.repo-root"
HOOK

TARGET="$REPO_DIR/.worktrees/test-wt"
mkdir -p "$TARGET"

wt_run_hooks "$HOOK_DIR" "$TARGET" "$REPO_DIR" 2>/dev/null
assert_file_exists "repo root file created" "$TARGET/.repo-root"

root_value="$(cat "$TARGET/.repo-root")"
assert_eq "hook received repo root as \$2" "$REPO_DIR" "$root_value"

cleanup_test_repo "$REPO_DIR"

# --- no hooks dir is a no-op ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

wt_run_hooks "$REPO_DIR/.worktrees/hooks/create" "$REPO_DIR" "$REPO_DIR" 2>/dev/null
assert_exit_code "missing hook dir is ok" "0" "$?"

cleanup_test_repo "$REPO_DIR"

test_summary
