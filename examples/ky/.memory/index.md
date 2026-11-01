# Project Memory — Index

> Read this file at the start of every task. Keep it under ~150 lines.
> Details live in the files listed in the map below.

## Project summary
Ky is a small HTTP client library built on the Fetch API, published on npm as `ky` by Sindre Sorhus.
JavaScript and TypeScript developers use it in browsers, Node.js, Bun and Deno instead of calling `fetch()` directly, for method shortcuts, retries, timeouts, hooks and HTTP errors on non-2xx responses.
It is written in TypeScript, ships as an ES module compiled to `distribution/`, and has no runtime dependencies.
This checkout is release 2.2.0 (2026-10-09); the 2.x line started with 2.0.0 in April 2026.

## Rules & preferences
<!-- Standing rules, max ~15, most important first. One full sentence each, with the reason
     when it is not obvious. Example:
- Always reply in Bahasa Indonesia; code comments in English.
- Memory language: English (default; change only if the user asks).
- Never commit directly to main; every change goes through a pull request so CI runs first.
-->

## Key facts
<!-- Stack, how to run / test / deploy, important paths, where config & secrets live (never the values). -->
- Stack: TypeScript 5.9 · npm · tests with ava and Playwright; Express 5 is only the test server (`test/helpers/create-http-test-server.ts`).
- Commands: `npm run build` · `npm run test` (xo lint, build, type tests in `test-d/`, then all ava tests)
- One test file: `npx ava test/retry.ts`; ava runs the TypeScript through tsx, so only `test/browser.ts` needs `npm run build` first.
- Node.js >= 22 (`engines` in package.json).
- Project conventions for agents, such as never accepting `null` (the `signal` option is the one exception): AGENTS.md.
- Main folders: `test/`, `source/`, `test-d/`
- More: topics/codebase.md (how the code fits together, project layout, generated facts)

## Map
<!-- One line per file in topics/ and procedures/. Example:
- topics/auth.md — login flow, token refresh, legacy v1 endpoints
- procedures/release.md — steps to tag and deploy a release
-->
- progress.md — current status, next steps, blockers
- decisions.md — why things are the way they are
- gotchas.md — mistakes, corrections, surprises
- topics/codebase.md — how the code fits together, what each folder is for, plus generated repo facts: stack, commands, layout, config, CI (refresh: mem.sh scan)
- topics/retries.md — when Ky retries, how long it waits, and the cases it does not retry
