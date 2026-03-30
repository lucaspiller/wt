#!/usr/bin/env bash
# Minimal test harness for wt

_TESTS_RUN=0
_TESTS_PASSED=0
_TESTS_FAILED=0

setup_test_repo() {
    local tmpdir
    tmpdir="$(mktemp -d)"
    cd "$tmpdir" || exit 1
    git init -b main . >/dev/null 2>&1
    git commit --allow-empty -m "initial" >/dev/null 2>&1
    echo "$tmpdir"
}

cleanup_test_repo() {
    local dir="$1"
    [ -n "$dir" ] && [ -d "$dir" ] && rm -rf "$dir"
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    if [ "$expected" = "$actual" ]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo "  PASS: $desc"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        echo "  FAIL: $desc"
        echo "    expected: '$expected'"
        echo "    actual:   '$actual'"
    fi
}

assert_dir_exists() {
    local desc="$1" dir="$2"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    if [ -d "$dir" ]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo "  PASS: $desc"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        echo "  FAIL: $desc — directory '$dir' does not exist"
    fi
}

assert_file_exists() {
    local desc="$1" file="$2"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    if [ -f "$file" ]; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo "  PASS: $desc"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        echo "  FAIL: $desc — file '$file' does not exist"
    fi
}

assert_exit_code() {
    local desc="$1" expected="$2" actual="$3"
    assert_eq "$desc (exit code)" "$expected" "$actual"
}

assert_contains() {
    local desc="$1" haystack="$2" needle="$3"
    _TESTS_RUN=$((_TESTS_RUN + 1))
    if echo "$haystack" | grep -qF "$needle"; then
        _TESTS_PASSED=$((_TESTS_PASSED + 1))
        echo "  PASS: $desc"
    else
        _TESTS_FAILED=$((_TESTS_FAILED + 1))
        echo "  FAIL: $desc — output does not contain '$needle'"
        echo "    output: '$haystack'"
    fi
}

test_summary() {
    echo ""
    echo "Results: $_TESTS_PASSED/$_TESTS_RUN passed, $_TESTS_FAILED failed"
    [ "$_TESTS_FAILED" -gt 0 ] && exit 1
    exit 0
}
