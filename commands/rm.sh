#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

source "$LIB_DIR/git.sh"
source "$LIB_DIR/config.sh"

wt_rm() {
    local repo_root="$1"
    local name="$2"
    local force="${3:-}"

    wt_load_config "$repo_root"

    local base_path="$repo_root/$WT_BASE_PATH"
    local worktree_path="$base_path/$name"

    if [ ! -d "$worktree_path" ]; then
        echo "wt: worktree '$name' does not exist" >&2
        return 1
    fi

    if [ "$force" != "--force" ]; then
        local dirty
        dirty="$(git -C "$worktree_path" status --porcelain 2>/dev/null)"
        if [ -n "$dirty" ]; then
            echo "wt: worktree '$name' has uncommitted changes (use --force to override)" >&2
            return 1
        fi

        local unpushed=""
        if git -C "$worktree_path" rev-parse --verify '@{upstream}' >/dev/null 2>&1; then
            unpushed="$(git -C "$worktree_path" log --oneline '@{upstream}..HEAD' 2>/dev/null)"
        else
            local default_branch
            default_branch="$(wt_git_main_branch 2>/dev/null || true)"
            if [ -n "$default_branch" ]; then
                unpushed="$(git -C "$worktree_path" log --oneline "$default_branch..HEAD" 2>/dev/null || true)"
            fi
        fi

        if [ -n "$unpushed" ]; then
            echo "wt: worktree '$name' has unpushed commits (use --force to override)" >&2
            return 1
        fi
    fi

    echo "wt: removing worktree '$name'" >&2

    cd "$repo_root"

    git worktree remove "$worktree_path" --force 2>/dev/null || {
        rm -rf "$worktree_path"
        git worktree prune 2>/dev/null
    }

    if git show-ref --verify --quiet "refs/heads/$name"; then
        git branch -D "$name" >/dev/null 2>&1 || true
        echo "wt: deleted branch '$name'" >&2
    fi

    echo "$repo_root"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    wt_rm "$@"
fi
