# wt — Project Brief

## What this is

A bash CLI tool for managing git worktrees. One command creates a worktree and branch, runs setup hooks, and drops you in. A status dashboard shows all worktrees grouped by lifecycle stage (in progress, in review, done) with GitHub PR/CI integration. It replaces the manual `git worktree add` / setup / context-switching dance.

## Essential workflow

Name → create-or-switch → hook → work → check status → clean up.

## Current state

- `wt <name>` creates-or-switches (single entry point)
- `wt rm <name>` removes worktree + branch with safety checks
- `wt exit` returns to main repo root
- `.worktrees/hooks/create/` and `.worktrees/hooks/switch/` for setup automation
- Shell integration (bash/zsh) so cd works
- Configurable base path and default branch

## What's next

- `wt status` — dashboard of all worktrees grouped into In Progress / In Review / Done
- GitHub integration via `gh` CLI for PR status, CI checks, review state
- Colored output for status command

## What isn't the core

- Linear ticket integration — later
- Cursor auto-open — later (user can alias)
- Tab completion — later
- Performance, parallel hook execution — not needed

## How to verify

Core: `wt test-abc` creates worktree + branch, runs hooks, cds in. `wt test-abc` again just switches. `wt rm test-abc` cleans up.

Status: `wt status` in a repo with multiple worktrees shows them grouped by lifecycle with correct PR/CI/review info from GitHub.
