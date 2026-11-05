#!/usr/bin/env bash
# team-memory GitHub Action: one comment on a pull request with the memory entries for the files it
# changes, the frozen (#hold) areas it touches, the entries it adds, and memory lint problems.
#   bash pr-comment.sh [--base <ref>] [--post]
# Run from the repository; MEMORY_PATH (default .) is the folder that holds .memory/. Without --post
# (or without GITHUB_TOKEN and a pull request number) it only prints the comment. Not part of the npm
# package: it runs on GitHub's runners, where it uses curl and jq to talk to the GitHub API.
set -u
export LC_ALL=C
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMSH="$HERE/../scripts/mem.sh"
BASE="${BASE_REF:-}"; POST=""
while [ $# -gt 0 ]; do
  case "$1" in --base) BASE="${2:-}"; shift ;; --post) POST=1 ;; *) echo "pr-comment.sh: unknown option $1" >&2; exit 2 ;; esac; shift
done
cd "${MEMORY_PATH:-.}" || { echo "::error::team-memory: folder ${MEMORY_PATH:-.} not found"; exit 1; }
[ -d .memory ] || { echo "::notice::team-memory: no .memory/ in ${MEMORY_PATH:-.} — nothing to check"; exit 0; }
MARK="<!-- team-memory:pr -->"
REPO="${GITHUB_REPOSITORY:-}"; SHA="${PR_HEAD_SHA:-$(git rev-parse HEAD)}"
PREFIX="$(git rev-parse --show-prefix 2>/dev/null)"   # .memory/ inside a package of a monorepo: links need the folder
link() { # link <.memory/file:line> → markdown link to that line at the PR's head, or plain text outside GitHub
  local f="${1%%:*}" l="${1#*:}"
  if [ -n "$REPO" ]; then printf '[%s](%s/%s/blob/%s/%s%s#L%s)' "${1#.memory/}" "${GITHUB_SERVER_URL:-https://github.com}" "$REPO" "$SHA" "$PREFIX" "$f" "$l"
  else printf '`%s`' "${1#.memory/}"; fi
}

# the base to compare with: the PR's base branch, fetched when the checkout is shallow
[ -n "$BASE" ] || BASE="$(git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo origin/main)"
# a branch name may hold slashes (release/1.x): try origin/<name> first, then the name as given, then fetch it
if git rev-parse -q --verify "origin/$BASE" >/dev/null 2>&1; then BASE="origin/$BASE"
elif ! git rev-parse -q --verify "$BASE" >/dev/null 2>&1; then
  b="${BASE#origin/}"; git fetch -q --no-tags origin "+refs/heads/$b:refs/remotes/origin/$b" 2>/dev/null && BASE="origin/$b"
fi
git rev-parse -q --verify "$BASE" >/dev/null 2>&1 || { echo "::error::team-memory: cannot find the base branch $BASE (use actions/checkout with fetch-depth: 0)"; exit 1; }
MB="$(git merge-base "$BASE" HEAD 2>/dev/null || echo "$BASE")"

CHANGED="$(git diff --name-only --relative "$MB" HEAD -- . 2>/dev/null | grep -v '^\.memory/')"   # all of them: a #hold must never be missed
MEMCH="$(git diff --name-only --relative "$MB" HEAD -- .memory 2>/dev/null)"

# 1) entries for the changed files (mem.sh path), each once, with the files that brought it up
HITS="$(printf '%s\n' "$CHANGED" | grep . | tr '\n' '\0' | xargs -0 bash "$MEMSH" path --tsv 2>/dev/null | awk -F'\t' '{ if (!($1 in n)) o[++c] = $1; n[$1]++; if (n[$1] <= 2) f[$1] = f[$1] (f[$1] != "" ? ", " : "") "`" $2 "`" }
  END { for (i = 1; i <= c; i++) print o[i] "\t" f[o[i]] (n[o[i]] > 2 ? " +" n[o[i]] - 2 " more" : "") }')"
