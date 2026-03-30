# wt status Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a `wt status` command that shows all worktrees grouped by lifecycle (In Progress / In Review / Done) with GitHub PR/CI/review integration and colored output.

**Architecture:** Three new lib files (format.sh for colors, github.sh for gh CLI, worktree.sh for worktree enumeration/info), one new command (status.sh), wired through bin/wt. Tests mock `gh` by injecting a fake script into PATH.

**Tech Stack:** Bash, `gh` CLI for GitHub data (JSON output), ANSI escape codes for color.

---

### Task 1: lib/format.sh — color and formatting helpers

**Files:**
- Create: `lib/format.sh`
- Create: `tests/test_format.sh`

**Step 1: Write the tests**

Create `tests/test_format.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"
source "$PROJECT_ROOT/lib/format.sh"

echo "=== lib/format.sh ==="

# --- color functions produce ANSI codes ---

result="$(fmt_green "hello")"
assert_contains "green wraps text" "$result" "hello"
assert_contains "green has escape code" "$result" "[32m"

result="$(fmt_red "error")"
assert_contains "red wraps text" "$result" "error"
assert_contains "red has escape code" "$result" "[31m"

result="$(fmt_yellow "warn")"
assert_contains "yellow wraps text" "$result" "warn"

result="$(fmt_dim "faded")"
assert_contains "dim wraps text" "$result" "faded"

result="$(fmt_bold "strong")"
assert_contains "bold wraps text" "$result" "strong"

# --- status icons ---

result="$(fmt_icon_pass)"
assert_contains "pass icon is green" "$result" "[32m"

result="$(fmt_icon_fail)"
assert_contains "fail icon is red" "$result" "[31m"

result="$(fmt_icon_pending)"
assert_contains "pending icon is yellow" "$result" "[33m"

# --- relative time ---

now="$(date +%s)"
one_hour_ago=$((now - 3600))
result="$(fmt_relative_time "$one_hour_ago")"
assert_contains "1 hour ago" "$result" "1h ago"

two_days_ago=$((now - 172800))
result="$(fmt_relative_time "$two_days_ago")"
assert_contains "2 days ago" "$result" "2d ago"

thirty_seconds_ago=$((now - 30))
result="$(fmt_relative_time "$thirty_seconds_ago")"
assert_contains "just now" "$result" "just now"

test_summary
```

**Step 2: Run tests — verify they fail**

Run: `bash tests/test_format.sh`
Expected: fails.

**Step 3: Implement lib/format.sh**

Create `lib/format.sh`:

```bash
#!/usr/bin/env bash

_FMT_RED='\033[31m'
_FMT_GREEN='\033[32m'
_FMT_YELLOW='\033[33m'
_FMT_DIM='\033[2m'
_FMT_BOLD='\033[1m'
_FMT_RESET='\033[0m'

fmt_red()    { printf "${_FMT_RED}%s${_FMT_RESET}" "$1"; }
fmt_green()  { printf "${_FMT_GREEN}%s${_FMT_RESET}" "$1"; }
fmt_yellow() { printf "${_FMT_YELLOW}%s${_FMT_RESET}" "$1"; }
fmt_dim()    { printf "${_FMT_DIM}%s${_FMT_RESET}" "$1"; }
fmt_bold()   { printf "${_FMT_BOLD}%s${_FMT_RESET}" "$1"; }

fmt_icon_pass()    { fmt_green "✓"; }
fmt_icon_fail()    { fmt_red "✗"; }
fmt_icon_pending() { fmt_yellow "◌"; }
fmt_icon_dirty()   { fmt_red "●"; }
fmt_icon_clean()   { fmt_green "✓"; }

fmt_relative_time() {
    local timestamp="$1"
    local now
    now="$(date +%s)"
    local diff=$((now - timestamp))

    if [ "$diff" -lt 60 ]; then
        echo "just now"
    elif [ "$diff" -lt 3600 ]; then
        echo "$((diff / 60))m ago"
    elif [ "$diff" -lt 86400 ]; then
        echo "$((diff / 3600))h ago"
    elif [ "$diff" -lt 604800 ]; then
        echo "$((diff / 86400))d ago"
    else
        echo "$((diff / 604800))w ago"
    fi
}
```

**Step 4: Run tests — verify they pass**

Run: `bash tests/test_format.sh`
Expected: all PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add color and formatting helpers"
```

---

### Task 2: lib/github.sh — GitHub PR data fetching

**Files:**
- Create: `lib/github.sh`
- Create: `tests/test_github.sh`

**Step 1: Write the tests**

Tests mock `gh` by putting a fake script on PATH that outputs canned JSON.

Create `tests/test_github.sh`:

```bash
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
export PATH="$EMPTY_DIR"
wt_gh_fetch_prs 2>/dev/null

