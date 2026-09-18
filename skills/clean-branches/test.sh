#!/usr/bin/env bash
# Regression test for clean-branches.sh.
#
# Builds a throwaway repo with a real bare remote covering every case the
# script decides on, runs plan -> apply -> re-run, and asserts each verdict.
# Exits non-zero on the first failure count. The fixture is deleted on pass and
# kept on failure, with its path printed, so a failing case can be poked at.
#
# Usage: test.sh [--keep]

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/clean-branches.sh"
FIXTURE="${TMPDIR:-/tmp}/clean-branches-test.$$"
KEEP=0
[ "${1:-}" = "--keep" ] && KEEP=1

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "PASS $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL $1"; echo "     wanted: $2"; }

# has <file> <label> <regex>
has()  { grep -Eq "$3" "$1" && ok "$2" || bad "$2" "$3"; }
# hasnt <file> <label> <regex>
hasnt() { grep -Eq "$3" "$1" && bad "$2" "no line matching $3" || ok "$2"; }

build() {
  rm -rf "$FIXTURE"; mkdir -p "$FIXTURE"
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  git init -q -b main --bare "$FIXTURE/origin.git"
  git clone -q "$FIXTURE/origin.git" "$FIXTURE/repo" 2>/dev/null
  cd "$FIXTURE/repo"
  git checkout -q -b main 2>/dev/null
  echo ".env" > .gitignore; git add .; git commit -q -m base; git push -q -u origin main

  # squash-merged, and the only thing living in a worktree
  git checkout -q -b feat/auth; echo a > a.txt; git add .; git commit -q -m a
  git push -q -u origin feat/auth
  # unmerged, worktree has uncommitted work
  git checkout -q -b feat/pay main; echo p > p.txt; git add .; git commit -q -m p
  # merged via merge commit
  git checkout -q -b chore/deps main; echo d > d.txt; git add .; git commit -q -m d
  # unmerged, never pushed
  git checkout -q -b spike/idea main; echo s > s.txt; git add .; git commit -q -m s
  # merged, lives in a worktree whose directory gets deleted
  git checkout -q -b wt-gone-br main
  # unmerged upstream, local tip behind it
  git checkout -q -b ff/live main; echo f > f.txt; git add .; git commit -q -m f
  git push -q -u origin ff/live; git reset -q --hard HEAD~1
  # merged locally but upstream moved on: must fast-forward, not delete
  git checkout -q -b stale/tip main; git push -q -u origin stale/tip
  echo t > t.txt; git add .; git commit -q -m "later work on stale/tip"; git push -q origin stale/tip
  git reset -q --hard HEAD~1
  # squash-merged and clean, but its worktree holds a gitignored file
  git checkout -q -b feat/cache main; echo c > c.txt; git add .; git commit -q -m c
  git push -q -u origin feat/cache
  # protected by name, and merged, so only the name can save it
  git checkout -q -b staging main

  git checkout -q main
  git merge -q --squash feat/auth; git commit -q -m "squash feat/auth (#1)"
  git merge -q --squash feat/cache; git commit -q -m "squash feat/cache (#2)"
  git merge -q --no-ff chore/deps -m "merge chore/deps"
  git push -q origin main

  git worktree add -q "$FIXTURE/wt-auth" feat/auth
  git worktree add -q "$FIXTURE/wt-pay"  feat/pay
  echo scratch > "$FIXTURE/wt-pay/scratch.txt"
  git worktree add -q "$FIXTURE/wt-gone" wt-gone-br
  rm -rf "$FIXTURE/wt-gone"
  git worktree add -q "$FIXTURE/wt-cache" feat/cache
  echo "SECRET=1" > "$FIXTURE/wt-cache/.env"
  git worktree add -q --detach "$FIXTURE/wt-detached" main

  # main falls behind origin
  git clone -q "$FIXTURE/origin.git" "$FIXTURE/other" 2>/dev/null
  git -C "$FIXTURE/other" commit -q --allow-empty -m remote-extra
  git -C "$FIXTURE/other" push -q origin main

  git fetch -q --all --prune
}

build

P="$FIXTURE/plan.out"; A="$FIXTURE/apply.out"; R="$FIXTURE/rerun.out"
bash "$SCRIPT" > "$P" 2>&1

