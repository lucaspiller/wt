#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

source "$LIB_DIR/git.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/hooks.sh"

wt_cd() {
    local repo_root="$1"
    local name="$2"
    local from_branch="${3:-}"

    wt_load_config "$repo_root"

    local base_path="$repo_root/$WT_BASE_PATH"
    local worktree_path="$base_path/$name"

    if [ -d "$worktree_path" ]; then
        echo "wt: switching to '$name'" >&2
        local switch_hooks="$base_path/hooks/switch"
        wt_run_hooks "$switch_hooks" "$worktree_path"
        echo "$worktree_path"
        return 0
    fi

    mkdir -p "$base_path"

    if [ -z "$from_branch" ]; then
        if [ -n "${WT_BASE_BRANCH:-}" ]; then
            from_branch="$WT_BASE_BRANCH"
        else
            from_branch="$(wt_git_main_branch)"
        fi
    fi

    echo "wt: creating worktree '$name' from '$from_branch'" >&2

    if git show-ref --verify --quiet "refs/heads/$name"; then
        git worktree add "$worktree_path" "$name" >/dev/null 2>&1
    else
        git worktree add -b "$name" "$worktree_path" "$from_branch" >/dev/null 2>&1
    fi

    local create_hooks="$base_path/hooks/create"
    wt_run_hooks "$create_hooks" "$worktree_path"

    echo "$worktree_path"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    wt_cd "$@"
fi
