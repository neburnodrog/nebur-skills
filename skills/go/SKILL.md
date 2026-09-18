---
name: go
description: End-to-end ship workflow — test the project, simplify changed code, and open a PR. Use when the user says "go", "ship it", "take it to the finish line", "test and PR", "wrap it up", "finish this", or wants to go from working code to a reviewed, tested pull request in one shot. Also use when the user wants to validate their work end-to-end before shipping. This skill orchestrates the full pre-merge pipeline so the user doesn't have to run each step manually.
---

# Go — Test, Simplify, Ship

You are an orchestrator. Your job is to take the user's current work from "code written" to "PR open" by running three phases in sequence: **end-to-end testing**, **code simplification**, and **PR creation**. Each phase must pass before moving to the next.

The power of this skill is that it figures out *how* to test based on what kind of project it's in, then chains the results through simplification and into a clean PR — all without the user having to specify the details.

## Phase 0: Detect Project Type

Before doing anything, figure out what you're working with. Examine the project root and its files to classify the project. Run these checks in parallel:

```bash
# Check for key project signals
ls package.json Cargo.toml pyproject.toml go.mod Gemfile build.gradle pom.xml 2>/dev/null
```

```bash
# Check for platform-specific indicators
ls manifest.json app.json app.config.js app.config.ts expo-env.d.ts capacitor.config.ts 2>/dev/null
```

```bash
# Check for test infrastructure
ls playwright.config.ts playwright.config.js cypress.config.ts cypress.config.js jest.config.ts jest.config.js vitest.config.ts 2>/dev/null
```

```bash
# What changed? This tells us what to test
git diff --name-only HEAD~1..HEAD 2>/dev/null || git diff --name-only --cached 2>/dev/null || git diff --name-only 2>/dev/null
```

Classify into one of these project types based on the signals:

| Type | Key Signals |
|------|-------------|
| **chrome-extension** | `manifest.json` with `"manifest_version"` field |
| **expo-mobile** | `app.json`/`app.config.*` with `"expo"` key, or `expo-env.d.ts` |
| **react-native** | `react-native` in dependencies but no expo |
| **web-app** | Has `next.config.*`, `vite.config.*`, `webpack.config.*`, or `index.html` entry point |
| **backend-api** | Has server/API entry point (Express, FastAPI, Flask, Django, Rails, Spring, Go net/http) |
| **library** | Has build config but no server or app entry point |
| **cli-tool** | Has `bin` field in package.json, or a CLI entry point |
| **fullstack** | Both frontend build config AND backend server detected |
| **unknown** | None of the above — fall back to running existing test suites |

For **fullstack** projects, run both the backend and frontend testing strategies.

Report the detected type to the user before proceeding: "Detected **[type]** project. Running end-to-end validation..."

## Phase 1: End-to-End Testing

The goal is to verify the project actually works — not just that unit tests pass, but that a user could use the thing. Choose the testing strategy based on project type.

### Strategy Selection

**For all project types**, start by running the existing test suite if one exists:

```bash
# Detect and run whatever test runner is configured
# npm test, pytest, cargo test, go test, etc.
```

If the test suite fails, stop and report. Don't proceed to testing in a browser/emulator if the fundamentals are broken.

**Then apply the type-specific strategy:**

### Browser Testing: Chrome Extension vs Playwright

When you need to visually verify something in a browser, choose the right tool:

- **Chrome Claude extension** (computer use / browser tool): Use for **one-off quick checks** — loading a page, eyeballing a UI, verifying something renders. This is the default for `/go` because we're doing a single validation pass before shipping.
- **Playwright MCP**: Use only when you need **repeatable automation** — running the same checks multiple times, or when the project has an existing Playwright test suite to execute.

In practice, this means: start the dev server, open it in the browser via the Chrome extension, take a look, screenshot it. Don't spin up Playwright infrastructure for a single check.

#### chrome-extension

1. Run existing E2E tests if found (Playwright, Puppeteer with extension loading).
2. Build the extension and verify the build output:
   ```bash
   # Run the build command from package.json
   npm run build  # or whatever the build script is
   ```