echo "--- plan"
has  "$P" "plan: default branch detected"             '^DEFAULT main$'
has  "$P" "plan: mode reported"                       '^MODE plan$'
has  "$P" "plan: squash-merged worktree marked remove" '^WT remove wt-auth feat/auth merged:squash clean$'
has  "$P" "plan: vanished worktree dir marked prune"  '^WT prune wt-gone wt-gone-br missing-dir$'
has  "$P" "plan: dirty worktree kept"                 '^WT keep wt-pay feat/pay (no-proof|uncommitted)$'
has  "$P" "plan: detached worktree kept"              '^WT keep wt-detached - detached$'
has  "$P" "plan: merge-commit branch marked delete"   '^BR delete chore/deps merged:ancestor was:[0-9a-f]+$'
has  "$P" "plan: squash branch marked delete"         '^BR delete feat/auth merged:squash was:[0-9a-f]+$'
has  "$P" "plan: freed worktree branch marked delete" '^BR delete wt-gone-br merged:ancestor was:[0-9a-f]+$'
has  "$P" "plan: unmerged local-only branch kept"     '^BR keep spike/idea no-proof no-upstream$'
has  "$P" "plan: held worktree branch kept"           '^BR keep feat/pay other-worktree'
has  "$P" "plan: branch behind live upstream gets ff" '^BR ff ff/live 1-behind$'
has  "$P" "plan: stale tip under live upstream ff"    '^BR ff stale/tip 1-behind$'
hasnt "$P" "plan: stale tip is never deleted"         '^BR delete stale/tip'
has  "$P" "plan: behind default branch gets ff"       '^BR ff main 1-behind$'
has  "$P" "plan: worktree with ignored files kept"     '^WT keep wt-cache feat/cache ignored-files:1$'
hasnt "$P" "plan: worktree with ignored files not removed" '^WT remove wt-cache'
has  "$P" "plan: its branch kept, worktree holds it"  '^BR keep feat/cache other-worktree'
has  "$P" "plan: protected name survives proof"       '^BR keep staging protected'
hasnt "$P" "plan: protected name never deleted"       '^BR delete staging'
has  "$P" "plan: nothing was applied"                 '^PLAN .* Re-run with --apply\.$'
[ -d "$FIXTURE/wt-auth" ] && ok "plan: changed nothing on disk" || bad "plan: changed nothing on disk" "wt-auth still present"

echo "--- apply"
bash "$SCRIPT" --apply > "$A" 2>&1
has  "$A" "apply: worktree removed"                   '^WT removed wt-auth feat/auth merged:squash clean$'
has  "$A" "apply: vanished worktree pruned"           '^WT pruned wt-gone wt-gone-br missing-dir$'
has  "$A" "apply: squash branch deleted"              '^BR deleted feat/auth merged:squash was:[0-9a-f]+$'
has  "$A" "apply: freed worktree branch deleted"      '^BR deleted wt-gone-br merged:ancestor was:[0-9a-f]+$'
hasnt "$A" "apply: no delete reported as failed"      'delete-failed|ff-failed|remove-failed'
hasnt "$A" "apply: worktree with ignored files survives" '^WT removed wt-cache'
[ -f "$FIXTURE/wt-cache/.env" ] && ok "apply: ignored .env still on disk" \
  || bad "apply: ignored .env still on disk" "$FIXTURE/wt-cache/.env is gone"
[ ! -d "$FIXTURE/wt-auth" ] && ok "apply: worktree gone from disk" || bad "apply: worktree gone from disk" "wt-auth removed"
[ -f "$FIXTURE/wt-pay/scratch.txt" ] && ok "apply: dirty worktree untouched" || bad "apply: dirty worktree untouched" "scratch.txt kept"
git show-ref --verify --quiet refs/heads/spike/idea && ok "apply: unmerged branch survives" || bad "apply: unmerged branch survives" "spike/idea kept"
[ "$(git rev-parse main)" = "$(git rev-parse origin/main)" ] && ok "apply: main fast-forwarded" || bad "apply: main fast-forwarded" "main == origin/main"
[ "$(git rev-parse stale/tip)" = "$(git rev-parse origin/stale/tip)" ] && ok "apply: stale tip fast-forwarded" || bad "apply: stale tip fast-forwarded" "stale/tip == origin/stale/tip"

echo "--- re-run"
bash "$SCRIPT" > "$R" 2>&1
has  "$R" "rerun: no work left"                       '^PLAN 0 worktrees, 0 branches, 0 fast-forwards\.'
hasnt "$R" "rerun: nothing marked for deletion"       '^BR delete '

echo "--- guards"
echo junk > junk.txt
bash "$SCRIPT" > "$FIXTURE/dirty.out" 2>&1
[ $? = 1 ] && ok "guard: dirty tree exits 1" || bad "guard: dirty tree exits 1" "exit 1"
has "$FIXTURE/dirty.out" "guard: dirty tree explained" '^ERROR working tree has uncommitted changes'
rm junk.txt

cd "${TMPDIR:-/tmp}"
if [ $FAIL = 0 ] && [ $KEEP = 0 ]; then
  rm -rf "$FIXTURE"
else
  echo "fixture kept at $FIXTURE"
fi

echo "$PASS passed, $FAIL failed"
[ $FAIL = 0 ]
