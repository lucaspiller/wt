# wt v1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the `wt` CLI tool — a bash worktree manager that creates-or-switches with one command.

**Architecture:** Subcommand dispatch. `bin/wt` dispatches to `commands/`. Shared logic in `lib/`. Shell functions in `shell/` handle `cd`. All human output to stderr, only paths to stdout.

**Tech Stack:** Bash (4.0+), plain bash test scripts with a minimal assertion helper.

---

### Task 1: Scaffolding + test harness

**Files:**
- Create: `bin/wt`
- Create: `tests/helpers.sh`
- Create: `.gitignore`

**Step 1: Create directory structure**

```bash
mkdir -p bin commands lib shell tests
```

**Step 2: Create .gitignore**

Create `.gitignore`:

```
.worktrees/
```

**Step 3: Create test helper**

Create `tests/helpers.sh`:

```bash
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
```

**Step 4: Create placeholder bin/wt**

Create `bin/wt` (just enough to be executable):

```bash
#!/usr/bin/env bash
set -euo pipefail
echo "wt: not yet implemented" >&2
exit 1
```

```bash
chmod +x bin/wt
```

**Step 5: Verify scaffolding**

Run: `ls -R bin commands lib shell tests`
Expected: all directories exist, `bin/wt` is executable, `tests/helpers.sh` exists.

**Step 6: Commit**

```bash
git add -A
git commit -m "chore: project scaffolding and test harness"
```

---

### Task 2: lib/git.sh — git helpers

**Files:**
- Create: `lib/git.sh`
- Create: `tests/test_git.sh`

**Step 1: Write the tests**

Create `tests/test_git.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"
source "$PROJECT_ROOT/lib/git.sh"

echo "=== lib/git.sh ==="

# --- git_repo_root ---

REPO_DIR="$(setup_test_repo)"

cd "$REPO_DIR"
result="$(wt_git_repo_root)"
assert_eq "repo root from top level" "$REPO_DIR" "$result"

mkdir -p sub/deep
cd sub/deep
result="$(wt_git_repo_root)"
assert_eq "repo root from nested dir" "$REPO_DIR" "$result"

cleanup_test_repo "$REPO_DIR"

# --- wt_git_main_branch ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

result="$(wt_git_main_branch)"
assert_eq "detects main branch" "main" "$result"

cleanup_test_repo "$REPO_DIR"

# test with master
REPO_DIR="$(mktemp -d)"
cd "$REPO_DIR"
git init -b master . >/dev/null 2>&1
git commit --allow-empty -m "initial" >/dev/null 2>&1

result="$(wt_git_main_branch)"
assert_eq "detects master branch" "master" "$result"

cleanup_test_repo "$REPO_DIR"

test_summary
```

**Step 2: Run tests — verify they fail**

Run: `bash tests/test_git.sh`
Expected: fails because `lib/git.sh` doesn't exist yet.

**Step 3: Implement lib/git.sh**

Create `lib/git.sh`:

```bash
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
```

**Step 4: Run tests — verify they pass**

Run: `bash tests/test_git.sh`
Expected: all PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add git helper library"
```

---

### Task 3: lib/config.sh — config loading

**Files:**
- Create: `lib/config.sh`
- Create: `tests/test_config.sh`

**Step 1: Write the tests**

Create `tests/test_config.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"
source "$PROJECT_ROOT/lib/config.sh"

echo "=== lib/config.sh ==="

# --- defaults when no config file ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

unset WT_BASE_BRANCH WT_BASE_PATH 2>/dev/null || true
wt_load_config "$REPO_DIR"
assert_eq "default base path" ".worktrees" "$WT_BASE_PATH"

cleanup_test_repo "$REPO_DIR"

# --- config file values ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

mkdir -p .worktrees
cat > .worktrees/config <<'CONF'
WT_BASE_BRANCH=develop
WT_BASE_PATH=.wt
CONF

