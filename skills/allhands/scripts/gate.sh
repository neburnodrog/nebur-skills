#!/usr/bin/env bash
# Daily gate for the all-hands routine. Exits quietly on the 29 days a month
# that carry no All Hands; on the day, builds the draft before the meeting.
set -uo pipefail

# launchd starts with an almost empty environment. USER decides whether the
# claude CLI finds its keychain credential; without it every run reports
# "Not logged in" and exits 1.
export HOME="${HOME:-/Users/rubenkarlsson}"
export USER="${USER:-rubenkarlsson}"
NODE_BIN="$HOME/.nvm/versions/node/v24.15.0/bin"
export PATH="$NODE_BIN:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

SKILL_DIR="$HOME/.claude/skills/allhands"
LOG="$SKILL_DIR/scripts/logs/gate.log"
VAULT_DIR="$HOME/vault/Areas/Teclead/all-hands"
WORK_DIR="$HOME/Repos"

# Stable across renames of the series; the title is the fallback.
EVENT_ID="cakfcg7b190kqd63so7k4phfi7"
EVENT_TITLE="All Hands @Teclead Ventures"

TODAY="$(date +%Y-%m-%d)"
MONTH="$(date +%Y-%m)"
DRAFT="$VAULT_DIR/allhands-$MONTH.md"

mkdir -p "$(dirname "$LOG")"

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG"; }

notify() {
  local title="$1" body="$2"
  osascript -e "display notification \"${body//\"/\\\"}\" with title \"${title//\"/\\\"}\"" 2>/dev/null || true
}

die() {
  log "FAIL  $*"
  notify "All Hands draft failed" "$*"
  exit 1
}

[ -x "$NODE_BIN/node" ] || die "node not found at $NODE_BIN, update the plist and gate.sh"
command -v claude >/dev/null || die "claude not found on PATH: $PATH"

if [ -f "$DRAFT" ]; then
  log "SKIP  draft already exists: $DRAFT"
  exit 0
fi

CAL_PROMPT="Today is $TODAY. Use the Google Calendar search_events tool to find the recurring event whose recurringEventId starts with \"$EVENT_ID\"; if nothing matches that id, match the exact summary \"$EVENT_TITLE\". Ignore every event whose summary contains \"AfterWork\".

Reply with ONE line and nothing else, no explanation, no code fence:
- An instance starts today: TODAY|<its start as ISO 8601 with offset>|<the date YYYY-MM-DD on which the most recent EARLIER instance started, or NONE>
- No instance starts today: NOT_TODAY
- The tool is unavailable or errors: ERROR|<short reason>"

CAL_OUT="$(claude -p "$CAL_PROMPT" \
  --output-format text \
  --permission-prompts none \
  --allowedTools "mcp__claude_ai_Google_Calendar__search_events" \
  </dev/null 2>>"$LOG" | tr -d '\r' | grep -E '^(TODAY\||NOT_TODAY|ERROR\|)' | head -1)"

case "$CAL_OUT" in
  NOT_TODAY) log "SKIP  no All Hands on $TODAY"; exit 0 ;;
  ERROR*)    die "calendar: ${CAL_OUT#ERROR|}" ;;
  TODAY*)    : ;;
  *)         die "calendar returned nothing usable" ;;
esac

START="$(printf '%s' "$CAL_OUT" | cut -d'|' -f2)"
PREV="$(printf '%s' "$CAL_OUT" | cut -d'|' -f3)"

# BSD date wants +0200, the calendar gives +02:00, so drop the colon from the
# offset before parsing. Falls back to the naive local reading.
iso_epoch() {
  local iso="$1" naive="${1%%[+-]??:??}" off="${1##*[0-9][0-9]:[0-9][0-9]:[0-9][0-9]}"
  if [ -n "$off" ] && [ "$off" != "$iso" ]; then
    date -j -f '%Y-%m-%dT%H:%M:%S%z' "${naive}${off/:/}" '+%s' 2>/dev/null && return
  fi
  date -j -f '%Y-%m-%dT%H:%M:%S' "$naive" '+%s' 2>/dev/null || echo 0
}

start_epoch="$(iso_epoch "$START")"
now_epoch="$(date '+%s')"

if [ "$start_epoch" -gt 0 ] && [ "$now_epoch" -ge "$start_epoch" ]; then
  log "SKIP  All Hands already started at $START"
  notify "All Hands draft skipped" "Meeting already started at $START. Run /allhands by hand."
  exit 0
fi

if [ "$PREV" = "NONE" ] || [ -z "$PREV" ]; then
  PREV="$(date -v-28d +%Y-%m-%d)"
  log "WARN  no previous instance found, falling back to $PREV"
fi

# A run started after 08:00 means launchd caught up late, after a sleep or a
# reboot; the banner says so.
LATE=""
[ "$(date '+%H')" -ge 9 ] && LATE=" (late run)"

log "RUN   All Hands today at $START, period from $PREV"

mkdir -p "$VAULT_DIR"

RUN_OUT="$(cd "$WORK_DIR" && claude -p "/allhands --auto --since $PREV" \
  --output-format text \
  --permission-prompts none \
  --allowedTools Bash Read Write Edit Glob Grep Task TodoWrite \
  </dev/null 2>>"$LOG")"

RESULT="$(printf '%s' "$RUN_OUT" | tr -d '\r' | grep -E '^(OK\||EMPTY)' | tail -1)"

case "$RESULT" in
  EMPTY)
    log "DONE  no commits in period from $PREV"
    notify "All Hands: nothing to report" "No commits since $PREV. Meeting at ${START:11:5}.$LATE"
    ;;
  OK*)
    path="$(printf '%s' "$RESULT" | cut -d'|' -f2)"
    blocks="$(printf '%s' "$RESULT" | cut -d'|' -f3)"
    log "DONE  $path  [$blocks]"
    notify "All Hands draft ready$LATE" "$blocks — meeting ${START:11:5}. $path"
    ;;
  *)
    [ -f "$DRAFT" ] && die "draft written but no OK line; check $DRAFT"
    die "run produced no draft, see $LOG"
    ;;
esac
