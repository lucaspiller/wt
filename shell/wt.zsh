#!/usr/bin/env zsh
# Source this file in .zshrc:
#   source /path/to/wt/shell/wt.zsh
#
# Requires bin/wt to be on PATH.

wt() {
    local result
    result="$(command wt "$@")"
    local rc=$?
    if [ $rc -eq 0 ] && [ -d "$result" ]; then
        cd "$result" || return 1
    elif [ -n "$result" ]; then
        echo "$result"
    fi
    return $rc
}
