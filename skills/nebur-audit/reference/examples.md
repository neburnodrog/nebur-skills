# nebur-audit worked run

> Read when the shape of a run is unclear. Not needed on a normal pass.

```
User: /nebur-audit

Agent: Reading the configuration and surveying the codebase...

Loaded every session: 417 lines across 4 files
  CLAUDE.md                     342
  ~/.claude/CLAUDE.md            48
  .claude/rules/style.md         27  (no paths: frontmatter, loads always)

## Claude Code Configuration Audit

**Tier Baseline, Working**

### Live
- Build and test commands, exact and present in package.json
- The soft-delete gotcha on the users table. Nothing else states it
- `.claude/rules/api.md`, paths: src/api/**/*.ts (61 files match)

### Findings

1. Inert at `CLAUDE.md:88`. "Log corrections to `tasks/lessons .md`"
   Why: the path does not resolve. No `tasks/` directory exists. The space in the
   filename means downstream agents either create `tasks/lessons .md` literally or
   skip the instruction.
   Fix: `tasks/lessons.md`, and create the directory.

2. Inert at `.claude/rules/mobile.md:3`. paths: "src/native/**/*.tsx"
   Why: Glob returns 0 matches. The directory was renamed to `src/mobile/` in March.
   The rule has never loaded.
   Fix: update the pattern to `src/mobile/**/*.tsx` (43 files match).

3. Contradiction between `CLAUDE.md:51` and `.eslintrc:12`
   Why: CLAUDE.md says single quotes, ESLint enforces double.
   Fix: delete the CLAUDE.md line. The linter is the source of truth.

4. Enforcement at `CLAUDE.md:203`. "NEVER commit directly to main"
   Why: CLAUDE.md is context, not a gate. A matcher cannot filter Bash by command
   content either, so this is not a PreToolUse hook.
   Fix: a `.git/hooks/pre-commit` branch check.

5. Trigger at `CLAUDE.md:14`. "See ARCHITECTURE.md for the codebase map."
   Why: names the target, encodes no condition, so it fires at random.
   Fix: "Read ARCHITECTURE.md before changing a module boundary or adding a package."

6. Staleness at `ARCHITECTURE.md:22`. The module map lists `src/native/`
   Why: renamed to `src/mobile/`. Same rename as finding 2.

7. No-op candidates, 9 lines at `CLAUDE.md:104-131`
   Why: ESLint config restated in prose (lines 104-118), plus "write clean code",
   "handle errors gracefully", "keep functions small".
   Fix: delete. If you want this measured rather than judged, an eval suite with
   `claude plugin eval --ablation with-without` reports the delta.

### Path to Structured
- Fix findings 1, 2 and 3. Those are facts, not judgements
- CLAUDE.md 342 lines to under 200. Findings 3 and 7 remove 31. Moving the testing
  and React sections to path-scoped rules removes another 120
- `CLAUDE.local.md` exists but is not gitignored
- No `$schema` in settings.json, no deny rules for `.env`

Apply fixes? I can group them as facts (1, 2, 3, 6), routing (4, 5), and cuts (7).
```
