---
name: clean-branches
description: Deletes local git branches and worktrees. Load ONLY when the user invokes it by name, as /clean-branches or "run clean-branches". Never load it because branch cleanup came up, because a repo looks untidy, or as a step inside another task, however well it would fit.
---

# Clean branches

`clean-branches.sh`, next to this file, does the assessment and the work. Run it with the repo as the working directory, using this skill's base directory for the script path.

```bash
bash <skill-dir>/clean-branches.sh          # assess and print the plan
bash <skill-dir>/clean-branches.sh --apply  # carry the plan out
```

Plan mode touches no branch, worktree or file. It does run `git fetch --all --prune`, which drops remote-tracking refs for branches already deleted on the remote. Without that every merge check reads a stale ref.

## Steps

1. Run without flags. It fetches, prunes remote refs, and prints one line per branch and per worktree.
2. On `ERROR`, stop and relay it. `DIRTY yes` means the user commits or stashes first; never work around it.
3. Relay the plan and the `PLAN` count. Wait for the user to say go.
4. Run with `--apply`, then relay the result lines and the `DONE` count.

## Reading the output

```
WT  <verb> <path>   <branch> <reasons>
BR  <verb> <branch> <reasons>
```

Verbs are `remove`/`removed`, `prune`/`pruned`, `delete`/`deleted`, `ff`, `keep`. Reasons that carry a decision:

| Reason | Meaning |
|---|---|
| `merged:ancestor` | Branch tip is already in the default branch. |
| `merged:squash` | Different sha, identical tree. Squash-merged, so `git branch -d` would refuse it. |
| `no-proof` | Content is not in the default branch. Kept. Proof is only ever checked against the remote default branch, so work merged into `develop` or a release branch reads as `no-proof`. |
| `uncommitted` / `unpushed` | Worktree holds real work. Kept. |
| `ignored-files:N` | Worktree holds N gitignored paths, such as `.env` or a local database. `git worktree remove` would delete them, so the worktree is kept. Remove it by hand once you have moved them. |
| `was:<sha>` | The tip the branch had when it was deleted. `git branch <name> <sha>` puts it back. |
| `diverged +N/-M` | Local commits to push, or a rebase to run. Say so; the script will not touch it. |
| `delete-failed` / `ff-failed` / `remove-failed` | Git refused. Surface it, do not retry with force. |

Everything is accounted for under exactly one verb, so the output is the report. Add prose only for `ERROR`, `diverged`, or a `*-failed` line.

The script documents its own safety rules in its header: what proof means, and which branches are protected whatever the proof says. Read it when the user asks why something was kept, or wants the policy changed.
