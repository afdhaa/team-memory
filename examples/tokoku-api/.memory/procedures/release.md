# Release a new version

**When:** after the pull requests for a release are merged. **Takes:** ~15 minutes. **Needs:** access to Railway and to the GitHub repository.

1. Check that CI on `main` is green.
2. If the release has migrations, run `npx prisma migrate status` against production (`DATABASE_URL` from Railway) and read which ones will run.
3. Bump the version: `npm version minor` (or `patch`), then `git push --follow-tags`.
4. Railway deploys the API and the worker from `main`; wait until both show the new version.
5. Write the release notes on the GitHub release for the new tag, in Indonesian, for shop owners.

**Check it worked:** `GET /health` shows the new version, and the worker log says `worker ready` after the deploy.
**If it fails:** in Railway, roll both services back to the previous deploy. A migration is not rolled back by that: write a new migration that undoes it.