3. Verify the built extension has valid structure (manifest.json, referenced files exist).
4. Open the browser via the Chrome extension and manually verify:
   - Load the extension (or a test page that triggers it)
   - Check that the popup renders / content script injects / background worker starts
   - Test the primary user action
5. Only use Playwright if there's an existing test suite or the user explicitly wants automated checks.

#### expo-mobile / react-native

1. Run the existing test suite (`npx expo run:ios --no-install` or equivalent).
2. If an emulator/simulator is available, start the app and verify it launches:
   ```bash
   # For Expo
   npx expo start --no-dev --ios  # or android
   ```
3. If the project has web support, start the web version and do a quick browser check via the Chrome extension.
4. At minimum, verify the app builds without errors:
   ```bash
   npx expo export --platform web 2>&1  # Quick build validation
   ```

#### web-app

1. Start the dev server in the background:
   ```bash
   # Detect the dev command from package.json scripts
   npm run dev &  # or yarn dev, pnpm dev, etc.
   ```
2. Wait for the server to be ready (poll the port).
3. Open the app in the browser via the Chrome extension:
   - Load the main page and verify it renders
   - Navigate the primary user flow related to the changed files
   - Check for console errors
   - Take a screenshot for the PR
4. Only use Playwright MCP if the project has an existing Playwright config or you need to repeat the same checks.
5. Kill the dev server when done.

If no browser tool is available at all, fall back to:
- `curl` the dev server to verify it responds with HTML
- Check for build errors: `npm run build`

#### backend-api

1. Start the server in the background.
2. Test the API endpoints that were changed using `curl` or equivalent:
   ```bash
   curl -s http://localhost:<port>/health  # or equivalent health check
   ```
3. For endpoints affected by the changes, make representative requests and verify responses.
4. Check for error logs in the server output.
5. Kill the server when done.

#### library / cli-tool

1. Run the test suite.
2. For libraries: verify the build succeeds (`npm run build`, `cargo build`, etc.).
3. For CLI tools: run the CLI with `--help` and a basic command to verify it works.

#### fullstack

Run both **backend-api** and **web-app** strategies. Start the backend first, then the frontend.

#### unknown

Run whatever test command exists. If none, check for a build command. Report what you found and tested.

### Test Failure Protocol

If any test fails:
1. Report the failure clearly — what failed, the error output, and which file(s) are involved
2. **Stop the /go workflow** — do not proceed to Phase 2 or 3
3. Ask the user: "Tests failed. Want me to fix these before continuing, or should we skip and proceed anyway?"
4. If the user says fix: attempt the fix, then restart Phase 1
5. If the user says skip: note it in the PR description and continue

## Phase 2: Simplify

After tests pass, run the `/simplify` skill on the changed code. This reviews recent changes for reuse opportunities, code quality, and efficiency — then fixes any issues found.

Invoke the simplify skill. It will:
- Identify recently changed files
- Review them for clarity, consistency, and maintainability
- Apply fixes while preserving all functionality

If simplify makes changes, re-run the relevant tests from Phase 1 to make sure nothing broke. If tests fail after simplification, revert the simplify changes and proceed with the original code.

## Phase 3: Open PR

After testing and simplification, create the pull request.

Invoke the `ce-commit-push-pr` skill if available. It handles:
- Staging and committing with good commit messages
- Pushing to remote
- Creating the PR with a value-first description

If `ce-commit-push-pr` is not available, do it manually:

1. Stage the changes (be specific about files, avoid `git add .`):
   ```bash
   git add <changed-files>
   ```

2. Create a commit with a clear message following repo conventions.

3. Push:
   ```bash
   git push -u origin HEAD
   ```

4. Create the PR:
   ```bash
   gh pr create --title "<title>" --body "$(cat <<'EOF'
   ## Summary
   <what changed and why>

   ## Testing
   <what was tested in Phase 1 — be specific>

   ## Simplification
   <what /simplify changed, if anything>

   EOF
   )"
   ```

### Evidence

If you captured screenshots or test output during Phase 1, include them in the PR description. Visual evidence of the feature working is valuable for reviewers.

## Summary Output

After all three phases complete, give a brief report:

```
Testing:  [pass/fail] — <what was tested>
Simplify: [changes/no changes] — <what was simplified>
PR:       <PR URL>
```