# 1b) lines that name a changed file (or its folder) in `backticks` without an @path: shown too, apart.
#     Left out: the overview in topics/codebase.md and the Key facts, which name every folder.
MENTIONS="$(awk '
  FNR == 1 { gen = 0; inc = 0; skip = (FILENAME ~ /topics\/codebase\.md$/) }
  skip { next }
  /^## / { facts = (FILENAME ~ /index\.md$/ && /^## (Key facts|Map)/) } facts { next }
  /^<!-- scan:start/ { gen = 1; next } gen { if (/^<!-- scan:end/) gen = 0; next }
  /^[ \t]*<!--/ { inc = !/-->/; next } inc { if (/-->/) inc = 0; next }
  /^#|^>/ { next }
  /^([-*] |[0-9]+\. |### )/ || /^[^ \t]/ { start = FNR }   # a Why:/Do instead: line belongs to the entry above it
  { x = $0; while (match(x, /`[A-Za-z0-9_.-]+(\/[A-Za-z0-9_.-]+)+\/?`/)) { w = substr(x, RSTART + 1, RLENGTH - 2); x = substr(x, RSTART + RLENGTH); print FILENAME ":" (start ? start : FNR) "\t" w } }' \
  $(find -H .memory -type f -name '*.md' ! -name README.md ! -name progress.md ! -name inbox.md ! -name local.md 2>/dev/null | sort) /dev/null 2>/dev/null)"
MHITS="$(printf '%s\n' "$CHANGED" | MENTIONS="$MENTIONS" HITS="$HITS" awk '
  BEGIN { n = split(ENVIRON["MENTIONS"], M, "\n"); h = split(ENVIRON["HITS"], H, "\n"); for (i = 1; i <= h; i++) { split(H[i], a, "\t"); done[a[1]] = 1 } }
  NF { f = $0; for (i = 1; i <= n; i++) { split(M[i], a, "\t"); p = a[2]; loc = a[1]; if (loc in done) continue
         q = p; sub(/\/$/, "", q); if (f == q || (p ~ /\/$/ && index(f, p) == 1)) { if (!(loc in c)) o[++k] = loc; if (c[loc]++ < 2) w[loc] = w[loc] (w[loc] != "" ? ", " : "") "`" f "`" } } }
  END { for (i = 1; i <= k && i <= 8; i++) print o[i] "\t" w[o[i]] (c[o[i]] > 2 ? " +" c[o[i]] - 2 " more" : "") }')"

entry() { # the entry text at .memory/file:line, without tags, dates and source
  sed -n "${1#*:}p" "${1%%:*}" | sed -E 's/^([0-9]+\. |- |### )//; s/\*\*//g; s/^\[[0-9-]+\] //; s/^[0-9]{4}-[0-9]{2}-[0-9]{2} · //; s/[[:space:]]+[#@][^[:space:]]+//g; s/[[:space:]]*\((user|agent)[^()]*\)[[:space:]]*$//' |
    awk '{ if (length($0) > 220) { s = substr($0, 1, 220); sub(/[ \t][^ \t]*$/, "", s); print s "…" } else print }'   # cut at a space: never inside a UTF-8 character
}
src() { sed -n "${1#*:}p" "${1%%:*}" | sed -nE 's/.*\(((user|agent)[^()]*)\)[[:space:]]*$/\1/p'; }
fix() { # a gotcha's "Do instead:" line, when the entry has one
  awk -v n="${1#*:}" 'NR > n && /^[^[:space:]]/ { exit } NR > n && /^[[:space:]]+Do instead:/ { sub(/^[[:space:]]+Do instead:[[:space:]]*/, ""); print substr($0, 1, 200); exit }' "${1%%:*}"
}
HOLD=""; NOTE=""; nh=0; nn=0
while IFS=$'\t' read -r loc files; do
  [ -n "$loc" ] || continue
  s="$(src "$loc")"; d="$(fix "$loc")"
  line="- $(entry "$loc") — $(link "$loc")${s:+ ($s)}"$'\n'"  <sub>for $files</sub>"${d:+$'\n'"  Do instead: $d"}
  # at most 30 of each in the comment (GitHub refuses a comment over 65,536 characters); the counts stay whole
  if sed -n "${loc#*:}p" "${loc%%:*}" | grep -q '#hold'; then nh=$((nh + 1)); [ "$nh" -le 30 ] && HOLD="$HOLD$line"$'\n'
  else nn=$((nn + 1)); [ "$nn" -le 30 ] && NOTE="$NOTE$line"$'\n'; fi
done <<HITS_EOF
$HITS
HITS_EOF

MENT=""; nm=0
while IFS=$'\t' read -r loc files; do
  [ -n "$loc" ] || continue
  nm=$((nm + 1)); MENT="$MENT- $(entry "$loc") — $(link "$loc")"$'\n'"  <sub>names $files</sub>"$'\n'
done <<MHITS_EOF
$MHITS
MHITS_EOF

# 2) entries this PR adds to memory
NEW=""; nw=0
for f in $MEMCH; do
  case "$f" in .memory/progress.md|.memory/inbox.md|.memory/local.md) continue ;; esac
  [ -f "$f" ] || continue
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    sed -n "${n}p" "$f" | grep -qE '^([0-9]+\. |- |### )' || continue
    nw=$((nw + 1)); [ "$nw" -le 10 ] && NEW="$NEW- $(entry "$f:$n") — $(link "$f:$n")"$'\n'
  done <<NEW_EOF
