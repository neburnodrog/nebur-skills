---
name: new-personal-web-project
description: Bootstrap a new personal web project with opinionated defaults — GitHub repo via gh CLI, Vercel deployment via vercel CLI, optional Stack Auth, and a Next.js or React+Vite stack. Use when the user asks to start, create, scaffold, or bootstrap a new personal web project, side project, or app from scratch.
---

# New Personal Web Project

Opinionated bootstrap: idea → GitHub repo → Vercel deploy in one flow.

## Defaults

- **Repo host**: GitHub via `gh` CLI (private by default)
- **Deploy**: Vercel via `vercel` CLI
- **Framework**: Next.js (App Router) OR React + Vite (bare SPA)
- **Auth** (optional): Stack Auth
- **Package manager**: npm (unless asked) — pnpm or bun on request
- **Project dir**: `~/Repos/<slug>`

Diverge only when the description clearly calls for it — see [STACK-RECS.md](STACK-RECS.md).

## Workflow

### 1. Prerequisites — check in parallel

```bash
gh --version && gh auth status
vercel --version && vercel whoami
node --version
```

If any check fails OR the user lacks a GitHub / Vercel / Stack Auth account, surface the matching section of [PREREQS.md](PREREQS.md) and STOP until resolved.

### 2. Discovery — grill via `AskUserQuestion`

Batch questions 2–4 per call. Drive toward a clear picture before scaffolding.

1. **Project description** (free text via "Other"). Then drill:
   - One-sentence purpose?
   - Audience: just you / friends / public?
   - Single page or multi-page?
   - Server-rendered data or pure client app?
   - Auth (login / per-user state)?
   - Persistence (DB, KV, files)? — flag if yes; this skill does NOT provision storage.
2. **Framework**: Next.js vs React+Vite. Recommend per [STACK-RECS.md](STACK-RECS.md); let user override.
3. **Package manager**: npm (default) / pnpm / bun.
4. **Repo visibility**: private (default) / public.
5. **Project slug**: kebab-case; confirm `~/Repos/<slug>` does not exist.

### 3. Fetch current docs via context7

Local knowledge is stale. Pull fresh docs for the chosen stack BEFORE scaffolding:

- `mcp__plugin_context7_context7__resolve-library-id` then `query-docs`:
  - Next.js → "app router create-next-app"
  - Vite + React → "react-ts template"
  - Stack Auth (if auth) → "Next.js setup" or "React setup"
  - Vercel CLI → "vercel link" + "vercel env add"

### 4. Scaffold locally

```bash
mkdir -p ~/Repos && cd ~/Repos

# Next.js (substitute <pm>)
npx create-next-app@latest <slug> --typescript --app --tailwind --eslint \
  --src-dir --import-alias "@/*" --use-<pm>

# React + Vite
<pm> create vite@latest <slug> -- --template react-ts
cd <slug> && <pm> install
```

Then: `git init` (if missing) and a first commit.

### 5. Create GitHub repo

```bash
gh repo create <slug> --<private|public> --source=. --remote=origin --push
```

### 6. Wire Vercel

```bash
vercel link --yes --project <slug>
vercel git connect
```

Next.js: zero config. Vite: Vercel auto-detects.

### 7. Wire Stack Auth (only if auth chosen)

If the user has no Stack Auth account, point them at [PREREQS.md](PREREQS.md) first.

1. Create project at https://app.stack-auth.com
2. Copy `NEXT_PUBLIC_STACK_PROJECT_ID`, `NEXT_PUBLIC_STACK_PUBLISHABLE_CLIENT_KEY`, `STACK_SECRET_SERVER_KEY`
3. Install: `<pm> add @stackframe/stack` (Next) or `@stackframe/react` (Vite)
4. Configure per context7 docs fetched in step 3
5. Push envs to Vercel: `vercel env add <KEY> production preview development`
6. Mirror to `.env.local`; add `.env.local` to `.gitignore` if missing

### 8. Deploy

```bash
vercel          # preview deploy
vercel --prod   # production deploy
```

### 9. Report

Print, in this order: repo URL, Vercel project URL, deploy URL, local path. Done.

## Verification checklist before claiming done

- [ ] `gh repo view <slug>` resolves
- [ ] `vercel ls` shows the project linked
- [ ] Latest deploy is in `READY` state
- [ ] If auth: visiting the deploy shows working Stack Auth sign-in
- [ ] `.env.local` is gitignored AND populated
