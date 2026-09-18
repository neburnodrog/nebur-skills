---
name: improve-module-architecture
description: Find deepening opportunities within a specific module, slice, or feature of a codebase — a scoped variant of improve-codebase-architecture. Use when the user wants to review architecture, find refactoring opportunities, or improve testability for one particular part of the app (e.g. "the auth flow", "the order intake module", "the playback engine") rather than scanning the entire codebase.
---

# Improve Module Architecture

A scoped variant of [improve-codebase-architecture](../improve-codebase-architecture/SKILL.md). Same vocabulary, same deepening lens — but focused on **one module the user names up front**, instead of the whole tree.

Reuse the glossary and principles from [LANGUAGE.md](../improve-codebase-architecture/LANGUAGE.md). Don't redefine terms here. In particular: **Module**, **Interface**, **Depth**, **Seam**, **Adapter**, **Leverage**, **Locality**, and the **deletion test**.

## When to reach for this over the full skill

- The user already knows where the pain is.
- A broad scan would spend most of its budget on code the user doesn't care about right now.
- A previous review surfaced one area worth a slower, deeper look.

If the user hasn't named a target yet, ask which module / area / feature — one sentence, then stop. Don't go fishing.

## Process

### 1. Pin the scope

Before exploring anything, get the boundary explicit. Write it down inline in the conversation:

- **In scope** — concrete files / directories / package(s) / domain concept. Resolve fuzzy names ("the search stuff") to actual paths.
- **Edge seams** — the seams this module exposes to callers and the ones it consumes. These matter even when they sit outside the in-scope set.
- **Out of scope** — everything else. No refactors here.

Then read, in this order:

1. `CONTEXT.md` (or the project's domain glossary) for terms touching this module.
2. Any ADRs in `docs/adr/` whose subject overlaps the module.

If the in-scope set is ambiguous, confirm with the user once. Then commit and move on — don't re-litigate scope mid-review.

### 2. Explore the module

Use the Agent tool with `subagent_type=Explore`, scoped to the paths from step 1. Look for the same friction signals as the parent skill (shallow modules, leaky seams, pure-function-for-testability-only extractions, untested behaviour) — but only inside the boundary and at its edges.

Pay extra attention to things only a targeted review can catch:

- **The module's own interface** — deep, or nearly as complex as the implementation?
- **Internal sub-modules** — is there a smaller module *inside* this one trying to get out? Are several sub-modules pretending to be separate when they should collapse into one?
- **Edge seams** — where the module touches the outside world, are those seams real (≥2 adapters) or hypothetical (1 adapter)?
- **Call sites** — how do callers actually use this module? Are they working around the interface? That's the strongest "wrong shape" signal a targeted review can surface.

Apply the **deletion test** to anything suspected of being shallow. The fixed boundary makes the test sharper: if deleting a sub-module pushes complexity *out* of the in-scope set, that's a different signal than complexity reappearing across in-scope callers — note which.

### 3. Present candidates

Same format as the parent skill — numbered list, each candidate with **Files / Problem / Solution / Benefits**. Use `CONTEXT.md` vocabulary for the domain and [LANGUAGE.md](../improve-codebase-architecture/LANGUAGE.md) vocabulary for the architecture.

Two scope rules unique to this skill:

- **Cap suggestions at the in-scope set.** If a candidate genuinely requires changes outside the boundary, mark it clearly: _"requires touching X outside scope — flag for a broader review."_ Don't silently expand.
- **Prefer candidates that re-shape the module's own interface or collapse internal sub-modules** over candidates that just rearrange code inside an unchanged interface. Re-shaping is what the user came for; rearranging is what the parent skill is for.

ADR conflicts: same rule as the parent skill — only surface if the friction is real enough to justify reopening.

Do NOT propose interfaces yet. Ask: "Which would you like to explore?"

### 4. Grilling loop

Same as the parent skill — see [improve-codebase-architecture/SKILL.md §3](../improve-codebase-architecture/SKILL.md). Side effects work identically:

- New domain term during the conversation → add to `CONTEXT.md` inline.
- User rejects with a load-bearing reason that future explorers would need → offer an ADR.
- Want to explore alternative interfaces for the deepened module → see [INTERFACE-DESIGN.md](../improve-codebase-architecture/INTERFACE-DESIGN.md).

For the *how* of actually deepening a module once a candidate is picked, see [DEEPENING.md](../improve-codebase-architecture/DEEPENING.md).