unset WT_BASE_BRANCH WT_BASE_PATH 2>/dev/null || true
wt_load_config "$REPO_DIR"
assert_eq "config file base branch" "develop" "$WT_BASE_BRANCH"
assert_eq "config file base path" ".wt" "$WT_BASE_PATH"

cleanup_test_repo "$REPO_DIR"

# --- env vars override config file ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

mkdir -p .worktrees
cat > .worktrees/config <<'CONF'
WT_BASE_BRANCH=develop
CONF

export WT_BASE_BRANCH=release
wt_load_config "$REPO_DIR"
assert_eq "env overrides config file" "release" "$WT_BASE_BRANCH"
unset WT_BASE_BRANCH

cleanup_test_repo "$REPO_DIR"

test_summary
```

**Step 2: Run tests — verify they fail**

Run: `bash tests/test_config.sh`
Expected: fails.

**Step 3: Implement lib/config.sh**

Create `lib/config.sh`:

```bash
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
```

**Step 4: Run tests — verify they pass**

Run: `bash tests/test_config.sh`
Expected: all PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add config loading library"
```

---

### Task 4: lib/hooks.sh — hook execution

**Files:**
- Create: `lib/hooks.sh`
- Create: `tests/test_hooks.sh`

**Step 1: Write the tests**

Create `tests/test_hooks.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"
source "$PROJECT_ROOT/lib/hooks.sh"

echo "=== lib/hooks.sh ==="

# --- runs hooks in lexicographic order ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

HOOK_DIR="$REPO_DIR/.worktrees/hooks/create"
mkdir -p "$HOOK_DIR"

cat > "$HOOK_DIR/02-second" <<'HOOK'
#!/usr/bin/env bash
echo "second" >> "$1/.hook-log"
HOOK
chmod +x "$HOOK_DIR/02-second"

cat > "$HOOK_DIR/01-first" <<'HOOK'
#!/usr/bin/env bash
echo "first" >> "$1/.hook-log"
HOOK
chmod +x "$HOOK_DIR/01-first"

TARGET="$REPO_DIR/.worktrees/test-wt"
mkdir -p "$TARGET"

wt_run_hooks "$HOOK_DIR" "$TARGET" 2>/dev/null
assert_file_exists "hook log created" "$TARGET/.hook-log"

first_line="$(head -1 "$TARGET/.hook-log")"
assert_eq "first hook ran first" "first" "$first_line"

second_line="$(tail -1 "$TARGET/.hook-log")"
assert_eq "second hook ran second" "second" "$second_line"

cleanup_test_repo "$REPO_DIR"

# --- warns on hook failure but continues ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

HOOK_DIR="$REPO_DIR/.worktrees/hooks/create"
mkdir -p "$HOOK_DIR"

cat > "$HOOK_DIR/01-fail" <<'HOOK'
#!/usr/bin/env bash
exit 1
HOOK
chmod +x "$HOOK_DIR/01-fail"

cat > "$HOOK_DIR/02-succeed" <<'HOOK'
#!/usr/bin/env bash
echo "ran" >> "$1/.hook-log"
HOOK
chmod +x "$HOOK_DIR/02-succeed"

TARGET="$REPO_DIR/.worktrees/test-wt"
mkdir -p "$TARGET"

stderr="$(wt_run_hooks "$HOOK_DIR" "$TARGET" 2>&1)"
assert_contains "warning printed for failed hook" "$stderr" "warning"
assert_file_exists "second hook still ran" "$TARGET/.hook-log"

cleanup_test_repo "$REPO_DIR"

# --- no hooks dir is a no-op ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

wt_run_hooks "$REPO_DIR/.worktrees/hooks/create" "$REPO_DIR" 2>/dev/null
assert_exit_code "missing hook dir is ok" "0" "$?"

cleanup_test_repo "$REPO_DIR"

test_summary
```

**Step 2: Run tests — verify they fail**

Run: `bash tests/test_hooks.sh`
Expected: fails.

**Step 3: Implement lib/hooks.sh**

Create `lib/hooks.sh`:

