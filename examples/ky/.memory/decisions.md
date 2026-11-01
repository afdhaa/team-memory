# Decisions

> Why things are the way they are. Newest first. Write so a teammate who missed the discussion
> understands both the decision and the reason behind it.
> One line when the reason fits in one sentence:
> `- YYYY-MM-DD · What was decided, because why. #tag @path/ (source)`
> A block for bigger ones: `### YYYY-MM-DD · What was decided #tag @path/`, one or two sentences
> of context, then `Why:` / `Rejected:` (alternatives and why not) / `Revisit if:`.
> Decisions the agent made on its own carry `(agent, unconfirmed)` on their first line (the `###` title of a
> block) until the user confirms them. Insert new decisions right below this header.
> Add `#hold` to freeze an area: agents must ask before editing files under its @path.
> Never delete reversed decisions — mark them `~~…~~ superseded YYYY-MM-DD → see …`.

- 2026-11-01 · Without a `shouldRetry` override, an error Ky does not recognise (not a `NetworkError`, `TimeoutError`, `HTTPError` or `ForceRetryError`) is thrown at once instead of retried. The code comment gives programming bugs as the example; the readme points to `shouldRetry` for retrying them. Found in a code comment in `#calculateRetryDelay()`, added by pull request 842 (commit eaf0b80, 2026-03-25). #retry @source/core/Ky.ts (agent, unconfirmed)
