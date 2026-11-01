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

### 2026-10-21 · Supplier returns (nota retur) are a separate table, not negative purchase-order lines #returns #po @src/returns/ (user)
Why: suppliers send a credit note for a return and match it to the original invoice, not to the PO.
Rejected: negative quantities on `purchase_order_lines` — changes the totals of paid invoices, and the stock ledger can no longer tell a return from a correction.
Revisit if: a supplier wants returns and new goods on one document.

- 2026-09-30 · Freeze `src/payments/settlement/` until the payout audit with the bank is finished; ask before any edit there. #settlement #hold @src/payments/settlement/ (user)
- 2026-09-12 · The settlement job runs at 02:00 WIB and pays out the previous day, because the gateway's report for a day is final only after 01:00. #settlement @src/jobs/queues.ts (user)
- 2026-10-20 · Stock is checked when the sale is saved, not when an item is scanned, because two tablets in one shop scan at the same time and holding stock per scan left items blocked when a sale was abandoned. #stock #sales @src/services/sales.ts (agent, unconfirmed)
- 2026-07-15 · BullMQ on the existing Redis for background jobs, because Redis already runs for sessions and the jobs need retries and a schedule. #jobs @src/jobs/ (user)
- ~~2026-05-20 · Prices are stored with two decimals.~~ superseded 2026-06-02 → see the money Rule in index.md (whole rupiah).