```bash
#!/usr/bin/env bash

wt_run_hooks() {
    local hook_dir="$1"
    local worktree_path="$2"

    [ -d "$hook_dir" ] || return 0

    local hooks=()
    while IFS= read -r -d '' hook; do
        hooks+=("$hook")
    done < <(find "$hook_dir" -maxdepth 1 -type f -executable -print0 | sort -z)

    for hook in "${hooks[@]}"; do
        local hook_name
        hook_name="$(basename "$hook")"
        echo "wt: running hook '$hook_name'" >&2
        if ! "$hook" "$worktree_path"; then
            echo "wt: warning: hook '$hook_name' exited with non-zero status" >&2
        fi
    done
}
```

**Step 4: Run tests — verify they pass**

Run: `bash tests/test_hooks.sh`
Expected: all PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add hook execution library"
```

---

### Task 5: commands/cd.sh — the core command

**Files:**
- Create: `commands/cd.sh`
- Create: `tests/test_cd.sh`

**Step 1: Write the tests**

Create `tests/test_cd.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

echo "=== commands/cd.sh ==="

# --- creates a new worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

stdout="$(bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "test-feature" "" 2>/dev/null)"
assert_dir_exists "worktree directory created" "$REPO_DIR/.worktrees/test-feature"
assert_eq "prints worktree path" "$REPO_DIR/.worktrees/test-feature" "$stdout"

branch_exists="$(git branch --list test-feature)"
assert_contains "branch created" "$branch_exists" "test-feature"

cleanup_test_repo "$REPO_DIR"

# --- switches to existing worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "existing-wt" "" >/dev/null 2>&1

stdout="$(bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "existing-wt" "" 2>/dev/null)"
assert_eq "prints path for existing worktree" "$REPO_DIR/.worktrees/existing-wt" "$stdout"

cleanup_test_repo "$REPO_DIR"

# --- respects --from flag ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

git checkout -b develop >/dev/null 2>&1
git commit --allow-empty -m "develop commit" >/dev/null 2>&1
git checkout main >/dev/null 2>&1

bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "from-develop" "develop" >/dev/null 2>&1

cd "$REPO_DIR/.worktrees/from-develop"
parent_log="$(git log --oneline -1)"
assert_contains "based on develop" "$parent_log" "develop commit"

cleanup_test_repo "$REPO_DIR"

# --- runs create hooks on new worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

mkdir -p .worktrees/hooks/create
cat > .worktrees/hooks/create/01-marker <<'HOOK'
#!/usr/bin/env bash
touch "$1/.created-marker"
HOOK
chmod +x .worktrees/hooks/create/01-marker

bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "hooked-wt" "" >/dev/null 2>&1

assert_file_exists "create hook ran" "$REPO_DIR/.worktrees/hooked-wt/.created-marker"

cleanup_test_repo "$REPO_DIR"

# --- runs switch hooks on existing worktree ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "switch-test" "" >/dev/null 2>&1

mkdir -p .worktrees/hooks/switch
cat > .worktrees/hooks/switch/01-marker <<'HOOK'
#!/usr/bin/env bash
touch "$1/.switched-marker"
HOOK
chmod +x .worktrees/hooks/switch/01-marker

bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "switch-test" "" >/dev/null 2>&1

assert_file_exists "switch hook ran" "$REPO_DIR/.worktrees/switch-test/.switched-marker"

cleanup_test_repo "$REPO_DIR"

# --- uses existing branch without -b ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

git branch existing-branch >/dev/null 2>&1

stdout="$(bash "$PROJECT_ROOT/commands/cd.sh" "$REPO_DIR" "existing-branch" "" 2>/dev/null)"
assert_dir_exists "worktree from existing branch" "$REPO_DIR/.worktrees/existing-branch"

cleanup_test_repo "$REPO_DIR"