$(git diff -U0 "$MB" HEAD -- "$f" | awk '/^@@/ { split($3, a, ","); s = substr(a[1], 2) + 0; k = (a[2] == "") ? 1 : a[2] + 0; for (i = 0; i < k; i++) print s + i }')
NEW_EOF
done
[ "$nw" -gt 10 ] && NEW="$NEW- … and $((nw - 10)) more"$'\n'
[ "$nh" -gt 30 ] && HOLD="$HOLD- … and $((nh - 30)) more frozen area(s): run \`mem.sh path <file>\` for the rest"$'\n'
[ "$nn" -gt 30 ] && NOTE="$NOTE- … and $((nn - 30)) more: run \`mem.sh path <file>\` on the files you change"$'\n'

# 3) memory lint problems (⚠) that concern this PR: a memory line it adds or changes, a file it changes,
#    renames or deletes, or a secret anywhere. Older problems elsewhere are left to the team's own lint run.
ADDED_AT="$(for f in $MEMCH; do git diff -U0 "$MB" HEAD -- "$f" | awk -v f="$f" '/^@@/ { split($3, a, ","); s = substr(a[1], 2) + 0; k = (a[2] == "") ? 1 : a[2] + 0; for (i = 0; i < k; i++) print f ":" s + i }'; done)"
TOUCHED="$(git diff --name-status -M --relative "$MB" HEAD -- . 2>/dev/null | cut -f2- | tr '\t' '\n' | grep -v '^\.memory/')"
LINT="$(bash "$MEMSH" lint 2>/dev/null | grep '^⚠' | ADDED_AT="$ADDED_AT" TOUCHED="$TOUCHED" awk '
  BEGIN { n = split(ENVIRON["ADDED_AT"], A, "\n"); for (i = 1; i <= n; i++) if (A[i] != "") at[A[i]] = 1
          m = split(ENVIRON["TOUCHED"], T, "\n") }
  { keep = ($0 ~ /secret|password|token|private key|possible injected/)
    s = $0; while (!keep && match(s, /\.memory\/[^ :]+:[0-9]+/)) { if (substr(s, RSTART, RLENGTH) in at) keep = 1; s = substr(s, RSTART + RLENGTH) }
    for (i = 1; i <= m && !keep; i++) if (T[i] != "" && index($0, T[i])) keep = 1
    if (keep && k++ < 10) { sub(/^⚠ /, "- "); print } }')"
nl="$(printf '%s' "$LINT" | grep -c .)"

