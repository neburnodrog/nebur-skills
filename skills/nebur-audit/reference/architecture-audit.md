# ARCHITECTURE.md Audit

<!-- Primary source: matklad.github.io/2021/02/06/ARCHITECTURE.md.html. Not Claude Code specific. -->

> Read by nebur-audit at Step 3 when the project has an ARCHITECTURE.md.

The project has one or it does not. This skill audits it; it does not write one.

**No ARCHITECTURE.md.** Under roughly 10k lines of code, that is correct and not a
finding. A well-structured README covers it. Above that, or where contributors keep
asking where the code for X lives, report it as a missing section and stop there.

**An ARCHITECTURE.md exists.** Audit it. A wrong architecture document is worse than
none, so staleness outranks completeness.

## Scope boundary

ARCHITECTURE.md answers "where does X live?" and "what does this module do?". README
answers "how do I install and run this?". Content in the wrong one is a finding.

Do not fold it into CLAUDE.md either. CLAUDE.md should carry a pointer with a trigger
condition, not a copy of the map. See the Trigger pass.

## Staleness

Check each against the ground-truth survey. These are facts, so resolve them rather than
judging them.

| Check | Finding when |
|---|---|
| Module map paths | A listed directory no longer exists, or a significant one is unlisted |
| Named entry points | The file is gone or renamed |
| Invariants | The boundary is now crossed in the code |
| Cross-cutting concerns | The named implementation file no longer holds it |
| External integrations | A system was removed, or a new one is absent |
| Hyperlinked source files | Any. Links go stale. Name files instead and let contributors search |

Module boundaries and invariants change more slowly than implementation, so a document
describing implementation goes stale fastest. That is both a staleness finding and a
granularity one.

## Sections

Report what is missing, in this order of value.

1. **Invariants.** The most valuable section and the most often absent. What must not be
   violated: layer separation, import direction, who may run SQL. Pay attention to
   absences, because a boundary the code never crosses is an invariant whether or not
   anyone wrote it down. Without this section the architecture erodes silently.
2. **Module map.** The primary deliverable, as a table. Granularity is "a team could own
   this", not individual files. A map of a country, not an atlas of its states.
3. **Overview.** One paragraph on what the project solves and its overall shape. Naming
   the framework and ORM is implementation detail and belongs lower.
4. **Entry points.** The anchor files a new contributor starts from, named not linked.
5. **Cross-cutting concerns.** Auth, logging, error handling, feature flags, and where
   each lives.
6. **External integrations.** What the project calls out to, and the env var that
   configures it.
7. **Data flow.** Only where data movement is genuinely complex. Mermaid earns its place
   there.

## Anti-patterns

| Anti-pattern | Fix |
|---|---|
| Implementation detail instead of purpose and relationships | Describe what a module does and how it relates, not how it works inside |
| Every file documented | Cover the 20% that explains 80%. An exhaustive list is the directory tree in prose |
| Hyperlinked sources | Name them |
| Missing invariants | Add the section. This is the one that prevents decay |
| Sections describing removed modules | Delete them |
| Merged with README | Split once the project is large enough to need both |
| Attempted real-time sync | Review semi-annually and when module boundaries move |