test_summary
```

**Step 2: Run tests — verify they fail**

Run: `bash tests/test_cd.sh`
Expected: fails.

**Step 3: Implement commands/cd.sh**

Create `commands/cd.sh`. This script receives args from `bin/wt` and is sourced or called with the repo root, name, and optional from-branch:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

source "$LIB_DIR/git.sh"
source "$LIB_DIR/config.sh"
source "$LIB_DIR/hooks.sh"

wt_cd() {
    local repo_root="$1"
    local name="$2"
    local from_branch="${3:-}"

    wt_load_config "$repo_root"

    local base_path="$repo_root/$WT_BASE_PATH"
    local worktree_path="$base_path/$name"

    if [ -d "$worktree_path" ]; then
        echo "wt: switching to '$name'" >&2
        local switch_hooks="$base_path/hooks/switch"
        wt_run_hooks "$switch_hooks" "$worktree_path"
        echo "$worktree_path"
        return 0
    fi

    mkdir -p "$base_path"

    if [ -z "$from_branch" ]; then
        if [ -n "${WT_BASE_BRANCH:-}" ]; then
            from_branch="$WT_BASE_BRANCH"
        else
            from_branch="$(wt_git_main_branch)"
        fi
    fi

    echo "wt: creating worktree '$name' from '$from_branch'" >&2

    if git show-ref --verify --quiet "refs/heads/$name"; then
        git worktree add "$worktree_path" "$name" >/dev/null 2>&1
    else
        git worktree add -b "$name" "$worktree_path" "$from_branch" >/dev/null 2>&1
    fi

    local create_hooks="$base_path/hooks/create"
    wt_run_hooks "$create_hooks" "$worktree_path"

    echo "$worktree_path"
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    wt_cd "$@"
fi
```

**Step 4: Run tests — verify they pass**

Run: `bash tests/test_cd.sh`
Expected: all PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: implement cd (create-or-switch) command"
```

---

### Task 6: bin/wt — entry point with dispatch

**Files:**
- Modify: `bin/wt`
- Create: `tests/test_wt.sh`

**Step 1: Write the tests**

Create `tests/test_wt.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/helpers.sh"

WT_BIN="$PROJECT_ROOT/bin/wt"

echo "=== bin/wt ==="

# --- no args shows usage ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

stderr="$("$WT_BIN" 2>&1 || true)"
assert_contains "usage message when no args" "$stderr" "usage"

cleanup_test_repo "$REPO_DIR"

# --- wt <name> creates and outputs path ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

stdout="$("$WT_BIN" dispatch-test 2>/dev/null)"
assert_eq "dispatches to cd" "$REPO_DIR/.worktrees/dispatch-test" "$stdout"
assert_dir_exists "worktree created via dispatch" "$REPO_DIR/.worktrees/dispatch-test"

cleanup_test_repo "$REPO_DIR"

# --- wt cd <name> also works ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

stdout="$("$WT_BIN" cd explicit-test 2>/dev/null)"
assert_eq "explicit cd subcommand" "$REPO_DIR/.worktrees/explicit-test" "$stdout"

cleanup_test_repo "$REPO_DIR"

# --- wt <name> --from <branch> ---

REPO_DIR="$(setup_test_repo)"
cd "$REPO_DIR"

git checkout -b develop >/dev/null 2>&1
git commit --allow-empty -m "on develop" >/dev/null 2>&1
git checkout main >/dev/null 2>&1

stdout="$("$WT_BIN" from-test --from develop 2>/dev/null)"
assert_eq "from flag works via dispatch" "$REPO_DIR/.worktrees/from-test" "$stdout"

cleanup_test_repo "$REPO_DIR"

# --- not in a git repo ---

TMPDIR_NOGIT="$(mktemp -d)"
cd "$TMPDIR_NOGIT"

stderr="$("$WT_BIN" anything 2>&1 || true)"
assert_contains "error outside git repo" "$stderr" "not a git repository"

rm -rf "$TMPDIR_NOGIT"

test_summary
```

**Step 2: Run tests — verify they fail**

Run: `bash tests/test_wt.sh`
Expected: fails (bin/wt is a placeholder).

**Step 3: Implement bin/wt**

Replace `bin/wt`:

```bash
#!/usr/bin/env bash
set -euo pipefail

WT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMANDS_DIR="$WT_ROOT/commands"
LIB_DIR="$WT_ROOT/lib"

