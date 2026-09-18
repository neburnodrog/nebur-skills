---
name: comment-cleanup
description: Strip a file set's comments, then restore only what a cold reader asks for — as a comment, or in the design doc with a pointer.
disable-model-invocation: true
---

Comments are a fact you need only once the file is open. This skill empties 
the file and refills it on **demand**: a subagent reads the stripped file **cold**, 
consults the docs, and asks about what it would change. Only questions get answers, 
and only answers become comments. A comment nobody asked about was not load-bearing.

**Cut is the default.** A **load-bearing** comment names the wrong edit it
prevents, in the form `X, not Y: consequence`. 
**Keep comments as concise as possible, sacrifice grammar for the sake of concision**
Rationale, contracts and design decisions live in the design doc with
a `// Why: <doc> §… — …` pointer in the code. What the code already says gets no
comment.

Three tests decide whether a comment survives; open the thing before you rule:

- **Single source of truth** — is the fact already written where an agent
  reaches it anyway: the code itself, a test, a config, the doc? The executable
  copy wins; the comment goes.
- **Sediment** — is it still true? A comment that guards a fixed bug, names a
  swapped library, or gives a count that drifted was correct once, which is why
  nobody deleted it.
- **No-op** — does an agent do anything different with the comment deleted? If
  the answer is "the same thing", it is a no-op even when true and on-topic.

Before step 6, invoke the `writing-for-agents` skill; every comment and doc
sentence you write follows it. Skip it when the environment has no such skill.

You are the **single writer**: subagents report, you edit. Write into the
repository; never commit. Git is the undo. `<work>` is
`$TMPDIR/comment-cleanup/<repo-name>/`; it holds the pre-strip copies and the
reports, and nothing in it enters the repository.

## Steps

### 1. Pin the file set

Work from the repository root. The set is whatever the conversation names: a
ref, "uncommitted", a path list. When you inferred the set rather than read it
in the conversation, print it and stop for confirmation.

Write the resolved paths, one per line, to `<work>/files.txt`, and copy every
file to `<work>/pre/<path>` before anything else. 

Done when: the list and its count are printed, and `<work>/pre/` holds one copy
per file.

### 2. Strip

```bash
node <skill-dir>/strip-comments.mjs <work>/files.txt
```

It keeps tool directives, licence headers and `TODO`/`FIXME`/`HACK`, and refuses
a file whose parse would gain errors; treat a refusal as a bug in the script, not
a file to skip.

Done when: no `REFUSED` list. A file it left alone carried no comments;
`stripped 0` means none of them did, so there is nothing to restore — stop.

### 3. Find the design docs

Read the repository's `CLAUDE.md` / `AGENTS.md` for the documents it names as the
place design decisions live (`docs/ARCHITECTURE.md` and the like). Those are the
**docs** the reader consults and you route to. -cIf the steering names none, the
run is comments-only and that is a **finding** for the report.

