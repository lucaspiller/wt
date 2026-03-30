#!/usr/bin/env bash

wt_git_repo_root() {
    local common_dir
    common_dir="$(git rev-parse --git-common-dir 2>/dev/null)" || return 1

    # In a worktree, --git-common-dir points to the main repo's .git
    # In the main repo, it returns ".git"
    if [ "$common_dir" = ".git" ]; then
        git rev-parse --show-toplevel
    else
        (cd "$common_dir/.." && pwd -P)
    fi
}

wt_git_main_branch() {
    # Check remote HEAD first (most reliable)
    local remote_head
    if remote_head="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null)"; then
        echo "${remote_head#refs/remotes/origin/}"
        return 0
    fi

    # Fall back to common names
    local branch
    for branch in main master dev develop; do
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            echo "$branch"
            return 0
        fi
    done

    echo "wt: could not detect default branch — set WT_BASE_BRANCH in .worktrees/config" >&2
    return 1
}
