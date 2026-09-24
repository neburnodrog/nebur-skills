# nebur-skills

Claude Code skills I use daily, packaged as a plugin so they install on any machine without dragging my settings along.

## Install

```
/plugin marketplace add neburnodrog/nebur-skills
/plugin install nebur-skills@nebur-skills
```

Restart Claude Code. Type `/` to see the skills, or let Claude reach for them itself.

To update: `/plugin update nebur-skills`.

## What is in here

Code and repo hygiene

| Skill | Does |
|---|---|
| `clean-branches` | Deletes merged branches and stale worktrees, on proof that the content already landed. |
| `dependabot-manager` | Triages every open Dependabot PR: merges the safe, flags the dubious, blocks the rest. |
| `hate-me` | Reviews your diff as a senior dev who hates the implementation. |
| `trim-comments` | Drops the paraphrase comments a branch added, keeps the load-bearing ones. |
| `comment-cleanup` | Strips a file set's comments, restores only what a cold reader asks for. |
| `improve-module-architecture` | Finds deepening opportunities in one module or slice. |

Setup and config

| Skill | Does |
|---|---|
| `new-personal-web-project` | Scaffolds a personal web project: GitHub repo, Vercel, Next.js or Vite. |
| `personal-clone` | Mirrors the current repo to a private repo on your account. |
| `nebur-audit` | Scores a Claude Code config and finds instructions that cannot fire. |
| `allhands` | Builds a monthly all-hands summary from your own git activity. |

## Before you install

Some skills assume my setup and will need editing for yours:

- `allhands` writes into an Obsidian vault at `~/vault` and can push to Notion.
- `personal-clone` and `new-personal-web-project` use the `gh` and `vercel` CLIs, already authenticated.
- `nebur-audit` reads `~/.claude`.

Two skills call skills that are not in this repo. `nebur-audit` calls `/skill-doctor`, which is built into Claude Code, and `improve-module-architecture` points at `/improve-codebase-architecture`. Both degrade to doing the step inline.

## Testing

`clean-branches` ships a test that builds a throwaway repo with a real remote and asserts every verdict:

```
bash skills/clean-branches/test.sh
```

## Working on these skills

See [CONTRIBUTING.md](CONTRIBUTING.md) for how the two repos fit together, when a version bump is needed, and why the cache is never the thing to edit.

## Licence

MIT.
