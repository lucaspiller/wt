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
