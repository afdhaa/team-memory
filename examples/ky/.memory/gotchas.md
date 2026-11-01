# Gotchas

> A curated runbook, not a log: things that surprised someone and will surprise the next person.
> Highest priority first; max 10 entries per section. Write each entry so a newcomer understands
> it without opening the code: the title states the problem in a full sentence, `Why:` gives the
> cause, `Do instead:` gives the concrete fix. Format:
> `1. **[YYYY-MM-DD] What goes wrong or what the rule is, in one sentence** #tag @path/ (user|agent, seen: N)`
> `   Why: the cause or the reason behind the rule.`
> `   Do instead: the concrete action — command, file, value.`
> An agent's own conclusion is marked `(agent, seen: 1, unconfirmed)` until the user confirms it,
> it comes up again, or it is verified; then `, unconfirmed` is removed.
> Rename or add sections to fit the project.

## User directives

## Build, test & tooling
1. **[2026-11-01] The type tests in `test-d/` fail with "Cannot find module 'ky'" until `distribution/` is built** #test #types @test-d/ (agent, seen: 1)
   Why: `test-d/` files import `ky`, which resolves through `exports` in package.json to `distribution/index.d.ts`; verified: ran `npx tsc --project tsconfig.test.json` before and after `npm run build`.
   Do instead: run `npm run build` first, or `npm test`, which builds before the type check.

## Domain & code behaviour
1. **[2026-11-01] A network failure whose message Ky does not recognise is thrown as a plain `TypeError` and not retried** #retry #network @source/utils/is-network-error.ts (agent, seen: 1)
   Why: `isRawNetworkError()` accepts only a `TypeError` with a known message: one from a fixed per-runtime list ("fetch failed", "Failed to fetch", …) or one starting with a known prefix (`Load failed (`, Deno's `error sending request for url`). Verified: a `fetch` throwing `TypeError('fetch failed')` ran 3 times, an unknown message once.
   Do instead: add the runtime's message, or a prefix pattern for it, to `is-network-error.ts`, which is inlined from sindresorhus/is-network-error (v1.3.2); fix it upstream first and sync the copy, as commit 61d6d66 did for Safari. Until then, a `shouldRetry` returning `true` retries it.
2. **[2026-11-01] Inside `Ky.ts`, once `#fetch()` has run with `retry.limit` above 0, `this.request` is an unsent clone, not the request that was sent** #retry #request @source/core/Ky.ts (agent, seen: 1, unconfirmed)
   Why: when `retry.limit` is above 0, `#fetch()` sends the current request and puts an unread clone in `this.request` for the next attempt; the sent one is `#originalRequest`.
   Do instead: for the request that failed or produced a response (errors, `beforeError`), use `#sentRequest` or `#getResponseRequest(response)`; `afterResponse` gets the clone on purpose (see its comment).
3. **[2026-11-01] A new error thrown from a `beforeRetry` hook skips the `beforeError` hooks; rethrowing the received `error` runs them** #hooks #retry @source/core/Ky.ts (agent, seen: 1)
   Why: `#throwProcessedError()` passes hook errors through unchanged on purpose; verified with a stub `fetch` returning 503. Returning `ky.stop` resolves with `undefined` and runs no `beforeError` hook.
   Do instead: to stop retrying and keep `beforeError` logging, `throw error` (the hook's argument); `ky.stop` limits: readme.md, "ky.stop".
