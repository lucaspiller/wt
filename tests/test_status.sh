#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

WT_BIN="$PROJECT_ROOT/bin/wt"

echo "=== wt status ==="

# --- setup mock gh ---

MOCK_DIR="$(mktemp -d)"
cat > "$MOCK_DIR/gh" <<'MOCK'
#!/usr/bin/env bash
branch="$3"
case "$branch" in
  reviewed-wt)
    echo '{"headRefName":"reviewed-wt","title":"Add feature X","state":"OPEN","isDraft":false,"reviewDecision":"APPROVED","statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"}]}'
    ;;
  merged-wt)
    echo '{"headRefName":"merged-wt","title":"Fix bug Y","state":"MERGED","isDraft":false,"reviewDecision":"APPROVED","statusCheckRollup":[{"status":"COMPLETED","conclusion":"SUCCESS"}]}'
    ;;
  *)
    exit 1
    ;;
esac
MOCK
chmod +x "$MOCK_DIR/gh"

# --- shows worktrees in correct buckets ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

"$WT_BIN" progress-wt >/dev/null 2>&1
"$WT_BIN" reviewed-wt >/dev/null 2>&1
"$WT_BIN" merged-wt >/dev/null 2>&1

export PATH="$MOCK_DIR:$PATH"

output="$(bash "$PROJECT_ROOT/commands/status.sh" "$REPO_DIR" 2>/dev/null)"

assert_contains "has in progress section" "$output" "In Progress"
assert_contains "has in review section" "$output" "In Review"
assert_contains "has done section" "$output" "Done"
assert_contains "progress-wt in output" "$output" "progress-wt"
assert_contains "reviewed-wt in output" "$output" "reviewed-wt"
assert_contains "merged-wt in output" "$output" "merged-wt"

cleanup_test_repo "$REPO_DIR"
rm -rf "$MOCK_DIR"

# --- shows message when no worktrees ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

output="$(bash "$PROJECT_ROOT/commands/status.sh" "$REPO_DIR" 2>&1)"
assert_contains "no worktrees message" "$output" "no worktrees"

cleanup_test_repo "$REPO_DIR"

test_summary
