#!/usr/bin/env bash
# Recall benchmark: how often the prompt hook brings up the memory line that answers a developer's
# message. Queries (queries.tsv) were written by someone who did not read the search code, against
# the memory in examples/ky and examples/tokoku-api.
#   bash bench/recall/run.sh [-v] [--tune|--holdout] [--min=80] [--min-quiet=70]
#   -v: list every miss; --tune / --holdout: odd / even rows only; --min / --min-quiet: exit 1 when recall@5 /
#   quiet falls below that percentage (CI runs it this way, so a change that makes recall worse fails)
# Scores: hit@1 (the answer is the first line recalled), recall@5 (among the lines recalled; the hook
# shows at most PM_RECALL_MAX, default 5), MRR, and for questions memory cannot answer the share that
# recalled nothing (a quiet hook is right there). A gotcha's Why/Do lines count as its title line.
set -u
export LC_ALL=C PM_UPDATE_CHECK=off PM_HOOKS=on
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SRC="$(cd "$HERE/../.." && pwd)"
V=""; SPLIT=all
MIN=0; MINQ=0; QSET=queries.tsv   # --set=queries2.tsv: the second set (written later, never used for tuning)
for a in "$@"; do case "$a" in -v) V=1 ;; --tune) SPLIT=odd ;; --holdout) SPLIT=even ;; --min=*) MIN="${a#--min=}" ;; --min-quiet=*) MINQ="${a#--min-quiet=}" ;; --set=*) QSET="${a#--set=}" ;; esac; done   # tune on odd rows, check on even ones
TMP="$(mktemp -d 2>/dev/null || mktemp -d -t recall)"; trap 'rm -rf "$TMP"' EXIT
export PM_USER_MEMORY="$TMP/none.md" TMPDIR="$TMP"
for p in ky tokoku-api; do mkdir -p "$TMP/$p" && cp -R "$SRC/examples/$p/.memory" "$TMP/$p/" && rm -f "$TMP/$p/.memory/inbox.md"; done
i=0
tail -n +2 "$HERE/$QSET" | awk -v s="$SPLIT" 's == "all" || (s == "odd" && NR % 2) || (s == "even" && !(NR % 2))' | while IFS=$'\t' read -r proj q file needle kind; do
  i=$((i + 1)); R="$TMP/$proj"
  # the line that answers it, or the entry it belongs to (a gotcha's Why/Do lines, a decision block's lines)
  want="-"
  if [ "$file" != - ]; then
    n="$(grep -nF -- "$needle" "$R/.memory/$file" | head -n1 | cut -d: -f1)"
    want="$(awk -v n="$n" 'NR <= n && /^([-*] |[0-9]+\. |### )/ { s = NR } NR <= n && /^[^ \t]/ && !/^([-*] |[0-9]+\. |### |Why:|Rejected:|Revisit if:)/ { s = NR }
      NR == n { print (s ? s : n); exit }' "$R/.memory/$file")"
    want=".memory/$file:$want"
  fi
  out="$(printf '{"session_id":"bench-%s","cwd":"%s","prompt":"%s"}' "$i" "$R" "$(printf '%s' "$q" | sed 's/\\/\\\\/g; s/"/\\"/g')" |
    bash "$SRC/hooks/pm-hook.sh" prompt claude)"
  got="$(printf '%s' "$out" | grep -oE '\.memory/[^ :"]+:[0-9]+:' | sed 's/:$//' | awk '!s[$0]++')"
  chars="$(printf '%s' "$out" | sed -n 's/.*"additionalContext":"\(.*\)"}}$/\1/p' | wc -c | tr -d ' ')"
  rank=0; k=0
  for g in $got; do k=$((k + 1)); [ "$g" = "$want" ] && { rank=$k; break; }; done
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$proj" "$kind" "$rank" "$(printf '%s\n' "$got" | grep -c .)" "$want" "$q" "${chars:-0}"
done > "$TMP/results.tsv"
awk -F'\t' -v v="$V" -v min="$MIN" -v minq="$MINQ" '
  { if ($2 == "negative") { neg++; if ($4 == 0) quiet++; else if (v) miss[++m] = "  recalled " $4 " line(s) for an unanswerable question: " $6; next }
    n++; K[$2]++; if ($3 == 1) { h1++; H1[$2]++ } if ($3 >= 1) { r5++; R5[$2]++; mrr += 1 / $3 } else if (v) miss[++m] = "  missed [" $2 "] " $5 " ← " $6
    P[$1]++; if ($3 >= 1) PR[$1]++; lines += $4; ch += $7 }
  END {
    printf "Recall benchmark: %d questions with an answer in memory, %d without\n\n", n, neg
    printf "  hit@1     %5.1f%%   (the answer is the first line recalled)\n", 100 * h1 / n
    printf "  recall@5  %5.1f%%   (the answer is among the lines recalled)\n", 100 * r5 / n
    printf "  MRR       %6.3f\n", mrr / n
    printf "  quiet     %5.1f%%   (no line recalled for a question memory cannot answer)\n", 100 * quiet / neg
    printf "  cost      %4.1f lines, %d characters (~%d tokens) added to an answerable prompt on average\n\n", lines / n, ch / n, ch / n / 4
    printf "  by kind:"; for (k in K) printf "  %s %d/%d", k, R5[k], K[k]; printf "\n"
    printf "  by project:"; for (p in P) printf "  %s %d/%d", p, PR[p], P[p]; printf "\n"
    if (v && m) { print "\nMisses:"; for (i = 1; i <= m; i++) print miss[i] }
    if (100 * r5 / n < min || 100 * quiet / neg < minq) { printf "\n✗ below the minimum (recall@5 %s%%, quiet %s%%)\n", min, minq; exit 1 } }' "$TMP/results.tsv"
