# wt — git worktree manager

A thin wrapper around `git worktree` that makes parallel development branches effortless. One command creates a worktree and branch, runs setup hooks, and drops you in. One command cleans it up when you're done.

Why: `git worktree add` requires choosing a path, creating a branch, then manually copying env files, installing deps, and cd'ing in. Multiply that by 5 branches in flight and it's tedious. `wt` does all of it in one command with hooks for the repo-specific setup.

## Install

Clone the repo:

```bash
git clone https://github.com/lucaspiller/wt.git ~/.wt
```

Add to your `.zshrc` (or `.bashrc`):

```bash
export PATH="$HOME/.wt/bin:$PATH"
source ~/.wt/shell/wt.zsh  # or wt.bash
```
## Usage

Create or switch to a worktree:

```bash
wt <name>                  # create or switch to worktree
wt <name> --from develop   # create from specific branch
```

Remove a worktree:

```bash
wt rm <name>               # remove worktree + branch (safe: checks for uncommitted/unpushed)
wt rm <name> --force       # remove regardless
```

Worktrees live in `.worktrees/<name>` inside your repo. The branch name matches the worktree name.

## Hooks

Place scripts in `.worktrees/hooks/create/` or `.worktrees/hooks/switch/`. They run in lexicographic order and receive two arguments:

- `$1` — worktree path
- `$2` — main repo root

### Example hooks

**`01-copy-env`** — symlink env files and setup direnv:

```bash
#!/usr/bin/env bash
WORKTREE="$1"
REPO_ROOT="$2"

for env_file in .env .env.local; do
    if [ -f "$REPO_ROOT/$env_file" ]; then
        ln -sv "$REPO_ROOT/$env_file" "$WORKTREE"
    fi
done

if [ -f "$REPO_ROOT/.envrc" ]; then
    ln -sv "$REPO_ROOT/.envrc" "$WORKTREE"
    cd "$WORKTREE"
    direnv allow
fi
```

**`10-install-node-deps`** — switch node version and install dependencies:

```bash
#!/usr/bin/env bash
WORKTREE="$1"

if [ -f "$WORKTREE/package.json" ]; then
    cd "$WORKTREE"

    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
    nvm use

    yarn install
fi
```

## Config

Optional `.worktrees/config` file:

```
WT_BASE_BRANCH=main
WT_BASE_PATH=.worktrees
```

Environment variables override config file values. The default branch is auto-detected from `origin/HEAD`, falling back to `main`/`master`/`dev`/`develop`.

## Tests

```bash
bash tests/run_all.sh
```
