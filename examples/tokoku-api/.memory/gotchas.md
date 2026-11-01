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

1. **[2026-10-02] Do not send WhatsApp or email to real shops from a local or staging run; use the `NOTIFY_DRY_RUN=1` setting** #notify (user, seen: 2)
   Why: staging uses a copy of production data, and in September 40 shop owners got a test "payout failed" message.
   Do instead: start the worker with `NOTIFY_DRY_RUN=1 npm run worker`; messages are then only logged.

## Build, test & tooling

1. **[2026-09-05] Tests fail with "relation does not exist" after pulling new migrations** #test #prisma @tests/ (agent, seen: 3)
   Why: Vitest uses the `tokoku_test` database, and `npm run db:migrate` only migrates the development database.
   Do instead: run `DATABASE_URL=postgres://localhost/tokoku_test npx prisma migrate deploy` once after pulling.

2. **[2026-10-14] The worker does not pick up code changes while `npm run dev` is running** #jobs @src/jobs/ (agent, seen: 1, unconfirmed)
   Why: `npm run dev` watches only the API; the worker is a separate process started with `npm run worker`.
   Do instead: restart `npm run worker` after changing anything under `src/jobs/` or `src/payments/settlement/`.

## Domain & code behaviour

1. **[2026-09-12] A shop's payout is short by the gateway fee, which is expected** #settlement #payments @src/payments/settlement/calc.ts (user, seen: 4)
   Why: the gateway deducts its fee (0.7% for QRIS, 2.9% for cards) before it pays Tokoku; `calc.ts` passes the fee on to the shop.
   Do instead: when an owner reports a "missing" amount, compare it with the fee line in the payout report before treating it as a bug.

2. **[2026-10-21] A return must cite the supplier's original invoice and is refused after 30 days** #returns @src/returns/rules.ts (user, seen: 1)
   Why: suppliers reject credit notes for older invoices, and the 30 days are in their contracts.
   Do instead: check `canReturn()` in `src/returns/rules.ts` before adding a new kind of return.
