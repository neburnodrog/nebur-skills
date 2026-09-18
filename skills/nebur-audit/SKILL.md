---
name: nebur-audit
description: Audit and score an existing Claude Code configuration. Finds instructions that cannot fire, that change nothing, that point at a file without saying when to read it, that expect enforcement from guidance, or that contradict each other. Covers CLAUDE.md, .claude/rules/, settings.json, hooks, agents, and ARCHITECTURE.md.
disable-model-invocation: true
argument-hint: "[subdirectory]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - Bash(git rev-parse *)
  - Bash(git log *)
  - Bash(git ls-files *)
  - Bash(git check-ignore *)
---

# Skill: Nebur Audit

Scores a configuration that already exists. It does not create one.

`/init` generates CLAUDE.md, CLAUDE.local.md, skills and hooks, and interviews the
user for what code cannot answer. Run that first on an unconfigured project. This
skill runs after, and answers the question `/init` does not: of everything now
loaded into context, what is actually doing work?

## Step 1: Locate

1. `git rev-parse --is-inside-work-tree`
2. `git rev-parse --show-toplevel` → PROJECT_ROOT
3. Not a git repo? Stop: "Run this inside a git repository."

`$ARGUMENTS` names a subdirectory to scope the audit to, for one package of a monorepo.

No CLAUDE.md anywhere and no `.claude/` directory? Stop: "Nothing to audit. Run `/init`
first, then re-run this." An audit of an empty configuration reports nothing useful.

## Step 2: Collect

Two halves, and they do not swap.

**Read the instructions yourself.** Every CLAUDE.md at or above the scope root, every
nested CLAUDE.md, `CLAUDE.local.md`, `.claude/rules/**/*.md`, `.claude/settings.json`
and `settings.local.json`, `.claude/agents/*.md`, skill frontmatter under
`.claude/skills/`, `.mcp.json`, and `ARCHITECTURE.md`. Exact text matters for the
passes and for the edits that follow, so these are not delegated.

**Delegate the ground truth.** Launch an Explore subagent with the `ground-truth`
prompt from `reference/survey-prompt.md`. It returns what the instructions will be
checked against: which commands exist, which paths resolve, what the linter covers,
where the module boundaries are now.

Completion: every loaded instruction file is in hand, and every factual claim the
audit will test has a ground-truth answer.

## Step 3: Score

Read `reference/audit-passes.md`. For recognising a config component, read
`reference/config-catalogue.md`. For ARCHITECTURE.md, read
`reference/architecture-audit.md`.

Classify **every instruction line** into exactly one of five passes:

| Pass | The instruction… |
|---|---|
| **Inert** | cannot fire. A path that does not resolve, a `paths:` matching no file, a rule in a file that never loads. |
| **No-op** | fires and changes nothing. Claude does this by default. |
| **Trigger** | points at material without saying when to reach it. |
| **Enforcement** | is guidance where a gate is required. |
| **Contradiction** | disagrees with another loaded instruction. |

A line in none of the five is live. Say so and leave it alone.

**Inert is checkable, so check it.** Every path named in an instruction gets resolved
against the filesystem. Every `paths:` pattern gets a Glob with its match count. Report
the count, not an opinion.

**No-op is model-relative and settles by running, not by arguing.** Flag the candidate,
give the reason, and let the user decide. Where the project has an eval suite, say that
`claude plugin eval --ablation with-without` turns the candidate into a measured delta.

Then the structural checks in the reference: size, secrets, staleness, gitignore, and
`${CLAUDE_PROJECT_DIR}` in hook commands.

## Step 4: Report

```
## Claude Code Configuration Audit

**Tier {Tier}, {Name}**
**Loaded every session: {N} lines across {M} files**

### Live
{what is doing work, one line each}

### Findings
1. {Pass} at `{file}:{line}`. {the instruction, quoted}
   Why: {evidence, with the resolved path or match count}
   Fix: {the concrete edit}

### Path to {Next Tier}
```

Order findings by pass, Inert first. Inert and Contradiction are facts. Trigger and
Enforcement are judgements with evidence. No-op is a candidate list.

## Step 5: Fix

Present each fix with its diff, grouped by file. Ask which to apply.

Splitting an over-long CLAUDE.md into `.claude/rules/` is the one fix that creates
files. Verify every `paths:` pattern with Glob before writing it, and report the match
count in the diff.

Apply only what the user approves. Do not commit.

Close with:

"Run `/context` and check **Memory files** to confirm what loads now. `/skill-doctor`
reports the context cost of each skill. If a path-scoped rule does not appear when you
open a matching file, add an `InstructionsLoaded` hook to see what loaded and why."

---

`reference/examples.md` has a worked run.
