# Ground-Truth Survey

> Passed verbatim to an Explore subagent at Step 2, substituting `[PROJECT_ROOT]`.

This subagent does not read instruction files. It establishes the facts those
instructions will be checked against. The main agent reads CLAUDE.md and the rest itself,
because the passes and the edits need exact text.

## ground-truth

> Survey the codebase at [PROJECT_ROOT] and return the facts below. Report only what you
> verified by looking. Where something is absent, say absent rather than omitting it,
> because absence is what the audit is testing for.
>
> ## Commands
> - Build, test, single-test, lint, format, and dev-server commands that actually exist,
>   with their source (`package.json` scripts, Makefile, `Cargo.toml`, `pyproject.toml`)
> - Which file extensions the linter and formatter actually cover
> - Any command referenced in CI that has no local equivalent
>
> ## Structure
> - Primary languages and runtime
> - Monorepo? (workspaces, `lerna.json`, `nx.json`, `turbo.json`). If so, every package
>   with its purpose
> - Top-level directory purposes, and current module boundaries
> - Key entry points, by path
> - Rough source file count by language, and total lines of code
>
> ## Configuration inventory
> Paths only, with line counts. Do not summarise contents.
> - Every `CLAUDE.md` anywhere, root and nested
> - `CLAUDE.local.md`, and whether `.gitignore` covers it
> - `ARCHITECTURE.md`
> - `.claude/` contents: `rules/` including subdirectories, `settings.json`,
>   `settings.local.json`, `hooks/`, `agents/`, `skills/`, `commands/`, `workflows/`,
>   `output-styles/`, `agent-memory/`, `agent-memory-local/`
> - `.mcp.json`, `.worktreeinclude`
> - Other tools: `AGENTS.md`, `.cursor/rules/`, `.cursorrules`,
>   `.github/copilot-instructions.md`, `.devin/rules/`, `.windsurf/rules/`,
>   `.windsurfrules`, `.clinerules`, `GEMINI.md`, `.codex/`
>
> ## Environment
> - Linter and formatter config files present
> - CI system and its pipeline steps
> - `.env*` files, and which are gitignored
> - Databases and external APIs the code actually calls
> - `git worktree list` output
> - Observed conventions: indentation, import style, file naming, `.editorconfig`
>
> ## Boundaries currently never crossed
> Import directions, layer separations, or access patterns that hold everywhere in the
> code. These are candidate invariants, and the audit checks them against what
> ARCHITECTURE.md claims.
>
> **Output constraints:**
> - Maximum 500 words
> - No version numbers or dependency lists readable from the package manifest
> - No code examples
> - Paths and counts, not prose descriptions
