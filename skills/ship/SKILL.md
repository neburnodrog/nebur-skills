---
name: ship
description: Use when the user wants to ship a discrete piece of work end-to-end in one command and supplies a branch name plus a task description. Triggers include "/ship <branch> <task>", "ship this on a branch", "do X on a worktree and push it", or any request that bundles "make a branch", "do the work", "commit it cleanly", "push", and "clean up" into a single ask. Use even when the task description is short — this skill owns the orchestration so the user doesn't have to drive each step.
---

# Ship — Worktree, Work, Verify, Commit, Push, Clean

You are an orchestrator. The user hands you a **branch name** and a **task description**. Your job is to take that from "nothing started" to "branch pushed and local worktree gone" without coming back for each step.

## Arguments

This skill expects two arguments parsed from the user's invocation:

| Arg | Meaning | Example |
|-----|---------|---------|
| `<branch>` | Name of the new branch to create | `feat/login-rate-limit` |
| `<task>` | Free-form description of the work to perform | `"add rate limiting to /login, 5 req/min per IP"` |

If either is missing, ask once with `AskUserQuestion`, then proceed.

**Branch naming:** if the user's branch name lacks a conventional prefix (`feat/`, `fix/`, `chore/`, `refactor/`, `docs/`, `test/`), infer one from the task and prepend it. Don't rename what the user explicitly chose.

## Phase 0: Sanity Checks (parallel)

Run these together — they must all succeed before you create a worktree:

```bash
git rev-parse --show-toplevel              # in a repo?
git symbolic-ref --short HEAD              # what branch are we on
git status --porcelain                     # clean tree?
git remote get-url origin 2>/dev/null      # remote exists?
git branch --list <branch>                 # branch already exists locally?
git ls-remote --heads origin <branch>      # branch already exists on remote?
```

**Stop and ask** if:
- Working tree is dirty (offer: stash, commit-first, or abort)
- Branch already exists locally or remotely (offer: pick new name, reuse, or abort)
- No `origin` remote (push step will fail — confirm we should still proceed)

Pick the base branch with: `git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'` (falls back to `main` if unset).

## Phase 1: Create the Worktree

Use the dedicated skill — don't reinvent the wheel:

**REQUIRED SUB-SKILL:** Use `superpowers:using-git-worktrees` to set up the isolated workspace. If that skill is unavailable, fall back to:

```bash
git fetch origin
git worktree add -b <branch> ../worktrees/<branch> origin/<base-branch>
cd ../worktrees/<branch>
```

Record the worktree path — you'll need it for cleanup. From here on, **every subsequent command runs inside the worktree directory**. Never `cd` back to the original checkout until cleanup.

## Phase 2: Execute the Work

Read the task description carefully and execute it. This is where domain skills take over:

- New feature → consider `superpowers:brainstorming` first if scope is unclear, then `superpowers:test-driven-development`
- Bug fix → `superpowers:systematic-debugging` before touching code
- UI work → `frontend-design:frontend-design`, `web-design-guidelines`
- Refactor → `improve-module-architecture` or `simplify`
- Anything ambiguous → pause, `AskUserQuestion`, then continue

While working, group changes mentally into **logical commit chunks** as you go. Don't write one giant commit at the end. Examples of natural chunk boundaries:

- "schema change" vs. "code that uses the new schema"
- "test scaffolding" vs. "feature implementation"
- "refactor of existing function" vs. "new behavior added on top"
- "fix" vs. "tests proving the fix"

Take notes (mentally or in TodoWrite) of what files belong to which chunk.

## Phase 3: Verify — Typecheck and Lint

Before any commit, the code must typecheck and lint clean. Detect the commands from the project:

```bash
# Node/TS projects
cat package.json | grep -E '"(typecheck|lint|check)"' 2>/dev/null

# Rust
ls Cargo.toml 2>/dev/null && echo "cargo check && cargo clippy"

# Python
ls pyproject.toml 2>/dev/null && grep -E '(ruff|mypy|pyright)' pyproject.toml

# Go
ls go.mod 2>/dev/null && echo "go vet ./... && golangci-lint run"
```

Common script names to try (in order): `typecheck`, `tsc`, `check-types`, `lint`, `check`. For monorepos, prefer the workspace-level script (`pnpm -w typecheck`, `turbo run typecheck`, etc.).

**Run typecheck and lint in parallel** when they're independent commands.

