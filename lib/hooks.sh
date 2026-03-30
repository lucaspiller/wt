#!/usr/bin/env bash

wt_run_hooks() {
    local hook_dir="$1"
    local worktree_path="$2"

    [ -d "$hook_dir" ] || return 0

    local hooks=()
    while IFS= read -r -d '' hook; do
        [ -x "$hook" ] || continue
        hooks+=("$hook")
    done < <(find "$hook_dir" -maxdepth 1 -type f -print0 | sort -z)

    for hook in "${hooks[@]}"; do
        local hook_name
        hook_name="$(basename "$hook")"
        echo "wt: running hook '$hook_name'" >&2
        if ! "$hook" "$worktree_path"; then
            echo "wt: warning: hook '$hook_name' exited with non-zero status" >&2
        fi
    done
}