result="$(wt_gh_pr_state "anything")"
assert_eq "no gh returns empty" "" "$result"

rm -rf "$EMPTY_DIR"

test_summary
```

**Step 2: Run tests — verify they fail**

Run: `bash tests/test_github.sh`
Expected: fails.

**Step 3: Implement lib/github.sh**

Create `lib/github.sh`:

```bash
#!/usr/bin/env bash

_GH_PR_DATA=""

wt_gh_fetch_prs() {
    _GH_PR_DATA=""

    if ! command -v gh >/dev/null 2>&1; then
        return 0
    fi

    _GH_PR_DATA="$(gh pr list --state all \
        --json headRefName,title,state,isDraft,statusCheckRollup,reviewDecision \
        --limit 100 2>/dev/null)" || _GH_PR_DATA=""
}

_wt_gh_field() {
    local branch="$1"
    local field="$2"

    [ -n "$_GH_PR_DATA" ] || return 0

    echo "$_GH_PR_DATA" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for pr in data:
    if pr['headRefName'] == '$branch':
        val = pr.get('$field', '')
        if isinstance(val, list):
            print(json.dumps(val))
        elif isinstance(val, bool):
            print(str(val).lower())
        else:
            print(val)
        break
" 2>/dev/null
}

wt_gh_pr_state()     { _wt_gh_field "$1" "state"; }
wt_gh_pr_title()     { _wt_gh_field "$1" "title"; }
wt_gh_pr_review()    { _wt_gh_field "$1" "reviewDecision"; }
wt_gh_pr_is_draft()  { _wt_gh_field "$1" "isDraft"; }

wt_gh_pr_ci_status() {
    local branch="$1"
    local raw
    raw="$(_wt_gh_field "$branch" "statusCheckRollup")"
    [ -n "$raw" ] || return 0

    echo "$raw" | python3 -c "
import sys, json
checks = json.load(sys.stdin)
states = [c.get('state', '') for c in checks]
if any(s in ('FAILURE', 'ERROR') for s in states):
    print('FAILURE')
elif any(s in ('PENDING', 'QUEUED', 'IN_PROGRESS') for s in states):
    print('PENDING')
elif all(s == 'SUCCESS' for s in states):
    print('SUCCESS')
elif not states:
    print('')
else:
    print('PENDING')
" 2>/dev/null
}
```

Note: uses python3 for JSON parsing since it's available on macOS and avoids adding `jq` as a dependency. Each call is tiny (in-memory string, not a file or network call).

**Step 4: Run tests — verify they pass**

Run: `bash tests/test_github.sh`
Expected: all PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add GitHub PR data fetching library"
```

---

### Task 3: commands/status.sh — the status command

**Files:**
- Create: `commands/status.sh`
- Create: `tests/test_status.sh`

**Step 1: Write the tests**

Create `tests/test_status.sh`:

```bash
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
cat <<'JSON'
[
  {
    "headRefName": "reviewed-wt",
    "title": "Add feature X",
    "state": "OPEN",
    "isDraft": false,
    "reviewDecision": "APPROVED",
    "statusCheckRollup": [{"state": "SUCCESS"}]
  },
  {
    "headRefName": "merged-wt",
    "title": "Fix bug Y",
    "state": "MERGED",
    "isDraft": false,
    "reviewDecision": "APPROVED",
    "statusCheckRollup": [{"state": "SUCCESS"}]
  }
]
JSON
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

output="$(bash "$PROJECT_ROOT/commands/status.sh" "$REPO_DIR" 2>/dev/null)"
assert_contains "no worktrees message" "$output" "no worktrees"

cleanup_test_repo "$REPO_DIR"

test_summary
```

**Step 2: Run tests — verify they fail**

Run: `bash tests/test_status.sh`
Expected: fails.

**Step 3: Implement commands/status.sh**

