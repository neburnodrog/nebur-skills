# Audit Passes

<!-- Verified against Claude Code 2.1.269 binary on 2026-09-12. -->
<!-- Constants confirmed in-binary: memory discovery list ["CLAUDE.md","CLAUDE.local.md"]; MEMORY.md limits 200 lines / 25000 bytes. -->

> Read by nebur-audit at Step 3.

## What loads, and when

Inert findings depend on this, so establish it before classifying anything.

| Scope | Location | Loads |
|---|---|---|
| Managed policy | `/Library/Application Support/ClaudeCode/CLAUDE.md` (macOS), `/etc/claude-code/CLAUDE.md` (Linux/WSL) | Every session |
| User | `~/.claude/CLAUDE.md` | Every session |
| Project | `./CLAUDE.md` or `./.claude/CLAUDE.md` | Every session |
| Local | `./CLAUDE.local.md` | Every session, appended after CLAUDE.md |
| Rules, unscoped | `.claude/rules/**/*.md` with no `paths:` | Every session |
| Rules, scoped | `.claude/rules/**/*.md` with `paths:` | When Claude reads a matching file |
| Nested | `CLAUDE.md` below the working directory | When Claude reads a file in that directory |

Files concatenate, they do not override. Claude Code walks up from the working
directory, ordering root to cwd.

Three facts that generate findings on their own:

- **Imports do not reduce context.** `@path` expands at launch alongside the file that
  references it. An over-long CLAUDE.md split into imports is the same context. Depth
  limit is four hops. Code spans and fenced blocks are skipped, so `` `@README` `` stays
  literal.
- **AGENTS.md is not read.** The discovery list in 2.1.269 is `CLAUDE.md` and
  `CLAUDE.local.md`. A repo relying on AGENTS.md alone is loading nothing. Import it with
  `@AGENTS.md`, symlink it, or run `claude import`, which migrates AGENTS.md,
  `.cursor`, `.windsurfrules`, `.clinerules` and `.gemini` into CLAUDE.md.
- **Project-root CLAUDE.md survives compaction**, re-read from disk. Nested files do not,
  and reload only on the next read in their directory.

`/context` shows what loaded. An `InstructionsLoaded` hook shows why.

## Pass 1: Inert

The instruction cannot fire. Checkable against the filesystem, so never report it as a
judgement.

| Check | Method | Finding when |
|---|---|---|
| Named path | Resolve every path an instruction mentions | It does not exist |
| `paths:` pattern | Glob it, record the count | Count is zero |
| Command | Compare against the ground-truth survey | The script or binary is absent |
| Rule file | Check it is under a loaded scope | It sits outside `.claude/rules/`, or `project` is excluded from `--setting-sources` |
| Hook script | Check the command string | It uses a bare relative path instead of `${CLAUDE_PROJECT_DIR}`, so it fails from any subdirectory |

Filename typos are the highest-yield case, because the file reads as correct. A space in
a path (`tasks/lessons .md`) resolves to nothing, and agents downstream will either
create the literal space-named file or silently skip the instruction. Both happen, in the
same repo set.

`paths:` gotchas that produce a zero count: brace groups share a budget of 1,000 expanded
patterns and 4 MiB across the rule's whole list, and a pattern over budget is used
unexpanded so its literal braces match nothing. `[` opens a bracket expression, so
`photos [2024/**` matches nothing until escaped as `photos \[2024/**`.

## Pass 2: No-op

The instruction fires and changes nothing, because the model already behaves that way.
It pays context to say nothing.

The test: would removing this line cause a mistake? This is the same gate the built-in
`/init` applies when writing a file, applied here to a file that already exists.

It is model-relative. Two people disagreeing about a no-op disagree about the default,
and the disagreement settles by running the configuration, not by argument. So flag
candidates with reasons and let the user decide.

Reliable candidates:

- Generic development advice. "Write clean code", "handle errors", "write good tests".
- Restatements of linter or formatter config. The config file is the source of truth and
  cannot go stale.
- Directory listings, dependency lists, and file-by-file structure. Claude reads the code.
- Standard language conventions the project does not deviate from.
- A convention Claude already follows in this repo without being told. Check the diff
  history before flagging.

Where the project has an eval suite, `claude plugin eval --ablation with-without` runs a
no-configuration baseline arm and reports the score delta, which converts the candidate
into a number.

