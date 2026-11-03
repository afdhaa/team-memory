#!/usr/bin/env bash
# team-memory import — run through `mem.sh import`, which passes the project root.
#   bash import.sh <root> [--write]
# Finds notes the project already keeps for people or agents and turns them into memory:
# - ADRs (docs/adr/, docs/decisions/, adr/ …): one decision each, pointing to the ADR → decisions.md
# - agent instructions and other tools' memory (CLAUDE.md, AGENTS.md outside the team-memory block,
#   GEMINI.md, .cursor/rules, .cursorrules, .clinerules, .windsurfrules, .github/copilot-instructions.md,
#   Cline's memory-bank/, Serena's .serena/memories/, .agent-memory/, .context/memory/, decisions.md):
#   each bullet becomes a candidate in .memory/inbox.md, marked rule / decision / gotcha / fact, with its
#   file and line. The agent rewrites the ones worth keeping as entries and asks before moving anything
#   out of an instruction file that agents still read.
# Without --write it only shows what it would do. Lines already in memory are skipped. Nothing is
# deleted or changed outside .memory/.
set -u
export LC_ALL=C
ROOT="$1"; shift
cd "$ROOT" || exit 1
WRITE=""; [ "${1:-}" = --write ] && WRITE=1
TODAY="$(date +%Y-%m-%d)"
[ -d .memory ] || { echo "No .memory/ here: run mem.sh scan first."; exit 1; }
MAXC="${PM_IMPORT_MAX:-80}"

# ---- ADRs: one decision line each ----
ADRS="$(for d in docs/adr docs/adrs docs/ADR doc/adr adr adrs docs/decisions docs/architecture/decisions architecture/decisions decisions; do
  [ -d "$d" ] && find "$d" -maxdepth 2 -type f -name '*.md' ! -iname 'readme.md' ! -iname 'index.md' ! -iname 'template*.md' ! -name '0000-*' 2>/dev/null; done | sort -u)"
