# wt — Project Brief

## What this is

A bash CLI tool that gives you a single command — `wt <name>` — to create or switch to git worktrees. If the worktree exists, it cds into it. If not, it creates the branch and worktree in a sibling directory, runs post-create hooks (e.g. copying personal Cursor skills, installing deps), then cds in. It replaces the multi-step `git worktree add` / `cd` / manual-setup dance with one command.

## Essential workflow

Name → create-or-switch → hook → work.

## First usable version

- `wt <name>` that creates-or-switches (single entry point)
- Sibling directory layout with configurable base path (default `.worktrees`)
- Branch created from current HEAD when worktree doesn't exist
- `.worktrees/hooks/` directory
- Shell integration (bash/zsh function) so `cd` actually works
- Installable via PATH or symlink for development

## Good enough for now

- Config is env vars or a dotfile, not a full config system (in base path, e.g. `.worktrees/config`)
- No tab completion
- No color/fancy output — just clear status messages
- Hook errors print warnings but don't block
- No cleanup/delete command yet

## What isn't the core

- GitHub integration (CI status, PR checks) — later
- Linear ticket integration — later
- `wt list` / dashboard of active worktrees — later
- `wt delete` / garbage collection — later
- Cursor auto-open — later (user can alias)
- Performance, parallel hook execution — not needed

## How to verify

From a git repo, run `wt test-abc`. Verify: sibling directory exists, branch `test-abc` exists, hooks in `hooks/` ran (create a hook that touches a marker file), shell is now in the new worktree directory. Run `wt test-abc` again — verify it just cds into the existing worktree without re-running hooks or re-creating anything.
