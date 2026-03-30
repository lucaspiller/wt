#!/usr/bin/env bash

_GH_PR_DATA=""

wt_gh_fetch_prs() {
    local repo_dir="${1:-.}"
    shift
    local branches=("$@")
    _GH_PR_DATA="[]"

    if ! command -v gh >/dev/null 2>&1; then
        _GH_PR_DATA=""
        return 0
    fi

    if [ ${#branches[@]} -eq 0 ]; then
        _GH_PR_DATA=""
        return 0
    fi

    local results="["
    local first=true
    for branch in "${branches[@]}"; do
        local pr_json
        pr_json="$(cd "$repo_dir" && gh pr view "$branch" \
            --json headRefName,title,state,isDraft,statusCheckRollup,reviewDecision \
            2>/dev/null)" || continue
        if [ "$first" = true ]; then
            first=false
        else
            results="$results,"
        fi
        results="$results$pr_json"
    done
    results="$results]"

    _GH_PR_DATA="$results"
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
if not checks:
    sys.exit(0)
has_failure = False
has_pending = False
for c in checks:
    status = c.get('status', '')
    conclusion = c.get('conclusion', '')
    # Legacy format uses 'state' directly
    state = c.get('state', '')
    if status in ('IN_PROGRESS', 'QUEUED', 'WAITING') or state in ('PENDING', 'QUEUED', 'IN_PROGRESS'):
        has_pending = True
    elif conclusion in ('FAILURE', 'TIMED_OUT', 'CANCELLED') or state in ('FAILURE', 'ERROR'):
        has_failure = True
if has_failure:
    print('FAILURE')
elif has_pending:
    print('PENDING')
else:
    print('SUCCESS')
" 2>/dev/null
}
