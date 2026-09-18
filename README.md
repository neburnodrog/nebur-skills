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

Shipping

| Skill | Does |
|---|---|
| `go` | Test the project, simplify the changed code, open a PR. |
| `ship` | Branch name plus a task description in, clean commits and a pushed branch out. |
| `hate-me` | Reviews your diff as a senior dev who hates the implementation. |
| `diagnose` | Reproduce, minimise, hypothesise, instrument, fix, regression-test. |

Writing

| Skill | Does |
|---|---|
| `unslop` | Cuts AI tells from any writing. 25-rule editing pass. |
| `unslop-de` | The German delta on top of `unslop`. |
| `trim-comments` | Drops the paraphrase comments a branch added, keeps the load-bearing ones. |
| `comment-cleanup` | Strips a file set's comments, restores only what a cold reader asks for. |
| `caveman` | Ultra-compressed replies. Roughly 75% fewer tokens, same technical content. |

Repo hygiene

| Skill | Does |
|---|---|
| `clean-branches` | Deletes merged branches and stale worktrees, on proof that the content already landed. |
| `dependabot-manager` | Triages every open Dependabot PR: merges the safe, flags the dubious, blocks the rest. |
| `improve-module-architecture` | Finds deepening opportunities in one module or slice. |

Planning

| Skill | Does |
|---|---|
| `to-prd` | Turns the conversation into a PRD on the issue tracker. |
| `to-issues` | Splits a plan into independently grabbable issues as vertical slices. |
| `request-refactor-plan` | Interviews you, then files a refactor plan of tiny commits as an issue. |

Setup

| Skill | Does |
|---|---|
| `new-personal-web-project` | Scaffolds a personal web project: GitHub repo, Vercel, Next.js or Vite. |
| `personal-clone` | Mirrors the current repo to a private repo on your account. |
| `write-a-skill` | Writes a new skill with progressive disclosure and bundled resources. |
| `nebur-audit` | Scores a Claude Code config and finds instructions that cannot fire. |
| `find-skills` | Finds and installs skills that do what you are asking for. |
| `context7-mcp` | Pulls current library docs through Context7 instead of guessing from training data. |
| `allhands` | Builds a monthly all-hands summary from your own git activity. |

## Before you install

Some skills assume my setup and will need editing for yours:

- `allhands` writes into an Obsidian vault at `~/vault` and can push to Notion.
- `personal-clone` and `new-personal-web-project` use the `gh` and `vercel` CLIs, already authenticated.
- `to-prd` and `to-issues` expect a GitHub issue tracker.
- `nebur-audit` reads `~/.claude`.

Four skills call skills that are not in this repo: `go` calls `/simplify`, `nebur-audit` calls `/skill-doctor` (both built into Claude Code), and `diagnose` and `improve-module-architecture` point at `/improve-codebase-architecture`, which is not published here. They degrade to doing that step inline.

## Testing

`clean-branches` ships a test that builds a throwaway repo with a real remote and asserts every verdict:

```
bash skills/clean-branches/test.sh
```

## Licence

MIT.
