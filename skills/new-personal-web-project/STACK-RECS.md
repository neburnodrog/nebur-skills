# Stack recommendations — when to deviate from defaults

Read the user's project description against these heuristics. If a heuristic triggers, propose the alternative through `AskUserQuestion` with a one-line rationale. Never silently override defaults.

## Framework choice

### Pick Next.js (default) when

- Description mentions: SEO, social previews / OG tags, content site, blog, marketing page, landing page that needs to rank
- Server-side data fetching, secrets used at request time, or per-request rendering
- Auth-protected pages where you want server-side session checks
- API routes / server actions are needed
- Image-heavy site (use `next/image`)

### Pick React + Vite when

- Pure client app: dashboards, playgrounds, demos, tool UIs, canvas/WebGL experiments, audio toys
- "Single page, no SEO" or "behind a login wall"
- The user explicitly wants the lightest possible stack
- Bundle size matters more than SSR

### Edge cases — surface to user, don't auto-pick

- Multi-page interactive tool with auth → either works; ask
- "I want to learn X" → defer to user's learning goal
- Real-time / websockets heavy → either works; ask about hosting model

## Auth

### Default to NO auth unless

- Description mentions: login, signup, user accounts, "my X", personalised, save user data, social features
- Persistence per user (which implies identifying users)

If the user says "maybe later" → still skip auth now; adding Stack Auth post-hoc is easy.

## When the description implies storage

This skill does NOT provision databases. If the user mentions:

- "save", "remember", "history", "users can store", "per-user data", "comments", "posts" → flag explicitly:
  - "You'll need persistence. This skill won't set that up. After bootstrap, common choices: Vercel Postgres / Neon / Supabase / Turso."
- Offer to continue without DB (scaffold + deploy first) OR pause until the user picks a DB.

## Package manager nudges

- Monorepo / workspaces mentioned → suggest `pnpm`
- Speed-first / Bun-friendly libs only → suggest `bun`
- Otherwise → npm

## "Toy project" signal — strip everything

If the user says: "just messing around", "quick demo", "1 hour project", "throwaway":

- Vite + React (no Next.js)
- No auth
- No tailwind unless asked
- Private repo
- Skip Stack Auth wiring entirely

## Stricter Next.js variant

If user mentions: production app, real users, "I want this to last":

- Add `--eslint --tailwind` to scaffold (already in default)
- Suggest enabling Vercel Speed Insights and Web Analytics post-deploy
- Suggest pnpm over npm

## Recommendation format

When deviating, always present as a single AskUserQuestion option:

> "Your description sounds like X (e.g. 'a personal dashboard behind a login wall'). I'd recommend **React+Vite + Stack Auth** instead of the Next.js default — lighter, no SSR you won't use. OK or stick with Next.js?"
