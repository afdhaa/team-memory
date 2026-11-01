# Progress

> Your own work state (gitignored, not shared). Rewrite it (don't append) at the end of each task,
> so that you or your agent picking up the work tomorrow knows where things stand. Per item: one sentence on what it is and why it matters,
> then the next concrete step — or what it is waiting on, and who. Delete items that are no longer true.

_Last updated: 2026-10-28_

## In progress
- Supplier returns (nota retur): the `returns` table, `createReturn()` and its stock movements are done and tested in `tests/returns/create-return.test.ts`. Next: `POST /returns` in `src/routes/returns.ts`, then the PDF for the supplier. Not committed yet (branch `feat/returns`).

## Next
- Show returns in the owner's stock history, labelled "retur", so owners do not read them as theft.

## Blocked / waiting on
- Whether a return can be cancelled after the supplier has accepted it — waiting for Rina (product).

## Done recently
- 30-day limit and invoice check for returns in `src/returns/rules.ts`.
- Fixed the double stock movement when a sale was saved twice from a slow tablet.