ADR_LINES=""; nadr=0; nadr_skip=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  grep -qF "$f" .memory/decisions.md 2>/dev/null && { nadr_skip=$((nadr_skip + 1)); continue; }   # imported before
  line="$(awk -v f="$f" -v today="$TODAY" '
    function trim(t) { sub(/^[ \t]+/, "", t); sub(/[ \t]+$/, "", t); return t }
    !title && /^# / { title = substr($0, 3); next }
    /^[Ss]tatus:/ { st = $0; sub(/^[Ss]tatus:[ \t]*/, "", st) }
    /^#+ +[Ss]tatus/ { want = 1; next }
    want && /[^ \t]/ { if (st == "") st = $0; want = 0 }
    /^[Dd]ate:/ && !dt { dt = $0; sub(/^[Dd]ate:[ \t]*/, "", dt) }
    !dt && match($0, /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]/) { dt = substr($0, RSTART, 10) }
    END {
      if (title == "") { title = f; sub(/.*\//, "", title); sub(/\.md$/, "", title); gsub(/[-_]/, " ", title) }
      title = trim(title); sub(/^(ADR|adr)[- ]?[0-9]+[.:]?[ \t]*/, "", title); sub(/^[0-9]+[.:][ \t]*/, "", title)
      st = trim(st); gsub(/[*_`]/, "", st); st = tolower(st); sub(/[ .].*/, "", st)
      num = f; sub(/.*\//, "", num); n = ""; if (match(num, /^[0-9]+/)) n = " " substr(num, RSTART, RLENGTH)
      info = "ADR" n (st != "" ? ", " st : "") (dt != "" ? ", " dt : "")
      text = title " (" info "); see `" f "`."
      if (st ~ /^(superseded|deprecated|rejected|replaced)/) print "- ~~" today " · " text "~~ " st " (the ADR says so). #adr @" f " (user, from " f ")"
      else print "- " today " · " text " #adr @" f " (user, from " f ")" }' "$f")"
  ADR_LINES="$ADR_LINES$line"$'\n'; nadr=$((nadr + 1))
done <<EOF
$ADRS
EOF

# ---- instruction files and other tools' memory: bullets as candidates ----
SRCS=""
add() { for f in "$@"; do [ -f "$f" ] && [ ! -L "$f" ] && SRCS="$SRCS$f"$'\n'; done; }
add CLAUDE.md AGENTS.md GEMINI.md .cursorrules .windsurfrules .github/copilot-instructions.md decisions.md DECISIONS.md docs/decisions.md
[ -f .clinerules ] && add .clinerules
for d in .cursor/rules .clinerules .windsurf/rules memory-bank .serena/memories .context/memory .agent-memory .agent-memory/modules; do
  [ -d "$d" ] && SRCS="$SRCS$(find "$d" -maxdepth 1 -type f \( -name '*.md' -o -name '*.mdc' -o -name '*.txt' \) 2>/dev/null | sort)"$'\n'
done
# memory already here, to skip what is in it (first 50 letters of each line, lower case, letters only)
KNOWN="$( { cat .memory/*.md .memory/topics/*.md .memory/procedures/*.md 2>/dev/null
            sed -n 's/^- imported · [a-z]* · "\(.*\)" — .*/\1/p' .memory/inbox.md 2>/dev/null; } |   # and what an earlier import left in the inbox
          tr 'A-Z' 'a-z' | tr -cd 'a-z\n' | cut -c1-50 | awk 'length >= 20' | sort -u)"
CANDS="$(printf '%s' "$SRCS" | grep . | sort -u | while IFS= read -r f; do
  [ -z "$(grep -vE '^[[:space:]]*(@\.?/?AGENTS\.md[[:space:]]*|#.*|)$' "$f" | grep -v 'team-memory' | head -n 1)" ] && continue   # only imports AGENTS.md
  KNOWN="$KNOWN" awk -v f="$f" '
    BEGIN { n = split(ENVIRON["KNOWN"], K, "\n"); for (i = 1; i <= n; i++) known[K[i]] = 1
      cat = ""; b = tolower(f)   # the file says what its bullets are
      if (b ~ /decision/) cat = "decision"; else if (b ~ /(pitfall|mistake|lesson|gotcha)/) cat = "gotcha"; else if (b ~ /(convention|pattern|rule|style)/) cat = "rule" }
    /<!-- team-memory:start -->/ { tm = 1; next } tm { if (/<!-- team-memory:end -->/) tm = 0; next }
    /^[ \t]*(```|~~~)/ { code = !code; next } code { next }
    /^---[ \t]*$/ && NR == 1 { fm = 1; next } fm { if (/^---[ \t]*$/) fm = 0; next }   # .mdc front matter
    /^[ \t]*([-*+]|[0-9]+\.)[ \t]+/ {
      t = $0; sub(/^[ \t]*([-*+]|[0-9]+\.)[ \t]+/, "", t); sub(/[ \t]+$/, "", t)
      if (length(t) < 25 || length(t) > 1500 || t ~ /^\[[^]]*\]\([^)]*\)$/ || t ~ /^@/) next
      k = tolower(t); gsub(/[^a-z]/, "", k); k = substr(k, 1, 50); if (length(k) >= 20 && (k in known)) next
      l = tolower(t); c = cat
      if (c == "") {
        if (l ~ /(careful|beware|watch out|gotcha|pitfall|caveat|warning|important:|note:|hati-hati|awas|ternyata|breaks|fails|flaky|crash)/) c = "gotcha"
        else if (l ~ /(because|we chose|decided|instead of|karena|memilih|diputuskan)/) c = "decision"
        else if (l ~ /(^|[^a-z])(always|never|must|should|do not|don.t|avoid|use|prefer|may only|may not|not allowed|jangan|selalu|harus|wajib|pakai)([^a-z]|$)/ ||
                 l ~ /^(run|follow|use|keep|add|write|put|make sure|ensure|check|include|name|prefix|place|update)[ :]/) c = "rule"   # "Run `pnpm lint` before …": an instruction
        else c = "fact" }
      gsub(/"/, "\x27", t)
      print "- imported · " c " · \"" t "\" — " f ":" NR }' "$f"
done)"
nc="$(printf '%s' "$CANDS" | grep -c .)"

# ---- report / write ----
echo "team-memory import — $(basename "$(pwd -P)")"
[ -n "$ADRS" ] && echo "• ADRs: $nadr to add to decisions.md${nadr_skip:+, $nadr_skip already there}" | sed 's/, 0 already there//'
if [ -n "$SRCS" ]; then
  echo "• notes in: $(printf '%s' "$SRCS" | grep . | sort -u | tr '\n' ' ')"
  echo "  $nc candidate line(s) ($(printf '%s\n' "$CANDS" | awk -F' · ' 'NF > 2 { c[$2]++ } END { for (k in c) printf "%s%d %s", (n++ ? ", " : ""), c[k], k }'))"
fi
[ "$nadr$nc" = 00 ] && { echo "Nothing to import: no ADRs, agent rule files or other tools' memory found (or all of it is in memory already)."; exit 0; }
if [ -z "$WRITE" ]; then
  echo; echo "Preview:"
  printf '%s' "$ADR_LINES" | head -n 5
  printf '%s\n' "$CANDS" | head -n 10
  [ $((nadr + nc)) -gt 15 ] && echo "…"
  echo; echo "Run again with --write: ADRs go to decisions.md, the other lines to .memory/inbox.md (max $MAXC), for the agent to"
  echo "rewrite as entries. Nothing outside .memory/ is changed."
  exit 0
fi
if [ "$nadr" -gt 0 ]; then
  # new decisions go right below the header (the > lines at the top)
  # (through the environment: BWK awk refuses a -v value with line breaks)
  if ADD="$ADR_LINES" awk 'BEGIN { add = ENVIRON["ADD"] } !done && seenh && !/^>/ { printf "\n%s", add; done = 1 } /^>/ { seenh = 1 } { print } END { if (!done) printf "\n%s", add }' \
      .memory/decisions.md > .memory/decisions.md.tmp && mv .memory/decisions.md.tmp .memory/decisions.md; then
    echo "+ $nadr ADR decision(s) in .memory/decisions.md"
  else rm -f .memory/decisions.md.tmp; echo "✗ could not add the ADRs to .memory/decisions.md" >&2; exit 1; fi
fi
if [ "$nc" -gt 0 ]; then
  [ -f .memory/inbox.md ] || printf '# Inbox\n\n> Captured automatically from user prompts (local, gitignored). Triaged by the agent: record durable items, then delete them.\n\n' > .memory/inbox.md
  printf '%s\n' "$CANDS" | head -n "$MAXC" >> .memory/inbox.md
  echo "+ $([ "$nc" -gt "$MAXC" ] && echo "$MAXC of $nc" || echo "$nc") candidate line(s) in .memory/inbox.md$([ "$nc" -gt "$MAXC" ] && echo " — run again after triage for the rest")"
  echo "Next: ask your agent to \"triage the imported notes\" (it rewrites them as entries with their source and asks before"
  echo "moving anything out of CLAUDE.md, AGENTS.md or rule files that agents still read)."
fi
