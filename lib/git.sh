#!/usr/bin/env bash

wt_git_repo_root() {
    git rev-parse --show-toplevel
}

wt_git_main_branch() {
    local branch
    for branch in main master; do
        if git show-ref --verify --quiet "refs/heads/$branch"; then
            echo "$branch"
            return 0
        fi
    done
    echo "main"
    return 0
}