Grep the docs for references into the file set ("see the note in
`validator.tsx`", a `file:line`). A comment the doc points at is load-bearing by
reference: move its reason into the doc and put a pointer at the code. These
bypass steps 4–5.

Done when: the doc list is written down, and every doc→comment reference is
listed with its target.

### 4. Cold read

Dispatch one **reader** per file with `model: sonnet`, as many in parallel as
the agent limit allows. The brief, verbatim, with the placeholders filled in:

> Read `<path>` cold and work out how it holds together. You may open what it
> imports, who imports it, its tests, and these docs: `<docs>`. You must not
> read git history, diffs, or anything under `<work>` — the point is what the
> code and the docs tell you.
>
> Go through **every guard, early return, effect cleanup, dependency array, DOM
> tag or attribute choice, and hard-coded number** in the file. For each, one
> of two outcomes:
>
> - You see why it is this way → a row in `<work>/keeps/<path>.md`:
>   `| line | what | why it is right |`. One clause each.
> - You would change it, or you cannot tell → a row in
>   `<work>/questions/<path>.md`:
>   `| line | the edit you would make | why it looks safe | where you looked (doc heading / file) |`.
>   A question is an edit with a reason, never "what does this do". A row
>   whose edit cell is empty, or asks what or why something is, is not a
>   question: delete it before you return.
>
> Grep `tests/` for the file's test ids, selectors and exported names; a spot a
> test pins is a `keeps` row with the test as the reason.
>
> Write both files and return only their paths. Edit nothing else.

Done when: every file has both `<work>/keeps/<path>.md` and
`<work>/questions/<path>.md` (either may be empty).

Trip-wire: a file that draws more questions than it had comment blocks in
`<work>/pre/` gets five rows read before its answerer starts. Rows that ask
what or why instead of naming an edit mean the reader drifted; redispatch it
with those rows quoted as what not to write. Real edit-rows are not drift.

### 5. Answer

Dispatch one **answerer** per file with `model: opus`; a file's answerer may
start as soon as its reader is done. Give it the paths of the two reader files, the pre-strip copy,
the stripped file, and the docs. The brief, verbatim:

> You hold the pre-strip copy of `<path>`; the reader did not. Answer from it
> and from the docs, never from your own opinion of the code.
>
> For every row in `questions.md`: is the edit safe? Write to
> `<work>/answers/<path>.md`:
> `| line | SAFE / NOT SAFE | reason, as the positive rule "X, not Y: consequence" | source: doc heading / old comment lines / test / none |`.
> `SAFE` needs no reason. `NOT SAFE` needs a consequence — what breaks, for
> whom; "the value was chosen deliberately" or "differs from the mock" is
> `SAFE`. A `NOT SAFE` whose source is `none` is a defect the old comments never
> covered; mark it `DEFECT` instead.
>
> For every row in `keeps.md`: does the old comment or a doc name a consequence
> the reader's reason does not — a test that asserts on it, a hazard, a
> coupling? Silence when the reader's reason covers it. When it does not, add a
> row in the same table with the line, `NOT SAFE`, the rule, and the source. A
> plausible reason that misses the real one is how a load-bearing comment dies.
>
> Then route every `NOT SAFE` by one question — *where would good documentation
> derive this?* Unintuitive for a local reason → `COMMENT`. A rule other files
> must obey — a contract spanning files, a repo-wide gotcha, a design choice →
> `DOC`, and say whether the doc already states it. Where a control sits or
> what a pixel value is stays `COMMENT`. Add the route as a final column. Return
> only the path.

Done when: every file has `<work>/answers/<path>.md`.

### 6. Apply

Work from the answer tables on disk. The reason column is a draft; hold it to
these forms:

- `COMMENT`: at the line the row names, in the file's comment style (`//` at a
  statement or between JSX attributes, `{/* */}` between JSX children). History,
  dates and ticket ids do not survive.
- `DOC`, already stated: the pointer is the whole comment, one line —
  `// Why: <doc> §<heading> — <gist in a clause>.`
  A bold lead-in paragraph counts as a heading where the doc has no `###`.
- `DOC`, not stated: write the sentence into the doc under the section that
  covers the area, then the pointer at the code. No section fits → write it as a
  `COMMENT` and record a **finding**: the doc lacks a home for it.
- `DEFECT`: no comment. It goes in the report.
- Formatting the strip left behind (an operator alone on a line where a trailing
  comment split a statement): reflow it. Code stays byte-identical otherwise.

Done when: every `NOT SAFE` row is on disk, and every pointer resolves to a
heading that exists.

### 7. Check

Run the repository's typecheck and lint, by the names `package.json` gives them.
Tests only when the user asks.

Done when: both pass, or the failures are in the report with the line that caused
them.

### 8. Report

One table per file: comment lines removed → questions asked → lines restored.
Under it, each restored line quoted, the edit it stops, and `COMMENT` / `DOC` /
pointer. Then the doc sentences added, the `DEFECT` rows, and the findings (no
docs named; doc had no section; doc→comment references inverted; readers
redispatched). Questions per file is the clarity metric: a file that draws many
is the one to refactor.

Leave `<work>/pre/` in place until the user says otherwise.
