# wt status — Design

## Command

`wt status` — lists all worktrees grouped by lifecycle stage.

## Buckets

1. **In Progress** — default bucket. No PR, draft PR, or anything not in the other two.
2. **In Review** — open (non-draft) PR exists. Shows CI status and review state.
3. **Done** — PR merged, worktree clean, no unpushed commits. Safe to delete.

## Per-worktree info

- Branch name
- Dirty/clean indicator (● dirty, ✓ clean)
- Last commit age (relative: "2h ago", "3d ago")
- PR title (if exists)
- CI status (✓ pass, ✗ fail, ◌ pending)
- Review status (✓ approved, ✗ changes requested, ◌ pending review)

## Data flow

1. List directories in `.worktrees/` (skip `hooks/`, `config`)
2. For each worktree: git status (dirty/clean), last commit time, branch name
3. One `gh pr list` call with JSON output to get all PRs (open + merged) for the repo
4. Match PRs to worktree branches by head branch name
5. For matched PRs: extract state, CI status via `gh pr checks`, review decision
6. Sort into buckets, render with colors

## GitHub integration

Single batch query:
```
gh pr list --state all --json headRefName,title,state,statusCheckRollup,reviewDecision --limit 100
```

Fields:
- `headRefName` — match to worktree branch
- `title` — PR title
- `state` — OPEN / MERGED / CLOSED
- `statusCheckRollup` — array of check statuses
- `reviewDecision` — APPROVED / CHANGES_REQUESTED / REVIEW_REQUIRED / empty

## Color scheme

- Green: clean, passing, approved, done bucket header
- Yellow: pending, in-progress bucket header, draft
- Red: dirty, failing, changes requested

## Files

```
commands/status.sh          # main status command
lib/github.sh               # gh CLI wrapper (PR data fetching)
lib/format.sh               # color/formatting helpers
tests/test_status.sh        # tests (mock gh output)
```

## Error handling

- `gh` not installed → skip GitHub info, show local-only status with note
- `gh` not authenticated → same
- No remote → same
- No worktrees → "no worktrees" message
