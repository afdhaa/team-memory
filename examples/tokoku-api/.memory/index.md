# Project Memory — Index

> Read this file at the start of every task. Keep it under ~150 lines.
> Details live in the files listed in the map below.

## Project summary
Tokoku API is the backend of Tokoku, a till and stock app for small shops in Indonesia. Shop staff
ring up sales on an Android tablet; the owner sees stock, orders goods from suppliers and gets the
day's card and QRIS payments paid out to their bank account the next working day. It is a Node.js
and TypeScript service (Express, Prisma on PostgreSQL, BullMQ jobs on Redis) used by about 300 shops.
Version 2 is in production; the current work is supplier returns.

## Rules & preferences
- Memory language: English.
- Money is an integer number of rupiah (`bigint` in the database, `Money` from `src/lib/money.ts` in code); never a float, because rounding errors show up in the daily payout. #money (user, 2026-06-02)
- Every change to stock goes through `adjustStock()` in `src/stock/adjust.ts`, which writes the ledger row; a direct `UPDATE` on `products.stock` breaks the stock history. @src/stock/ #stock (user, 2026-07-15)
- Database changes are Prisma migrations created with `npm run db:migrate`; never edit a migration that is already on `main`. @prisma/ (user, 2026-05-20)
- Pull requests need one review and a green CI; nobody pushes to `main`. (user, 2026-05-20)
- Changelog: none; release notes are written by hand on the GitHub release. (user, 2026-08-04)

## Key facts
- Stack: TypeScript · Node.js 22 (npm) — Express 5, Prisma 6 on PostgreSQL 17, BullMQ on Redis 7, Zod, Vitest
- Commands: `npm run dev` (API) · `npm run worker` (jobs) · `npm test` · `npm run lint` · `npm run db:migrate`
- Local services: `docker compose up db redis`; seed data: `npm run db:seed`
- Main folders: `src/routes/` (HTTP), `src/payments/`, `src/returns/`, `src/purchase-orders/`, `src/stock/`, `src/jobs/`
- Config: environment variables listed in `.env.example` (4); real values only in local `.env` files and in the hosting dashboard
- Deploy: merge to `main` → Railway builds and deploys the API and the worker (see procedures/release.md)
- More: topics/codebase.md (how the code fits together, project layout, generated facts)

## Map
- progress.md — current status, next steps, blockers
- decisions.md — why things are the way they are
- gotchas.md — mistakes, corrections, surprises
- topics/codebase.md — how the code fits together, what each folder is for, plus generated repo facts: stack, commands, layout, config, CI (refresh: mem.sh scan)
- topics/payments.md — card and QRIS payments, the gateway webhook, the daily settlement job
- topics/glossary.md — what Tokoku's own words mean: settlement, PO, nota retur, member aktif
- procedures/release.md — release a new version to production