If either fails:
1. **Fix the root cause** — never `// @ts-ignore` or `eslint-disable` to make red go green.
2. Re-run until both pass.
3. If a failure is pre-existing (unrelated to your changes), confirm with the user before proceeding — don't quietly carry someone else's debt into your PR.

## Phase 4: Commit in Logical Chunks

For each chunk identified in Phase 2:

1. Stage only the files belonging to that chunk: `git add <specific files>`. **Never** `git add -A` or `git add .` here — that defeats the chunking.
2. Verify what's staged: `git diff --cached --stat`.
3. Write a conventional commit:

   ```
   <type>(<optional scope>): <imperative summary, ≤72 chars>

   <body explaining WHY, wrapped at ~72 chars. Skip if the
   summary is fully self-explanatory.>
   ```

   Types: `feat`, `fix`, `refactor`, `perf`, `test`, `docs`, `chore`, `style`, `build`, `ci`.

4. Commit using a HEREDOC so multi-line bodies format correctly:

   ```bash
   git commit -m "$(cat <<'EOF'
   feat(auth): rate-limit /login to 5 req/min per IP

   Mitigates credential-stuffing attacks reported in INC-482.
   Uses the existing Redis-backed limiter; no new infra.

   Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
   EOF
   )"
   ```

5. Verify: `git log -1 --stat`, then move to the next chunk.

**Rules:**
- One concern per commit. If you're writing "and" in the subject, split it.
- Tests for a feature go in the same commit as the feature (they prove the feature works). Tests for an existing bug fix go in the same commit as the fix.
- Never amend a previous commit unless the user explicitly asked — create a new one.
- Never use `--no-verify`. If a pre-commit hook fails, fix the underlying issue and make a new commit.

## Phase 5: Push

```bash
git push -u origin <branch>
```

If the push is rejected (rare on a fresh branch, but possible for naming collisions or hook failures), surface the exact error — do **not** retry with `--force`.

## Phase 6: Clean Up the Worktree

Return to the original checkout, then tear down:

```bash
cd <original repo path>
git worktree remove ../worktrees/<branch>
git worktree prune
```

If `git worktree remove` complains about uncommitted changes (shouldn't happen at this point, but defend against it), inspect first — never pass `--force` without confirming the dirty files are intentional cruft.

Leave the local branch ref alone unless the user asked otherwise — they may want to inspect it. (See `clean-branches` skill if they ask to also delete the local branch.)

## Phase 7: Report

End with a single concise summary the user can act on:

```
Shipped <branch>:
  • <N> commits pushed to origin/<branch>
  • Typecheck: ✓   Lint: ✓
  • Worktree removed
  → Open PR: gh pr create --base <base> --head <branch>
```

If anything was skipped (no remote, pre-existing lint failure carried over, etc.), call it out in the report — don't bury it.

## Quick Reference

| Phase | One-liner |
|-------|-----------|
| 0 | Sanity-check repo state |
| 1 | `git worktree add -b <branch> ../worktrees/<branch> origin/<base>` |
| 2 | Do the work; track logical chunks |
| 3 | Typecheck + lint (parallel); fix root causes |
| 4 | Per chunk: stage → conventional commit |
| 5 | `git push -u origin <branch>` |
| 6 | `git worktree remove …` + `git worktree prune` |
| 7 | Summarize, suggest `gh pr create` |

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| One giant commit at the end | Group as you work; commit per logical chunk |
| `git add -A` inside the chunking loop | Stage only the files for that chunk |
| Suppressing lint/type errors to ship | Fix the root cause; suppression is a code smell |
| Forgetting to `cd` into the worktree before working | Phase 1 ends with `cd`; stay there until Phase 6 |
| Leaving the worktree behind after push | Phase 6 is mandatory — always prune |
| Using `--force` to recover from a push reject | Stop and diagnose; force-push is destructive |
| Amending instead of new commit on hook failure | Pre-commit failure means the commit didn't happen — make a new one |

## Red Flags — Stop and Reconsider

- About to run any command outside the worktree before Phase 6
- About to `git commit -am` (skips chunking)
- About to suppress a type/lint error to make it pass
- About to push to `main` or a protected branch
- About to delete the worktree before the push succeeded

Any of these = pause, confirm with the user, then proceed.

## Cross-References

- `superpowers:using-git-worktrees` — worktree creation details
- `superpowers:finishing-a-development-branch` — alternative integration paths (merge vs. PR vs. cleanup-only)
- `superpowers:verification-before-completion` — never claim "shipped" without evidence
- `clean-branches` — for tidying local branches after the PR merges
