---
name: trim-comments
description: Trim paraphrase comments from the code a branch adds, keeping only load-bearing ones. Use when the user asks to trim, reduce, or clean up comments, or wants a branch's comments minimized before review.
---

# Trim Comments

Cut **paraphrase** — comments that restate the code. Keep **load-bearing** — comments carrying information the code cannot.

**The default is CUT.** A comment is noise until it proves otherwise, and the proof must be a specific fact a reader cannot recover from the code. "It adds context" is not proof. "It's nice to have" is not proof. Expect to remove 40–60% of the comment lines a branch adds; if you land under 25%, you were too polite — go back through the keeps and make each one defend itself.

Scope is the unique code this branch carries: every line it adds against its parent, whether committed, staged, or still in the working tree. Comments the branch did not touch are out of scope, even in files it edits.

## Protected: directives are code

Some comments are read by a compiler, linter, or build step. They look like comments and behave like code. Leave every one exactly as found:

`eslint-disable*`, `@ts-expect-error`, `@ts-ignore`, `prettier-ignore`, `biome-ignore`, `# noqa`, `# type: ignore`, `# pragma`, `//go:embed`, `//go:generate`, `// swiftlint:`, `#[allow(...)]`, shebangs, encoding declarations, license and SPDX headers, and any codegen or region marker.

Markers are protected too: **TODO, FIXME, HACK, XXX, NOTE stay regardless of wording.** They signal unfinished work, and deleting one loses information silently.

## Step 1: Scope

Resolve the parent branch:

```bash
git symbolic-ref --short refs/remotes/origin/HEAD    # usually origin/main
```

If that fails, try in order: `origin/main`, `origin/master`, `origin/develop`, `main`, `master`. If two or more exist and the branch's history doesn't clearly descend from one, ask which parent to diff against rather than guessing.

Then take the merge base and collect the branch's own lines:

```bash
BASE=$(git merge-base HEAD <parent>)
git diff -U0 "$BASE"                        # committed + staged + unstaged, in one pass
git ls-files --others --exclude-standard    # untracked files: every line is new
```

`git diff "$BASE"` compares the working tree to the merge base, so all three states are already covered — do not diff them separately.

Parse the hunk headers into a set of added line numbers per file. **Done when:** every changed file has a recorded set of added line ranges, and untracked files are listed.

## Step 2: Inventory — with a tokenizer, never a grep

**Do not find comments by grepping for lines starting with `#` or `//`.** That misses the cases that matter most: continuation lines inside a multi-line docstring or `/* */` block, and lines a branch appends to a comment that already existed. A grep-built inventory silently skips them, and you will confidently report a file as clean when it is not.

Use the language's own lexer:

- **Python** — `tokenize` for `COMMENT` tokens, plus `ast` to locate module/class/function docstrings and expand each to its full `lineno..end_lineno` span. Beware: a multi-line SQL or template string is *not* a docstring; only the first statement of a body counts.
- **JS/TS/TSX** — the installed `typescript` package, or a scanner that tracks `/* */` block state across lines. Resolve it from the project (`node -e "require.resolve('typescript')"`) since a script outside the project root cannot import it.
- **Other languages** — use a real parser if one is at hand; otherwise scan with explicit block-comment state tracking.

Intersect the comment-line set with the added-line set. A comment counts as in scope if the branch added the line it *starts* on, or added lines *within* it.

Report the count per file, and the line span of every comment. **Any single comment over 3 lines is automatically suspect** — flag it for Step 3 regardless of how good it looks. **Done when:** every added range in every file has been lexed and its comments listed — not sampled.

## Step 3: Adversarial pass (required)

Do not evaluate comments one at a time in isolation and do not start from a posture of charity. Attack the set as a whole, as a reviewer who thinks these comments are bloat and intends to prove it. Run all five checks:

### 3a. Duplicate facts

Build a list of the distinct *claims* the comments make, then find every place each claim appears — across both stacks, and including comments the branch did not touch. **Any fact stated in more than one place is a defect**, not thoroughness: N copies means N−1 future lies the moment the fact changes. Pick the single best home and cut the rest.

Choose the home by *where someone edits when the fact changes*: a deployment constraint belongs in the config file whose value it constrains, not in the module that assumes it; a domain metric belongs in the module that defines it, with everyone else pointing there or saying nothing.

### 3b. The delete test, stated out loud

For each comment: delete it, then name **the specific fact** a competent reader can no longer recover. Write that fact down. If you cannot name one in a short concrete phrase — a unit, an ordering guarantee, a status code, an edge case, an upstream bug number, a deployment coupling — the comment is paraphrase. Cut it. "Explains the intent" and "gives context" are not facts and do not save a comment.

### 3c. The named bans

These die on sight. Every one is a real pattern that survives review by looking useful:

- **Name-echo docstrings** — a summary line that is the function's own name in a sentence. `_utc_hour` → *"SQL that truncates a datetime to its hour."* `validate_params` → *"Raise 422 unless the parameters are valid."* If the body carries a real reason, delete the echo summary and lead with the reason instead.
- **Control-flow narration** — restating a branch, guard, or early return the reader can see. *"Team-scoped requests fall through uncached"* above an `if team: return ...`.
- **Lock/mutex/async definitions** — *"concurrent misses serialize"* is what a mutex is. Keep only the part explaining why the critical section has the *extent* it does.
- **Call-site lists** — *"shared by the X page and the Y dashboard."* Grep answers this, and the comment rots the moment a third caller lands.
- **Filename-in-prose headers** — *"The global momentum plot — the momentum chart over every team"* atop `GlobalMomentumPlot.tsx`.
- **Vague performance claims** — *"this is expensive"*, *"far slower"*, with no number. Unactionable and uncheckable. Either the comment names the real constraint (*why the code is shaped this way*) or it goes.
- **Environment-specific measurements** — *"~16s on dev"*, *"~30x a plain CAST"*, *"half a million rows"*. These rot on the next hardware, dataset, or query-plan change, and no one re-measures. Cut the figure. If removing it leaves a bare *"it's slow"*, that is a sign the whole comment was decoration — cut that too.
- **Cross-stack references** — a backend comment naming a frontend hook, component, tab label, or UI control (and the reverse). The other side can be renamed or deleted without touching this file, so the reference is dead on arrival. State the constraint in terms local to this layer.
- **Restating the callee** — a call-site comment that repeats what the called function's own docstring says.
- **Signature-echo doc params** — `@param id The user ID` on `getUser(id: string)`.
- **Section banners, commented-out code, attribution and changelog noise** — `// ---- helpers ----`, `// added by R, 2026-04`.

### 3d. Mixed comments: keep the reason, drop the restatement

Most over-written comments are a real fact wrapped in three sentences of narration. Do not keep the whole thing because part of it is good, and do not delete the whole thing because part of it is bad. Extract the fact, write it in one line, drop the rest. A 10-line block guarding two lines of code almost always compresses to 2–4.

### 3e. What actually survives

Only these:

- A constraint invisible at this line — units, ordering guarantees, nullability, a status code, an upstream contract, a deployment coupling
- Why a non-obvious choice was made, where the reason is a real constraint and not a vague cost
- A workaround for an external defect, **with its reference** — `// upstream bug, see vercel/next.js#1234`
- A consequence a reader would not predict — *"mutates the input; callers rely on this"*, *"same-day flips cancel out, so no de-duplication is needed"*
- Intent behind code that cannot be read off — a dense regex, bit math, a magic constant, a sign convention that is easy to get backwards
- A tri-state or sentinel contract — what `null` vs `""` vs `undefined` each mean, when they are not obvious
- Doc comments carrying real contract — what it throws (when not visible), what it mutates, when it returns null

Doc comments face the same test as any other comment: signature echo goes, contract stays.

**Done when:** every comment is classified, every keep has its irrecoverable fact written down, and every duplicate claim is resolved to one home.

## Step 4: Confirm

Present, grouped by file:

- **Cuts** — each with the ban it violates or the missing fact
- **Compressions** — before and after line counts, and the fact retained
- **Keeps** — one compact list, each with its named fact
- **Duplicates resolved** — the claim, where it appeared, which home won

State the count: `N comment lines on branch-added lines: X cut, Y compressed to Z, W kept, V protected.` Use lines, not comment count — lines are what the reader pays.

If the reduction is under 25%, say so explicitly and re-attack the keeps before presenting.

Wait for approval. Apply any vetoes before editing. Offer the borderline calls separately so they can be pushed either way. **Done when:** the user has approved the cut list.

## Step 5: Apply and prove

Edit only the approved comments. Remove a now-empty comment block entirely, and drop a line that held nothing but a trailing comment only if the line becomes empty. When compressing, respect the project's formatter width (`.prettierrc` `printWidth`, ruff `line-length`, `.editorconfig`).

Then **prove** equivalence — do not eyeball the diff, and do not classify diff lines with a regex. A docstring body line looks executable to a pattern match, which produces both false alarms and false clears. Compare the code with comments stripped, against `HEAD` (your edits are uncommitted; `HEAD` is the baseline, *not* the merge base — that includes the branch's real feature work and will always differ):

- **Python** — parse both with `ast`, strip docstrings via a `NodeTransformer`, compare `ast.dump`.
- **JS/TS/TSX** — `ts.transpileModule(src, { compilerOptions: { removeComments: true } })` on both, compare with whitespace collapsed. Assert the output is **non-empty** on both sides; a wrong `jsx`/loader setting yields empty output on both and a meaningless "identical". (`esbuild` keeps comments unless `--minify`, so it is the wrong tool here.)
- **No parser available** — fall back to `git diff -U0` and read every hunk by hand.

Then run the project's real linters and tests, using the version CI uses (check the CI config) and the local binary (`./node_modules/.bin/…`) when `npx` misbehaves. Confirm any pre-existing warnings are unchanged by comparing against a stash of your edits, so you don't take credit or blame for someone else's lint debt.

**Done when:** the comment-stripped code is provably identical to `HEAD`, the linters are clean or unchanged, the tests pass, and you have reported the final line counts.
