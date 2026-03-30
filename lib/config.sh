#!/usr/bin/env bash

wt_load_config() {
    local repo_root="$1"

    local saved_base_branch="${WT_BASE_BRANCH:-}"
    local saved_base_path="${WT_BASE_PATH:-}"

    WT_BASE_BRANCH=""
    WT_BASE_PATH=""

    local config_file="$repo_root/.worktrees/config"
    if [ -f "$config_file" ]; then
        while IFS='=' read -r key value; do
            [[ "$key" =~ ^#.*$ ]] && continue
            [ -z "$key" ] && continue
            key="$(echo "$key" | tr -d '[:space:]')"
            value="$(echo "$value" | tr -d '[:space:]')"
            case "$key" in
                WT_BASE_BRANCH) WT_BASE_BRANCH="$value" ;;
                WT_BASE_PATH)   WT_BASE_PATH="$value" ;;
            esac
        done < "$config_file"
    fi

    [ -n "$saved_base_branch" ] && WT_BASE_BRANCH="$saved_base_branch"
    [ -n "$saved_base_path" ]   && WT_BASE_PATH="$saved_base_path"

    : "${WT_BASE_PATH:=.worktrees}"

    export WT_BASE_BRANCH WT_BASE_PATH
}
