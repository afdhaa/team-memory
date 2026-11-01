# Examples

Two complete `.memory/` folders, so you can see what the skill writes before you install it.

## ky — a real project you can check

[`ky/.memory/`](ky/.memory/) is the memory of [sindresorhus/ky](https://github.com/sindresorhus/ky)
at commit [`3541888`](https://github.com/sindresorhus/ky/tree/3541888) (release 2.2.0), written by an
agent that followed this skill in one session: onboarding from the scan, "lengkapi memori" for
`source/core/` and `source/utils/`, and two questions about retries. Open ky at that commit and
check any line against the code.

- **Not written or reviewed by ky's maintainers.** Every entry is the agent's (`agent`), and what it
  only read in the code stays `unconfirmed`. A decision it found in a code comment names the commit.
- **Fact-checked** by a second agent against the code before publishing: 84 claims, none wrong,
  14 reworded to be exact (for example which hooks a `ky.retry()` skips).
- What it shows: the project summary and key facts, how the code fits together, gotchas verified by
  running code (`verified: …`), a topic page (`topics/retries.md`) that answers a question once for
  everyone. Personal files (`progress.md`, `inbox.md`) are not committed, so they are not here.

| File | What to look at |
|---|---|
| [`index.md`](ky/.memory/index.md) | summary, key facts corrected after the scan, map |
| [`topics/codebase.md`](ky/.memory/topics/codebase.md) | how a request flows through `Ky.ts`, one line per folder, the generated facts below |
| [`topics/retries.md`](ky/.memory/topics/retries.md) | the order of the retry checks, how the wait is computed, what is never retried |
| [`gotchas.md`](ky/.memory/gotchas.md) | a build-order surprise in the type tests, and three behaviours of the retry code |
| [`decisions.md`](ky/.memory/decisions.md) | a maintainers' decision found in a code comment, with its pull request |

## tokoku-api — a made-up project

[`tokoku-api/.memory/`](tokoku-api/.memory/) is **fictional**: a till and stock backend for small
shops, after a few weeks of work with a team. It exists to show what a real project's memory holds
that the ky example cannot: entries from the user (`(user)`), a frozen area (`#hold`), a superseded
decision, a glossary of business terms (settlement, PO, nota retur), a release procedure, and the
personal files (`progress.md`, `local.md`, `inbox.md`). The repository facts in its
`topics/codebase.md` come from `mem.sh scan` run on a mock-up of the project.

| File | What to look at |
|---|---|
| [`index.md`](tokoku-api/.memory/index.md) | standing rules with their reason and source |
| [`decisions.md`](tokoku-api/.memory/decisions.md) | a block decision with `Why:` / `Rejected:` / `Revisit if:`, a `#hold`, a superseded entry |
| [`gotchas.md`](tokoku-api/.memory/gotchas.md) | a user directive, tooling surprises, domain rules |
| [`topics/payments.md`](tokoku-api/.memory/topics/payments.md), [`topics/glossary.md`](tokoku-api/.memory/topics/glossary.md) | a topic page and the project's own words |
| [`procedures/release.md`](tokoku-api/.memory/procedures/release.md) | steps with a check and a way back |
| [`progress.md`](tokoku-api/.memory/progress.md), [`local.md`](tokoku-api/.memory/local.md), [`inbox.md`](tokoku-api/.memory/inbox.md) | one developer's personal files (not committed in a real project) |

Try the commands on either folder: copy it into a git repository and run `mem.sh quiz` or `mem.sh lint`.
