# Retries

## Overview
Ky retries a failed attempt in `#retryFromError()` in `source/core/Ky.ts`; the decision and the wait come from `#calculateRetryDelay()`, retry defaults and validation from `normalizeRetryOptions()` in `source/utils/normalize.ts`, and header parsing from `source/core/retry-timing.ts`. Every option is documented under "retry" in `readme.md`; this page gives the order of the checks and the cases the readme does not spell out.

Source: read from the code on 2026-11-01 (agent, unconfirmed). Points marked "verified" were run with a stub `fetch` option; `npx ava test/retry.ts test/retry-decisions.ts test/retry-timing.ts test/retry-options.ts` passed.

## How it works
`#calculateRetryDelay()` checks in this order, and the first check that fails throws the original error instead of retrying:

1. The retry count must be below `retry.limit` (default 2). Ky reads the limit again when each attempt starts, so a hook can change it by setting `options.retry.limit` (an `afterResponse` hook can only lower it for the current attempt); `retry` cannot be changed through the `options` a `beforeRetry` hook returns.
2. A `ForceRetryError` from `ky.retry()` in an `afterResponse` hook skips steps 3–7 (method list, `shouldRetry` and the error-type checks), so it also retries `post` and `patch` (verified). It waits its own `delay` exactly, without jitter or `backoffLimit`, or the computed backoff when it has none.
3. The request method must be in `retry.methods` (default `get`, `put`, `head`, `delete`, `options`, `trace`, `query`). Other methods, including `post` and `patch`, are not retried and `shouldRetry` is not even called for them (verified); only a `ky.retry()` from step 2 retries them.
4. `retry.shouldRetry`, when set: `false` stops, and `true` skips the yes/no checks in steps 5–7 but keeps their timing rules. Any other result falls through to the defaults.
5. `TimeoutError` is retried when `retryOnTimeout` is `true` (default `false`), using the computed backoff.
6. `HTTPError` must have its status in `retry.statusCodes` (default 408, 413, 429, 500, 502, 503, 504). With a retry timing header and a status in `afterStatusCodes` (default 413, 429, 503), the wait is the header value capped by `maxRetryAfter`. Otherwise `413` is not retried (verified) unless `shouldRetry` returned `true`, and other statuses use the computed backoff. A timing header Ky cannot parse also uses the computed backoff, so a `413` with an unparsable `Retry-After` is retried (verified).
7. `NetworkError` uses the computed backoff; any other error is thrown (see the decision in decisions.md).

The computed backoff is `retry.delay(attemptCount)`, by default `0.3 * 2 ** (attemptCount - 1) * 1000` ms: 300 ms, then 600 ms (verified). `jitter: true` replaces it with a random value between 0 and that delay, and a `jitter` function's result is used unless it is negative or not finite. The result is then capped by `backoffLimit`.

The retry timing header is `Retry-After` when present; only without it does Ky read `RateLimit-Reset`, `X-RateLimit-Retry-After`, then `X-RateLimit-Reset` or `X-Rate-Limit-Reset`. A header Ky cannot parse falls back to the computed backoff instead of disabling the retry.

`#retryFromError()` then caps any wait at 2,147,483,647 ms (`maxSafeTimeout`, the largest `setTimeout()` delay). With `totalTimeout`, a wait that is not shorter than the remaining budget waits out the budget and throws `TimeoutError` without another attempt (verified: `Retry-After: 10` with `totalTimeout: 300` failed after about 300 ms and one request). An abort of the caller's `signal` ends the wait.

After the wait, a `request` given to `ky.retry()` replaces the request, then the `beforeRetry` hooks run. A hook can:

- cancel the retry by throwing or returning `ky.stop`;
- return a `Request` to send instead (the remaining `beforeRetry` hooks are then skipped);
- return a `Response` to use as-is, without fetching;
- return `{options}` to change `timeout`, `fetch`, `throwHttpErrors`, `onUploadProgress` or `onDownloadProgress` for this and later attempts (since 2.2.0, commit 242c327).

## Rules and pitfalls
- No retry happens when the response is not an error: `throwHttpErrors: false`, or a `throwHttpErrors` function returning `false`, returns the failing response as-is.
- A `Response` returned by a `beforeRequest` or `beforeRetry` hook is used as-is: a failing status throws `HTTPError` without a retry (verified for both hooks).
- Timeouts and dropped connections while `.json()`, `.text()` or another shortcut reads the body are not retried, because the response already arrived (readme, "retryOnTimeout" and "NetworkError").
- Stopping retries from a `beforeRetry` hook: throwing, rethrowing and `ky.stop` reach the caller differently; see the `beforeRetry` gotcha in gotchas.md.