# the comment (its own temp file: two runs on one machine must not mix their text)
BODY="$(mktemp "${TMPDIR:-/tmp}/team-memory-comment.XXXXXX")"; trap 'rm -f "$BODY" "$BODY.full"' EXIT
{
  echo "$MARK"
  echo "### 📝 team-memory"
  if [ "$nh$nn$nm$nw$nl" = "00000" ]; then
    echo "No memory entries point at the files in this pull request, and memory lint found no problems."
  fi
  [ "$nh" -gt 0 ] && { echo; echo "**🔒 Frozen areas touched** — the team asked to be consulted before these change:"; printf '%s' "$HOLD"; }
  [ "$nn" -gt 0 ] && { echo; echo "**Notes for the files in this PR** ($nn):"; printf '%s' "$NOTE"; }
  [ "$nm" -gt 0 ] && { echo; echo "**Memory that names these files** ($nm, without an \`@path\` tag — adding one makes the entry come up on edits too):"; printf '%s' "$MENT"; }
  [ "$nw" -gt 0 ] && { echo; echo "**Added to memory in this PR** ($nw) — review them like code:"; printf '%s' "$NEW"; }
  [ "$nl" -gt 0 ] && { echo; echo "**Memory checks** (\`mem.sh lint\`):"; printf '%s\n' "$LINT"; }
  echo
  echo "<sub>From \`.memory/\` in this repository · [team-memory](https://github.com/afdhaa/team-memory)</sub>"
} > "$BODY"
# a last guard on GitHub's comment limit (characters; counted here in bytes, which is stricter)
if [ "$(wc -c < "$BODY")" -gt 60000 ]; then
  { head -c 59000 "$BODY" | awk 'NR > 1 { print prev } { prev = $0 }'; echo; echo "… (cut to fit GitHub's comment limit; the job summary has the whole text)"; } > "$BODY.cut"
  cp "$BODY" "$BODY.full"; mv "$BODY.cut" "$BODY"
fi
SUM="$BODY"; [ -f "$BODY.full" ] && SUM="$BODY.full"   # the job summary keeps the whole text
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && cat "$SUM" >> "$GITHUB_STEP_SUMMARY"
[ -n "${GITHUB_OUTPUT:-}" ] && printf 'entries=%s\nholds=%s\nadded=%s\nlint=%s\n' "$((nn + nm))" "$nh" "$nw" "$nl" >> "$GITHUB_OUTPUT"

# post or update the one comment (found by its marker)
PR="${PR_NUMBER:-}"
if [ -z "$POST" ] || [ -z "${GITHUB_TOKEN:-}" ] || [ -z "$PR" ] || [ -z "$REPO" ]; then cat "$BODY"
else
  command -v jq >/dev/null 2>&1 || { echo "::warning::team-memory: jq is not installed on this runner, so the comment cannot be posted; see the job summary"; exit 0; }
  API="${GITHUB_API_URL:-https://api.github.com}/repos/$REPO"
  gh_api() { curl -fsS -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "$@"; }
  quiet=""; [ "$nh$nn$nm$nw$nl" = "00000" ] && [ "${COMMENT_WHEN_EMPTY:-false}" != true ] && quiet=1
  id="$(gh_api "$API/issues/$PR/comments?per_page=100" 2>/dev/null | jq -r --arg m "$MARK" '[.[] | select(.body | startswith($m))] | last | .id // empty')"
  payload="$(jq -Rs '{body: .}' < "$BODY")"
  if [ -n "$id" ]; then gh_api -X PATCH "$API/issues/comments/$id" -d "$payload" >/dev/null && echo "team-memory: updated comment $id on #$PR" ||
      echo "::warning::team-memory: could not update the comment (a pull request from a fork gets a read-only token); see the job summary"
  elif [ -z "$quiet" ]; then gh_api -X POST "$API/issues/$PR/comments" -d "$payload" >/dev/null && echo "team-memory: commented on #$PR" ||
      echo "::warning::team-memory: could not comment (a pull request from a fork gets a read-only token); see the job summary"
  else echo "team-memory: nothing applies to this pull request; no comment"; fi
fi
[ "${FAIL_ON_LINT:-false}" = true ] && [ "$nl" -gt 0 ] && { echo "::error::team-memory: memory lint found $nl problem(s)"; exit 1; }
exit 0
