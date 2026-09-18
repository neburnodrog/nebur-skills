# Configuration Catalogue

<!-- Verified against Claude Code 2.1.269 binary on 2026-09-12. -->

> Read by nebur-audit when it needs to identify a component or judge whether one is
> configured correctly. Recognition reference, not a generation template.

## Map

```
{project-root}/
├── CLAUDE.md                       # Project instructions (committed)
├── CLAUDE.local.md                 # Personal overrides. NOT auto-gitignored
├── ARCHITECTURE.md                 # Codebase map (committed)
├── AGENTS.md                       # Not read natively. Needs @AGENTS.md, a symlink, or `claude import`
├── .mcp.json                       # Project MCP servers (committed)
├── .worktreeinclude                # Gitignored files to copy into worktrees
└── .claude/
    ├── settings.json               # Team settings (committed)
    ├── settings.local.json         # Personal settings (should be gitignored)
    ├── CLAUDE.md                   # Alternate location for project instructions
    ├── rules/                      # Path-scoped rules, discovered recursively, symlinks work
    ├── skills/{name}/SKILL.md      # Skills, invoked as /{name}
    ├── commands/{name}.md          # Legacy single-file skills. Still work. Leave them
    ├── agents/{name}.md            # Subagent definitions
    ├── agent-memory/{agent}/       # `memory: project` (committed)
    ├── agent-memory-local/{agent}/ # `memory: local` (gitignored)
    ├── workflows/{name}.js         # Subagent orchestration scripts
    ├── hooks/{name}.sh             # Hook scripts
    └── output-styles/{name}.md     # Response styles
```

Auto memory lives outside the repo at `~/.claude/projects/<project>/memory/` and is
machine-local. It is Claude's own and is never a finding.

## The two memory systems

Conflating these is the most common setup mistake, so name it explicitly when auditing.

|  | CLAUDE.md files | Auto memory |
|---|---|---|
| Written by | The user | Claude |
| Holds | Instructions and rules | Learnings and patterns |
| Loaded | Every session, in full | First 200 lines or 25 KB of `MEMORY.md` |
| Committed | Yes | No |
| Scope | Project, user, or org | Per git repository, shared across worktrees |

`autoMemoryEnabled` (default true) and `autoMemoryDirectory` control it from any settings
scope. A project that has written instructions into auto memory, or expects auto memory to
be shared with teammates, is a finding.

## Components

### `.claude/rules/`

Discovered recursively. Without `paths:` frontmatter, loads every session at the same
priority as `.claude/CLAUDE.md`. With `paths:`, loads when Claude reads a matching file.

```yaml
---
paths:
  - "src/api/**/*.ts"
---
```

`paths` accepts a YAML list or a comma-separated string. Audit every pattern with Glob.
See the Inert pass for the brace and bracket failures that silently match nothing.

### `.claude/settings.json`

Arrays merge across scopes, scalars take the most specific. Precedence, highest first:
managed policy, CLI flags, `settings.local.json`, `settings.json`, `~/.claude/settings.json`.

Keys worth checking:

| Key | Audit for |
|---|---|
| `permissions.deny` | Secrets reachable. Deny is checked before ask, then allow |
| `permissions.allow` | Prompts on the project's own build tools |
| `sandbox.enabled` | Absent where deny rules are carrying security they cannot enforce |
| `claudeMdExcludes` | Absolute-path globs. The monorepo escape hatch |
| `autoMemoryEnabled` / `autoMemoryDirectory` | Disabled without a stated reason |
| `skillOverrides` | Skills set to `off`, `name-only` or `user-invocable-only` |
| `disableBundledSkills` | Turns off `/run`, `/verify` and the rest |
| `outputStyle` | A style missing `keep-coding-instructions: true` drops the built-in engineering instructions |
| `includeGitInstructions` | `false` with no custom git workflow to replace it |
| `disableAllHooks` | Hooks configured but globally switched off |
| `$schema` | Missing, so no editor validation |

`claudeMd` inlines organisation-wide content and works in managed settings only.

### Hooks

Configured under `hooks` in settings, or scoped to a skill or agent by its `hooks:`
frontmatter.

Events this audit reasons about:

| Event | Blocks? | Used for |
|---|---|---|
| `PreToolUse` | Yes | The gate an Enforcement finding should become |
| `PostToolUse` | Yes | Lint, format, test after edits |
| `SessionStart` | No | Injecting context at startup |
| `InstructionsLoaded` | No | Debugging which instruction files load and why |

Matcher semantics: `*`, `""` or omitted matches all. Letters, digits, `_`, `-`, spaces,
`,` and `|` only means exact match or list (`Edit|Write`). Anything else is an unanchored
JavaScript regex.

Two recurring defects. A command addressed by bare relative path resolves against the
session working directory and fails from any subdirectory, so it must use
`${CLAUDE_PROJECT_DIR}`. An unfiltered lint hook runs the linter on markdown, JSON,
lockfiles and binaries, so it must filter by the extensions the linter covers.

Command contract: JSON on stdin, exit 0 success, exit 2 blocking with stderr fed to
Claude, anything else non-blocking error.

### `.claude/agents/`

Frontmatter fields that carry audit weight: `description` (the pointer that decides
delegation, so it gets the Trigger pass), `tools` and `disallowedTools`, `model`,
`permissionMode`, `memory` (`user`, `project` or `local`), `isolation: worktree`, and
`skills` for preloading.

A subagent does not inherit the main session's auto memory, except a fork, which inherits
the parent conversation.

### `.claude/skills/`

For personal and project skills the command name comes from the **directory** name.
Frontmatter `name` only sets the display label.

Fields that carry audit weight: `description` plus `when_to_use`, truncated together at
1,536 characters in the listing; `disable-model-invocation` (user-only, and excluded from
subagent preloading); `allowed-tools`, which pre-approves for the invoking turn rather
than restricting; `paths`, which limits auto-activation; and `context: fork`, which runs
the skill in a subagent.

`/skill-doctor` reports per-skill context cost. `claude plugin eval` runs a skill's eval
suite, and `--ablation with-without` adds a no-skill baseline arm and reports the delta.

### `CLAUDE.local.md`

Not gitignored automatically. Confirm with `git check-ignore`.

It also does not reach a worktree outside the repo. Where `git worktree list` shows
sibling worktrees, the content belongs in `~/.claude/{project}-instructions.md` with a
one-line import stub in each worktree. That import never belongs in the project CLAUDE.md.

### `.claude/settings.local.json`

Claude Code adds it to the **global** git excludes when it writes a setting there itself.
That does not cover a file written by a skill, and it is not shared with teammates, so the
project `.gitignore` still needs the entry.

### `.mcp.json`

Project root, not inside `.claude/`. Supports `${VAR}` and `${VAR:-default}`. A literal
secret here is a finding; the env var name is not.

### `.worktreeinclude`

Gitignored files copied into worktrees created by `isolation: worktree`. Tracked files are
never duplicated. Expected wherever the project has `.env` files or a local database and
uses worktree subagents.

### `.claude/workflows/` and `.claude/commands/`

Workflows are saved from an observed `/workflows` run. Commands are the legacy single-file
form of a skill and behave identically. Note both, churn neither.