source "$LIB_DIR/git.sh"

usage() {
    echo "usage: wt <name> [--from <branch>]" >&2
    echo "       wt cd <name> [--from <branch>]" >&2
    exit 1
}

[ $# -lt 1 ] && usage

REPO_ROOT="$(wt_git_repo_root 2>/dev/null)" || {
    echo "wt: not a git repository" >&2
    exit 1
}

cmd="$1"
shift

case "$cmd" in
    cd)
        [ $# -lt 1 ] && usage
        name="$1"; shift
        from_branch=""
        while [ $# -gt 0 ]; do
            case "$1" in
                --from) from_branch="${2:-}"; shift 2 ;;
                *) echo "wt: unknown option '$1'" >&2; exit 1 ;;
            esac
        done
        exec bash "$COMMANDS_DIR/cd.sh" "$REPO_ROOT" "$name" "$from_branch"
        ;;
    -h|--help)
        usage
        ;;
    *)
        name="$cmd"
        from_branch=""
        while [ $# -gt 0 ]; do
            case "$1" in
                --from) from_branch="${2:-}"; shift 2 ;;
                *) echo "wt: unknown option '$1'" >&2; exit 1 ;;
            esac
        done
        exec bash "$COMMANDS_DIR/cd.sh" "$REPO_ROOT" "$name" "$from_branch"
        ;;
esac
```

**Step 4: Run tests — verify they pass**

Run: `bash tests/test_wt.sh`
Expected: all PASS.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: implement entry point with subcommand dispatch"
```

---

### Task 7: Shell wrappers

**Files:**
- Create: `shell/wt.bash`
- Create: `shell/wt.zsh`

**Step 1: Create shell/wt.bash**

```bash
#!/usr/bin/env bash
# Source this file in .bashrc:
#   source /path/to/wt/shell/wt.bash
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
```

**Step 2: Create shell/wt.zsh**

```zsh
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
```

**Step 3: Manual verification**

Open a new shell, then:

```bash
export PATH="/path/to/wt/bin:$PATH"
source /path/to/wt/shell/wt.bash  # or wt.zsh

cd /some/git/repo
wt test-manual
pwd  # should be inside .worktrees/test-manual
```

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add bash and zsh shell integration"
```

---

### Task 8: Run all tests + README

**Files:**
- Create: `tests/run_all.sh`
- Create: `README.md`

**Step 1: Create test runner**

Create `tests/run_all.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
failed=0

for test_file in "$SCRIPT_DIR"/test_*.sh; do
    echo ""
    echo "--- $(basename "$test_file") ---"
    if ! bash "$test_file"; then
        failed=1
    fi
done

echo ""
if [ "$failed" -eq 1 ]; then
    echo "SOME TESTS FAILED"
    exit 1
else
    echo "ALL TESTS PASSED"
fi
```

```bash
chmod +x tests/run_all.sh
```

**Step 2: Run all tests**

Run: `bash tests/run_all.sh`
Expected: all pass.

**Step 3: Create README**

Create `README.md`:

```markdown
# wt — git worktree manager

One command to create or switch to git worktrees.

## Install

Add to your shell rc file (`.bashrc` or `.zshrc`):

```bash
export PATH="/path/to/wt/bin:$PATH"
source /path/to/wt/shell/wt.bash  # or wt.zsh
```

## Usage

```bash
wt <name>                  # create or switch to worktree
wt <name> --from develop   # create from specific branch
wt cd <name>               # explicit form (same behavior)
```

Worktrees are created in `.worktrees/<name>` inside your repo.

## Hooks

Place executable scripts in `.worktrees/hooks/create/` or `.worktrees/hooks/switch/`.
They run in lexicographic order and receive the worktree path as `$1`.

## Config

Optional `.worktrees/config` file:

```
WT_BASE_BRANCH=main
WT_BASE_PATH=.worktrees
```

Environment variables override config file values.

## Tests

```bash
bash tests/run_all.sh
```
```

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: add test runner and README"
```