## Pass 3: Trigger

A pointer names material without encoding when to reach it. The wording, not the target,
decides whether the material is ever loaded, so a weak pointer in front of a must-have
file is a variance bug.

| Weak | Carries a trigger |
|---|---|
| "See ARCHITECTURE.md for the codebase map." | "Read ARCHITECTURE.md before changing a module boundary or adding a package." |
| "Testing conventions are in `.claude/rules/testing.md`." | (scoped by `paths:` instead, so it loads on the file read) |
| A skill described as "Deployment helper." | "Use when deploying to staging or production, or when a release fails mid-rollout." |

Audit the description of every project skill the same way. It is an always-loaded pointer
and it is the only thing deciding whether the skill fires.

Front-load the leading word. Keep one trigger per distinct case, and collapse synonyms
that rename a single case.

## Pass 4: Enforcement

Guidance standing where a gate is required. CLAUDE.md is context, not configuration.
Claude reads it and tries to follow it, with no guarantee.

Anything that must hold every time belongs in a `PreToolUse` hook or a permission deny
rule. "NEVER commit to main" in CLAUDE.md is advice.

Report the routing, not just the problem:

| The instruction is… | Belongs in |
|---|---|
| A stable fact needed every session | `CLAUDE.md` |
| Relevant to some file types only | `.claude/rules/{topic}.md` with `paths:` |
| A multi-step procedure | a skill |
| Required at a fixed moment, every time | a hook |
| Something Claude worked out itself | nowhere. Auto memory holds it |

Two limits worth naming in the report. `Read` and `Edit` deny rules gate Claude's file
tools and not Bash subprocesses, so `Read(./.env)` does not stop `cat .env`; pair
permissions with `sandbox.enabled`. And matchers cannot filter Bash by command content,
so a commit gate belongs in `.git/hooks/pre-commit`, not a `PreToolUse` matcher.

## Pass 5: Contradiction

Two loaded instructions disagree and Claude picks one arbitrarily.

Check across the full loaded set, not within one file: user CLAUDE.md against project,
root against nested, CLAUDE.md against `.claude/rules/`, and any of them against the
linter config. The user-scope file is the most common source, because it is invisible
from inside the project.

Prefer the linter as the source of truth and delete the prose copy.

## Structural checks

Run these after the five passes. They describe the file, not an instruction.

| Check | Threshold | Note |
|---|---|---|
| Always-loaded size | 200 lines per CLAUDE.md | A target, not a limit. Longer files load in full and adhere worse. Report the total across every always-loaded file, which is the number that matters |
| `MEMORY.md` size | 200 lines or 25,000 bytes | A hard limit. Content past it is dropped at load and writes past it error |
| Secrets | Any | Keys, tokens, database URLs in a committed file. Report the env var name instead |
| `CLAUDE.local.md` | Gitignored | Not automatic. Confirm with `git check-ignore` |
| Sibling worktrees | `git worktree list` | `CLAUDE.local.md` does not reach a worktree outside the repo. Personal content belongs in `~/.claude/{project}-instructions.md` with a one-line import stub |
| Staleness | Per file | Plans, roadmaps and checklists change faster than the file. ARCHITECTURE.md drifts when module boundaries move |
| Rule file size | 50 lines | Split when longer |

`claudeMdExcludes` skips CLAUDE.md files by absolute-path glob, and is the monorepo
escape hatch when another team's file is loading into your sessions. Managed policy files
cannot be excluded.

Block-level HTML comments are stripped before injection, so they cost nothing and are not
a finding.

## Tiers

| Tier | Name | Criteria |
|---|---|---|
| **Baseline** | Working | Tracked in git, exact build and test commands, no Inert or Contradiction findings, no secrets |
| **Structured** | Organised | Under 200 lines, `.claude/rules/` with every `paths:` verified, `settings.json` with `$schema` and deny rules, `CLAUDE.local.md` gitignored, no Enforcement findings |
| **Automated** | Self-maintaining | Lint or format hook via `${CLAUDE_PROJECT_DIR}` and filtered by extension, a project skill for a repeatable workflow, a custom subagent, MCP where external systems exist |

Each tier includes the previous. Target Structured. Automated pays off on active team
development.
