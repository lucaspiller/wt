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

    wt_gh_fetch_prs "$repo_root" "${worktrees[@]}"

    local in_progress=()
    local in_review=()
    local done_list=()

    for name in "${worktrees[@]}"; do
        local wt_path="$base_path/$name"
        local branch="$name"

        local is_dirty="false"
        local dirty_output
        dirty_output="$(git -C "$wt_path" status --porcelain 2>/dev/null || true)"
        [ -n "$dirty_output" ] && is_dirty="true"

        local last_commit_ts
        last_commit_ts="$(git -C "$wt_path" log -1 --format=%ct 2>/dev/null || echo "0")"

        local pr_state pr_title pr_draft pr_ci pr_review
        pr_state="$(wt_gh_pr_state "$branch")"
        pr_title="$(wt_gh_pr_title "$branch")"
        pr_draft="$(wt_gh_pr_is_draft "$branch")"
        pr_ci="$(wt_gh_pr_ci_status "$branch")"
        pr_review="$(wt_gh_pr_review "$branch")"

        local line
        line="$(_wt_format_line "$name" "$is_dirty" "$last_commit_ts" "$pr_title" "$pr_ci" "$pr_review" "$pr_state")"

        if [ "$pr_state" = "MERGED" ] && [ "$is_dirty" = "false" ]; then
            done_list+=("$line")
        elif [ "$pr_state" = "OPEN" ] && [ "$pr_draft" != "true" ]; then
            in_review+=("$line")
        else
            in_progress+=("$line")
        fi
    done

    if [ ${#in_progress[@]} -gt 0 ]; then
        echo ""
        echo "  $(fmt_bold "$(fmt_yellow "▸ In Progress")")"
        for line in "${in_progress[@]}"; do
            echo "    $line"
        done
    fi

    if [ ${#in_review[@]} -gt 0 ]; then
        echo ""
        echo "  $(fmt_bold "$(fmt_green "▸ In Review")")"
        for line in "${in_review[@]}"; do
            echo "    $line"
        done
    fi

    if [ ${#done_list[@]} -gt 0 ]; then
        echo ""
        echo "  $(fmt_bold "$(fmt_dim "▸ Done")")"
        for line in "${done_list[@]}"; do
            echo "    $line"
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

    if [ "$is_dirty" = "true" ]; then
        parts="$(fmt_icon_dirty)"
    else
        parts="$(fmt_icon_clean)"
    fi

    parts="$parts $(fmt_bold "$name")"

    if [ "$last_commit_ts" != "0" ]; then
        parts="$parts $(fmt_dim "$(fmt_relative_time "$last_commit_ts")")"
    fi

    if [ -n "$pr_title" ]; then
        parts="$parts  $(fmt_dim "$pr_title")"

        if [ -n "$pr_ci" ]; then
            case "$pr_ci" in
                SUCCESS) parts="$parts $(fmt_icon_pass) $(fmt_green "ci passed")" ;;
                FAILURE|ERROR) parts="$parts $(fmt_icon_fail) $(fmt_red "ci failed")" ;;
                PENDING) parts="$parts $(fmt_icon_pending) $(fmt_yellow "ci running")" ;;
            esac
        fi

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
