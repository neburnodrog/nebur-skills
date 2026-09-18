#!/usr/bin/env bash
# Finds repos under ~/Repos/work with own commits in the period.
# One line per repo:  <commits>|<repo-path-relative>|<group>|<last-commit>
set -uo pipefail

WEEKS="${1:-4}"
ROOT="${2:-$HOME/Repos/work}"
SINCE="$(date -v-$((WEEKS * 7))d +%Y-%m-%d 2>/dev/null || date -d "-$((WEEKS * 7)) days" +%Y-%m-%d)"

# Every git identity Ruben commits under: Teclead mail, E.ON id, GitHub noreply,
# the "Nebur" alias and the "Karlsson, Ruben" spelling the E.ON tooling writes.
ME='Ruben Karlsson\|Karlsson, Ruben\|ruben.karlsson\|rubenkarlsson\|R45792\|Nebur'

echo "# Period from $SINCE"

count() { sed '/^$/d' | sort -u | wc -l | tr -d ' '; }

# -type d skips linked worktrees, whose .git is a file, so their commits are
# counted once against the main repo.
find "$ROOT" -maxdepth 4 -name .git -type d 2>/dev/null | while read -r gitdir; do
  repo="$(dirname "$gitdir")"
  rel="${repo#$ROOT/}"

  own=$(git -C "$repo" log --all --since="$SINCE" --author="$ME" --pretty=%H 2>/dev/null || true)
  co=$(git -C "$repo" log --all --since="$SINCE" --grep="Co-Authored-By:.*$ME" --pretty=%H 2>/dev/null || true)
  n=$(printf '%s\n%s\n' "$own" "$co" | count)

  [ "${n:-0}" -gt 0 ] 2>/dev/null || continue

  last=$(git -C "$repo" log --all --since="$SINCE" --author="$ME" -1 --pretty=%ad --date=short 2>/dev/null || true)
  printf '%s|%s|%s|%s\n' "$n" "$rel" "${rel%%/*}" "$last"
done | sort -t'|' -k1,1 -rn
