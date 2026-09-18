# Prerequisites — install & account setup

Surface only the section that matches the failing check from SKILL.md step 1. Use `AskUserQuestion` to confirm the user wants to install/sign up before running anything.

## GitHub

### No `gh` CLI

```bash
brew install gh
```

(Other platforms: see https://cli.github.com/)

### `gh` installed but not authed

```bash
gh auth login
```

Pick: GitHub.com → HTTPS → "Login with a web browser". Copy the one-time code.

### No GitHub account

Direct user to https://github.com/signup. After signup, come back and run `gh auth login`.

## Vercel

### No `vercel` CLI

```bash
npm i -g vercel
```

### `vercel` installed but not logged in

```bash
vercel login
```

Prompts for email — user must confirm via emailed link.

### No Vercel account

Direct user to https://vercel.com/signup. Recommend "Continue with GitHub" so the future `vercel git connect` step is one click.

## Stack Auth

No CLI — dashboard-only setup.

### No Stack Auth account

1. Go to https://app.stack-auth.com
2. Sign up (GitHub OAuth recommended)
3. Create a new project; note the project ID
4. From the project's "API Keys" tab, copy:
   - `NEXT_PUBLIC_STACK_PROJECT_ID`
   - `NEXT_PUBLIC_STACK_PUBLISHABLE_CLIENT_KEY`
   - `STACK_SECRET_SERVER_KEY`

Then resume SKILL.md step 7.

## Node

If `node --version` fails or is below 20:

```bash
# If user has nvm
nvm install --lts && nvm use --lts

# Otherwise (Homebrew)
brew install node
```

Vercel deploys default to Node 20+; do not let the user scaffold on Node 18 — Next.js 15 will refuse.
