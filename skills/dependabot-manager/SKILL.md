---
name: dependabot-manager
description: Triage every open Dependabot PR in a repository — classify each as safe, dubious, or unsafe, merge the safe ones, flag the dubious with a test plan, and block the dangerous. Use when the user asks to review, triage, merge, or clean up Dependabot or dependency-update PRs.
---

# Dependabot Manager

Triage every open Dependabot PR in the current repository. Classify each as safe, dubious, or unsafe — then act: merge the safe ones, flag the dubious ones with analysis and a test plan, and block the dangerous ones with a label and explanation.

## Step 1 — Discover open Dependabot PRs

```bash
gh pr list --author "dependabot[bot]" --state open --json number,title,headRefName,body,labels,createdAt,mergeable --limit 100
```

If there are zero open PRs, tell the user and stop.

If `gh` is not authenticated, tell the user to run `gh auth login` first and stop. if not installed guide the user to install it first.

## Step 2 — Pre-filter: merge conflicts and human activity

Before analyzing each PR, do two quick checks:

### 2a. Merge conflicts

```bash
gh pr view <number> --json mergeable
```

If `mergeable` is `"CONFLICTING"`, skip the PR entirely. Note it in the summary as "has merge conflicts — skipped" so the user knows to trigger a Dependabot rebase or close it.

### 2b. Human activity

Check for existing human reviews and comments (not from bots):

