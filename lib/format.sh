#!/usr/bin/env bash

_FMT_RED='\033[31m'
_FMT_GREEN='\033[32m'
_FMT_YELLOW='\033[33m'
_FMT_DIM='\033[2m'
_FMT_BOLD='\033[1m'
_FMT_RESET='\033[0m'

fmt_red()    { printf "${_FMT_RED}%s${_FMT_RESET}" "$1"; }
fmt_green()  { printf "${_FMT_GREEN}%s${_FMT_RESET}" "$1"; }
fmt_yellow() { printf "${_FMT_YELLOW}%s${_FMT_RESET}" "$1"; }
fmt_dim()    { printf "${_FMT_DIM}%s${_FMT_RESET}" "$1"; }
fmt_bold()   { printf "${_FMT_BOLD}%s${_FMT_RESET}" "$1"; }

fmt_icon_pass()    { fmt_green "✓"; }
fmt_icon_fail()    { fmt_red "✗"; }
fmt_icon_pending() { fmt_yellow "◌"; }
fmt_icon_dirty()   { fmt_red "●"; }
fmt_icon_clean()   { fmt_green "✓"; }

fmt_relative_time() {
    local timestamp="$1"
    local now
    now="$(date +%s)"
    local diff=$((now - timestamp))

    if [ "$diff" -lt 60 ]; then
        echo "just now"
    elif [ "$diff" -lt 3600 ]; then
        echo "$((diff / 60))m ago"
    elif [ "$diff" -lt 86400 ]; then
        echo "$((diff / 3600))h ago"
    elif [ "$diff" -lt 604800 ]; then
        echo "$((diff / 86400))d ago"
    else
        echo "$((diff / 604800))w ago"
    fi
}