Create `commands/status.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

source "$LIB_DIR/git.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/github.sh"
source "$LIB_DIR/format.sh"

wt_status() {
    local repo_root="$1"

    wt_load_config "$repo_root"

    local base_path="$repo_root/$WT_BASE_PATH"

    if [ ! -d "$base_path" ]; then
        echo "wt: no worktrees" >&2
        return 0
    fi

    # Enumerate worktrees (skip hooks dir and config file)
    local worktrees=()
    for dir in "$base_path"/*/; do
        [ -d "$dir" ] || continue
        local name
        name="$(basename "$dir")"
        [ "$name" = "hooks" ] && continue
        worktrees+=("$name")
    done

    if [ ${#worktrees[@]} -eq 0 ]; then
        echo "wt: no worktrees" >&2
        return 0
    fi

    # Fetch GitHub PR data (one batch call)
    wt_gh_fetch_prs

    # Gather info and bucket
    local in_progress=()
    local in_review=()
    local done=()

    for name in "${worktrees[@]}"; do
        local wt_path="$base_path/$name"
        local branch="$name"

        # Git info
        local is_dirty="false"
        local dirty_output
        dirty_output="$(git -C "$wt_path" status --porcelain 2>/dev/null || true)"
        [ -n "$dirty_output" ] && is_dirty="true"

        local last_commit_ts
        last_commit_ts="$(git -C "$wt_path" log -1 --format=%ct 2>/dev/null || echo "0")"

        # PR info
        local pr_state
        pr_state="$(wt_gh_pr_state "$branch")"
        local pr_title
        pr_title="$(wt_gh_pr_title "$branch")"
        local pr_draft
        pr_draft="$(wt_gh_pr_is_draft "$branch")"
        local pr_ci
        pr_ci="$(wt_gh_pr_ci_status "$branch")"
        local pr_review
        pr_review="$(wt_gh_pr_review "$branch")"

        # Build info line
        local line=""
        line="$(_wt_format_line "$name" "$is_dirty" "$last_commit_ts" "$pr_title" "$pr_ci" "$pr_review" "$pr_state")"

        # Bucket
        if [ "$pr_state" = "MERGED" ] && [ "$is_dirty" = "false" ]; then
            done+=("$line")
        elif [ "$pr_state" = "OPEN" ] && [ "$pr_draft" != "true" ]; then
            in_review+=("$line")
        else
            in_progress+=("$line")
        fi
    done

    # Render
    if [ ${#in_progress[@]} -gt 0 ]; then
        echo ""
        fmt_bold "$(fmt_yellow "▸ In Progress")"
        echo ""
        for line in "${in_progress[@]}"; do
            echo "  $line"
        done
    fi

    if [ ${#in_review[@]} -gt 0 ]; then
        echo ""
        fmt_bold "$(fmt_green "▸ In Review")"
        echo ""
        for line in "${in_review[@]}"; do
            echo "  $line"
        done
    fi

    if [ ${#done[@]} -gt 0 ]; then
        echo ""
        fmt_bold "$(fmt_dim "▸ Done")"
        echo ""
        for line in "${done[@]}"; do
            echo "  $line"
        done
    fi

    echo ""
}

_wt_format_line() {
    local name="$1"
    local is_dirty="$2"
    local last_commit_ts="$3"
    local pr_title="$4"
    local pr_ci="$5"
    local pr_review="$6"
    local pr_state="$7"

    local parts=""

    # Dirty indicator
    if [ "$is_dirty" = "true" ]; then
        parts="$(fmt_icon_dirty)"
    else
        parts="$(fmt_icon_clean)"
    fi

    # Branch name
    parts="$parts $(fmt_bold "$name")"

    # Last commit age
    if [ "$last_commit_ts" != "0" ]; then
        parts="$parts $(fmt_dim "$(fmt_relative_time "$last_commit_ts")")"
    fi

    # PR info
    if [ -n "$pr_title" ]; then
        parts="$parts  $(fmt_dim "$pr_title")"

        # CI status
        if [ -n "$pr_ci" ]; then
            case "$pr_ci" in
                SUCCESS) parts="$parts $(fmt_icon_pass)" ;;
                FAILURE|ERROR) parts="$parts $(fmt_icon_fail)" ;;
                PENDING) parts="$parts $(fmt_icon_pending)" ;;
            esac
        fi

        # Review status
        if [ -n "$pr_review" ]; then
            case "$pr_review" in
                APPROVED) parts="$parts $(fmt_green "approved")" ;;
                CHANGES_REQUESTED) parts="$parts $(fmt_red "changes requested")" ;;
                REVIEW_REQUIRED) parts="$parts $(fmt_yellow "review needed")" ;;
            esac
        fi
    fi

    echo "$parts"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    wt_status "$@"
fi
```

**Step 4: Run tests — verify they pass**

Run: `bash tests/test_status.sh`
Expected: all PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: implement status command with GitHub integration"
```

---

### Task 4: Wire into bin/wt + update README

**Files:**
- Modify: `bin/wt`
- Modify: `README.md`

**Step 1: Add status to bin/wt dispatch**

Add a `status)` case in the dispatch, before the `-h|--help)` case:

```bash
    status)
        exec bash "$COMMANDS_DIR/status.sh" "$REPO_ROOT"
        ;;
```

Update the usage function to include:

```bash
    echo "       wt status" >&2
```

**Step 2: Update README.md**

Add `wt status` to the usage section and add a brief description.

**Step 3: Run all tests**

Run: `bash tests/run_all.sh`
Expected: ALL TESTS PASSED.

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: wire status command into dispatch, update README"
```
