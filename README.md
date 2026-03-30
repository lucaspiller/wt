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
