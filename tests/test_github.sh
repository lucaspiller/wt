#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"
source "$PROJECT_ROOT/lib/github.sh"

echo "=== lib/github.sh ==="

# --- setup mock gh ---

MOCK_DIR="$(mktemp -d)"
cat > "$MOCK_DIR/gh" <<'MOCK'
#!/usr/bin/env bash
cat <<'JSON'
[
  {
    "headRefName": "feat-login",
    "title": "Add login page",
    "state": "OPEN",
    "isDraft": false,
    "reviewDecision": "APPROVED",
    "statusCheckRollup": [{"state": "SUCCESS"}]
  },
  {
    "headRefName": "fix-bug",
    "title": "Fix crash on save",
    "state": "MERGED",
    "isDraft": false,
    "reviewDecision": "APPROVED",
    "statusCheckRollup": [{"state": "SUCCESS"}]
  },
  {
    "headRefName": "wip-draft",
    "title": "WIP: new feature",
    "state": "OPEN",
    "isDraft": true,
    "reviewDecision": "",
    "statusCheckRollup": [{"state": "PENDING"}]
  }
]
JSON
MOCK
chmod +x "$MOCK_DIR/gh"
export PATH="$MOCK_DIR:$PATH"

# --- fetches and parses PR data ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

wt_gh_fetch_prs

result="$(wt_gh_pr_state "feat-login")"
assert_eq "open PR state" "OPEN" "$result"

result="$(wt_gh_pr_state "fix-bug")"
assert_eq "merged PR state" "MERGED" "$result"

result="$(wt_gh_pr_state "no-pr-branch")"
assert_eq "no PR returns empty" "" "$result"

result="$(wt_gh_pr_title "feat-login")"
assert_eq "PR title" "Add login page" "$result"

result="$(wt_gh_pr_is_draft "wip-draft")"
assert_eq "draft PR detected" "true" "$result"

result="$(wt_gh_pr_is_draft "feat-login")"
assert_eq "non-draft PR" "false" "$result"

result="$(wt_gh_pr_ci_status "feat-login")"
assert_eq "CI passing" "SUCCESS" "$result"

result="$(wt_gh_pr_review "feat-login")"
assert_eq "review approved" "APPROVED" "$result"

cleanup_test_repo "$REPO_DIR"
rm -rf "$MOCK_DIR"

# --- graceful when gh is not available ---

EMPTY_DIR="$(mktemp -d)"
_OLD_PATH="$PATH"
export PATH="$EMPTY_DIR"
wt_gh_fetch_prs 2>/dev/null

result="$(wt_gh_pr_state "anything")"
assert_eq "no gh returns empty" "" "$result"

export PATH="$_OLD_PATH"
rm -rf "$EMPTY_DIR"

test_summary
