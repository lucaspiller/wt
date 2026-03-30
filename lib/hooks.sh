#!/usr/bin/env bash

wt_run_hooks() {
    local hook_dir="$1"
    local worktree_path="$2"
    local repo_root="$3"

    [ -d "$hook_dir" ] || return 0

    local hooks=()
    while IFS= read -r -d '' hook; do
        hooks+=("$hook")
    done < <(find "$hook_dir" -maxdepth 1 -type f -print0 | sort -z)

    for hook in "${hooks[@]}"; do
        local hook_name
        hook_name="$(basename "$hook")"
        echo "wt: running hook '$hook_name'" >&2
        if ! bash "$hook" "$worktree_path" "$repo_root"; then
            echo "wt: warning: hook '$hook_name' exited with non-zero status" >&2
        fi
    done
}
