#!/usr/bin/env bash
set -euo pipefail

wt_exit() {
    local repo_root="$1"
    echo "wt: leaving worktree" >&2
    echo "$repo_root"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    wt_exit "$@"
fi