- If a human has **approved** the PR, don't skip it — the human already did the review work. Classify it normally and merge if it's SAFE (the human's approval reinforces the decision).
- If a human has left **comments or requested changes** but hasn't approved, skip the PR — they're actively working on it. Note in the summary as "human review in progress — skipped".

**Inspect comment _content_, not just authorship.** Two traps:

- `gh` authenticates as a real user, so this tool's **own prior-run comments** (the `## Dependabot Manager — …` blocks) appear authored by a human. Those are not human review — read the body; if it's a previous automated triage comment, re-evaluate the PR normally rather than skipping it.
- Bot accounts like `vercel`, `github-actions`, `codecov`, `renovate` may not match a naive `*bot*` filter. Preview-deploy / status comments from these are not human activity — ignore them for the skip decision.

## Step 3 — Analyze each PR

For every remaining PR, gather three things:

### 3a. The diff and metadata

```bash
gh pr view <number> --json title,body,headRefName,baseRefName,additions,deletions,files,statusCheckRollup,labels
gh pr diff <number>
```

### 3b. CI check status

```bash
gh pr checks <number>
```

### 3c. Extract the key facts

From the diff (typically `package.json` and lock file changes) and the PR body, determine:

- **Package name** being updated
- **Version change**: old → new
- **Semver bump type**: patch (`x.y.Z`), minor (`x.Y.z`), or major (`X.y.z`). Treat a `0.x` package specially: for pre-1.0 packages the **minor** digit is breaking-by-convention (`0.34 → 0.35` carries the weight of a major bump)
- **Dependency type**: `dependencies` (production) or `devDependencies` — read this from `package.json`, don't infer it from the PR title. Dependabot's `deps` vs `deps-dev` title prefix reflects the dependency _path_, not necessarily where the package is declared
- **Direct vs transitive**: if only the lock file changed (`package.json` untouched), it's transitive. If `package.json` declares it, it's direct — even if it's never `import`-ed in code (e.g. `sharp` is declared so `next/image` uses it). Don't assume "no imports" means "transitive"; check `package.json`
- **Is it actually used in app code?** `grep -rn "from '<pkg>'" src/` (and `require`). A package that's declared but not imported (build/runtime tooling) means API-surface changes in its changelog can't touch your code
- Whether the PR body mentions **breaking changes**, **deprecations**, or **security advisories**
- Whether this is a **security update** (see detection below)
- Whether any other open Dependabot PR updates a related package (same npm scope like `@tanstack/*`, or a known peer dependency)

### Detecting security updates

Dependabot security PRs (fixing a CVE in your current version) look different from routine version bumps:

- The PR title often starts with `build(deps): bump <pkg>` but the body contains "**Dependabot alerts**" or "Fixes a security vulnerability"
- The PR may carry a `security` label
- The branch name may contain `security` or reference a specific advisory

Security fixes should be fast-tracked — they reduce risk rather than introducing it.

## Step 4 — Identify grouped PRs

Before classifying, group PRs that share an npm scope (e.g., `@tailwindcss/postcss` and `tailwindcss`, or `@tanstack/react-query` and `@tanstack/react-query-devtools`).

For each group, check whether one PR's diff is a **superset** of another — this happens when a transitive dependency update in one PR already covers the direct update in another. When PR A's lockfile diff already bumps the package that PR B targets:

- **PR A is the comprehensive one** — classify and act on it normally
- **PR B is redundant** — note in the summary that merging A makes B unnecessary. Do not act on B; it will either auto-close after A merges or become a trivial no-diff PR

When neither PR subsumes the other (they update genuinely different packages that share a scope), note the relationship but classify each independently. Mention in comments that they should be merged in sequence and that CI should be re-checked after the first one lands.

## Step 5 — Classify risk

### SAFE — auto-merge, no questions asked

All of these must hold:

- CI checks are **all passing**
- The bump is a **patch** (any dependency type), OR a **minor bump of a devDependency**
- The PR body does not mention breaking changes or deprecations
- The PR is not part of a group that requires coordinated merging (or it's the comprehensive PR in a superset group)
- OR: it is a **security fix** with passing CI (fast-track regardless of bump type)

### DUBIOUS — comment with analysis + test plan

Any of these:

- **Minor bump of a production dependency** (even with green CI — behavioral changes are possible)
- **Major bump with all CI checks passing** — the semver contract says to expect breaking changes, but fully green CI (especially if the project has type-checking and tests) is strong evidence it might actually be safe. Flag for human review rather than hard-blocking, since the risk is real but the CI signal is encouraging
- CI checks are **pending** (not yet conclusive)
- CI has **flaky-looking failures** (e.g., one retry passed, one didn't) rather than clear red
- The changelog mentions behavioral changes that aren't explicitly breaking but could affect the app

### UNSAFE — label and block

Any of these:

- **Major version bump with failing CI** — both the semver contract and the test suite agree this is breaking
- CI checks are **failing in a way caused by the dependency update** (e.g., the lint check fails after an eslint bump — even if other checks like tests still pass, the causal link makes this a real failure)
- PR body or changelog **explicitly mentions breaking changes** AND CI is not fully green
- The update would create a **peer dependency conflict**
- A known **security vulnerability exists in the new version** (not the old — that would make the update urgent)

## Step 5.5 — Resolve DUBIOUS verdicts with evidence (do this BEFORE commenting)

**DUBIOUS is a prior under uncertainty, not a final verdict.** The classification above encodes "behavioral changes are _possible_" — it does not establish that any occurred. That uncertainty is usually cheap to resolve, and resolving it is strictly better than deferring a generic test plan to a human: it either clears the PR for merge or sharpens the concern to something specific. For each PR provisionally classified DUBIOUS, run this pass before writing a comment.

### A. Read the actual changelog for the version range

- The PR body usually embeds the release notes — read those first.
- For the full delta, `WebFetch` the package's GitHub releases (`https://github.com/<org>/<repo>/releases`) or its `CHANGELOG.md` / docs changelog, and ask specifically for every version **between old and new (inclusive of the new)**.
- **context7 caveat:** context7 indexes a library's _current API docs_, often pinned to a single version. It's good for "how does API X behave" but usually **cannot answer "what changed between X and Y."** Use release notes / changelog for version deltas; use context7 only for API-behavior context.

### B. Cross-check every changelog entry against THIS repo

For each item in the changelog (breaking change, deprecation, behavioral fix, locale/format change, new default, Node-version floor):

- Does the repo use the affected API / option / locale / format / output mode? `grep` for it; read the relevant config (`next.config.*`, `tsconfig`, tool configs).
- Is the package even imported in app code (from Step 3c)? If not, API-surface removals are moot.
- For a Node-version floor: check `engines`, `.nvmrc`, and CI `node-version` — and call out that **local developers** below the floor will break on `npm install` even if CI/host won't.
- Locale/format libs: confirm whether the changed locale/format is one the app actually uses (e.g. a `pt`/`zh` fix is irrelevant to a German-only app).

### C. Probe the affected subsystem where it's cheap

If a preview/staging deployment exists (Vercel posts the URL in its PR comment) or a relevant test path exists, exercise the **exact code path the dependency powers** — bytes beat vibes:

- **Image library** (sharp, etc.): hit the optimizer directly, e.g. `curl -D - -H "Accept: image/webp" "<preview>/_next/image?url=<encoded>&w=384&q=75"` and confirm a valid optimized image (HTTP 200, expected `content-type`, correct magic bytes like `RIFF…WEBP`). Vary the `Accept` header to confirm which output formats are actually served.
- **Date/i18n / formatting lib**: render a page or run the test that exercises it; confirm output is unchanged.
- **Build tool / bundler / framework**: run `npm run build` and diff for new warnings or output changes.
- Confirm the preview deployment's CI **re-ran against current `HEAD`** — after earlier merges land, Dependabot rebases, and a fresh green run against today's base is far stronger evidence than a stale one.

### D. Re-classify on the evidence

- **Nothing relevant changed, or the subsystem verifies clean → promote to SAFE.** Approve + merge, and record what you verified in the approval/comment (changelog reviewed, paths checked, subsystem probed). This was the outcome for the great majority of "minor prod dep" and "verified-inapplicable breaking change" cases.
- **A genuine but narrow residual remains** (e.g. cosmetic output drift from an encoder bump) → **keep DUBIOUS**, but the comment must state the _narrowed_ residual and everything you already ruled out — not a generic "behavioral changes are possible."
- **Verification surfaces a real break** → **escalate to UNSAFE** (label + block).

> Merging may require user authorization (the harness can gate `gh pr review --approve` / `gh pr merge` as a high-severity external write). If a merge is blocked, present the gathered evidence and ask the user how to proceed rather than abandoning the verdict.

## Step 6 — Act

Process PRs in this order: SAFE first (to land easy wins and potentially auto-resolve grouped PRs), then DUBIOUS, then UNSAFE.

### SAFE → approve and merge

```bash
gh pr review <number> --approve --body "Auto-approved: <one-line reason, e.g. 'patch bump of devDependency with passing CI'>"
gh pr merge <number> --squash
```

If the merge fails (branch protection, required reviewers, etc.), note it in the summary as "approved but could not auto-merge — may require additional approvals" and move on.

### DUBIOUS → comment with the _narrowed_ residual + remaining test plan

Only PRs that **survived Step 5.5** still land here — i.e. the changelog cross-check and subsystem probe left a genuine, specific residual that a human should sign off on. The comment must show your work: what you verified and ruled out, and the one thing that remains. Do not post a generic "behavioral changes are possible" plan when you could have resolved it.

```bash
gh pr comment <number> --body "$(cat <<'COMMENT'
## Dependabot Manager — Needs Review

**Package:** `<name>` `<old>` → `<new>` (<bump type>, <dep type>)

### Verified (ruled out)
<Bullet each changelog item you checked and why it doesn't apply here — e.g. "Node 18 dropped → CI/Vercel on Node 24"; "API X removed → not imported in src/"; "AVIF retuned → no images.formats, serves WebP (confirmed live)". Cite the subsystem probe if you ran one.>

### Residual concern
<The one specific thing that remains, and why CI/changelog can't settle it — e.g. "libvips encoder bump may subtly change WebP output bytes; not breaking, but cosmetic drift is possible.">

### Test Plan
- [ ] <The single cheap check that closes the residual — tied to how the package is actually used here>
- [ ] Run `npm run build` and confirm no new warnings

COMMENT
)"
```

If Step 5.5 instead **cleared** the PR to SAFE, don't post this — approve + merge via the SAFE path and record the verification in the approval body. If a merge is gated by the harness, present the evidence and ask the user.

Also add a `needs-review` label — but only if the PR doesn't already carry a stronger label like `DO NOT MERGE`. Never downgrade a blocking label.

```bash
gh pr edit <number> --add-label "needs-review" 2>/dev/null
```

### UNSAFE → block with label and explanation

```bash
gh label create "DO NOT MERGE" --color "B60205" --description "Blocked — requires manual review" --force 2>/dev/null
gh pr edit <number> --add-label "DO NOT MERGE"
gh pr comment <number> --body "$(cat <<'COMMENT'
## Dependabot Manager — DO NOT MERGE

**Package:** `<name>` `<old>` → `<new>` (<bump type>)

### Why this is blocked
<Specific reason. E.g., "Major version bump with failing CI — both semver and the test suite confirm breaking changes.">

### What needs to happen
- <E.g., "Review the migration guide at <url from PR body>">
- <E.g., "Fix the lint/test failures introduced by this version">
- <E.g., "Wait for `@tanstack/react-query-devtools` to also be bumped to v6">
- <E.g., "Update usage of deprecated API X in src/hooks/api/">

COMMENT
)"
```

## Step 7 — Summary

After processing all PRs, present a table:

| PR   | Package              | Bump              | Type    | CI  | Tier    | Action                               |
| ---- | -------------------- | ----------------- | ------- | --- | ------- | ------------------------------------ |
| #410 | firebase             | 12.12.0 → 12.12.1 | prodDep | ✅  | SAFE    | Merged                               |
| #411 | @tailwindcss/postcss | 4.2.2 → 4.2.3     | devDep  | ✅  | SAFE    | Merged (comprehensive update)        |
| #413 | tailwindcss          | 4.2.2 → 4.2.3     | devDep  | ✅  | —       | Skipped (subsumed by #411)           |
| #405 | typescript           | 5.9.3 → 6.0.3     | devDep  | ✅  | DUBIOUS | Commented (major bump, but CI green) |
| #412 | eslint               | 9.39.4 → 10.2.1   | devDep  | ❌  | UNSAFE  | Labeled DO NOT MERGE                 |

**Totals:** X merged, Y flagged for review, Z blocked, W skipped.
