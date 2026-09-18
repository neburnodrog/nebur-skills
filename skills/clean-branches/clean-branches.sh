#!/usr/bin/env bash
# Branch and worktree cleanup for any git repo.
#
# Deletion runs on PROOF: a branch is removed only when its content is already
# in the remote default branch, either as an ancestor (merge/rebase) or as an
# identical tree already applied (squash merge). No proof, no delete. That is
# what licenses `git branch -D` here, and it is the only place -D is used.
#
# A worktree is removed only when git calls it clean AND it holds no ignored
# files. `git status --porcelain` hides ignored files, so without that second
# check a removal takes .env, local databases and caches down with it.
#
# Usage: clean-branches.sh [--apply]
#   (no args)  assess and print the plan; touches no branch, worktree or file,
#              but does refresh remote-tracking refs (see the fetch below)
#   --apply    carry the plan out
#
# Output is one line per item, all fields tab-free and greppable:
#   WT  <verb> <path>   <branch> <reasons>
#   BR  <verb> <branch> <reasons>
# Verbs: remove/removed, delete/deleted, ff, keep/kept.
#
# Never deleted, whatever the proof says: the checked-out branch, the remote
# default branch, and the conventional long-lived names in PROTECTED_NAMES.
# That list exists for branches passing the merge check by accident, such as a
# `prod` still identical to `main` just after a fork.

set -uo pipefail

PROTECTED_NAMES="main master develop dev prod production staging release"

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

git rev-parse --git-dir >/dev/null 2>&1 || { echo "ERROR not a git repo"; exit 1; }

if [ -n "$(git status --porcelain)" ]; then
  echo "DIRTY yes"
  echo "ERROR working tree has uncommitted changes; commit or stash first"
  exit 1
fi
echo "DIRTY no"

# Stale origin/* refs make every merge check below read a deleted branch, so
# this runs in plan mode too. It rewrites refs/remotes/*, dropping tracking refs
# for branches already deleted on the remote. Nothing local is touched.
git fetch --all --prune --quiet 2>/dev/null

git remote set-head origin -a >/dev/null 2>&1
DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||')
if [ -z "$DEFAULT" ]; then
  for c in main master; do
    git show-ref --verify --quiet "refs/remotes/origin/$c" && DEFAULT=$c && break
  done
fi
[ -z "$DEFAULT" ] && { echo "ERROR cannot determine default branch; set origin/HEAD"; exit 1; }
BASE="origin/$DEFAULT"
CURRENT=$(git branch --show-current)
echo "DEFAULT $DEFAULT"
echo "MODE $([ $APPLY = 1 ] && echo apply || echo plan)"

protected() {
  case " $PROTECTED_NAMES $DEFAULT $CURRENT " in *" $1 "*) return 0;; esac
  return 1
}

# Echoes the kind of proof found, or nothing.
proof() {
  if git merge-base --is-ancestor "$1" "$BASE" 2>/dev/null; then
    echo "merged:ancestor"; return 0
  fi
  local mb tmp
  mb=$(git merge-base "$BASE" "$1" 2>/dev/null) || return 1
  tmp=$(git commit-tree "$1^{tree}" -p "$mb" -m _ 2>/dev/null) || return 1
  if git cherry "$BASE" "$tmp" 2>/dev/null | grep -q '^-'; then
    echo "merged:squash"; return 0
  fi
  return 1
}

# "<path>\t<branch>" per worktree, blank branch when detached. Paths may
# contain spaces, so this parses the porcelain stream rather than splitting.
wt_list() {
  local line path="" branch=""
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) path=${line#worktree }; branch="" ;;
      "branch refs/heads/"*) branch=${line#branch refs/heads/} ;;
      "") [ -n "$path" ] && printf '%s\t%s\n' "$path" "$branch"; path=""; branch="" ;;
    esac
  done < <(git worktree list --porcelain; echo)
}

MAIN_WT=$(wt_list | head -1 | cut -f1)
WT_PARENT=$(dirname "$MAIN_WT")
short() { local p=${1#$WT_PARENT/}; echo "$p"; }

# --- worktrees -------------------------------------------------------------
# Runs before branch deletion on purpose: git refuses to delete a branch that a
# worktree holds, so removing the worktree is what frees it.

FREED=""   # branches whose worktree is gone or going, so deletable below
WT_N=0
while IFS=$'\t' read -r path branch; do
  [ -z "$path" ] && continue
  [ "$path" = "$MAIN_WT" ] && continue
  if [ ! -d "$path" ]; then
    # The directory is gone; the registration is all that is left.
    [ -n "$branch" ] && FREED="$FREED $branch"
    WT_N=$((WT_N+1))
    echo "WT $([ $APPLY = 1 ] && echo pruned || echo prune) $(short "$path") ${branch:--} missing-dir"
    continue
  fi
  if [ -z "$branch" ]; then
    echo "WT keep $(short "$path") - detached"; continue
  fi
  if protected "$branch"; then
    echo "WT keep $(short "$path") $branch protected"; continue
  fi
  why=$(proof "$branch") || { echo "WT keep $(short "$path") $branch no-proof"; continue; }
  if [ -n "$(git -C "$path" status --porcelain 2>/dev/null)" ]; then
    echo "WT keep $(short "$path") $branch uncommitted"; continue
  fi
  # git worktree remove deletes ignored files without complaint, and status
  # above does not list them. Count them and keep the worktree if there are any.
  ign=$(git -C "$path" clean -ndX 2>/dev/null | wc -l | tr -d ' ')
  if [ "${ign:-0}" != 0 ]; then
    echo "WT keep $(short "$path") $branch ignored-files:$ign"; continue
  fi
  up=$(git rev-parse --abbrev-ref "$branch@{u}" 2>/dev/null)
  if [ -n "$up" ] && [ -n "$(git rev-list "$up..$branch" 2>/dev/null)" ]; then
    echo "WT keep $(short "$path") $branch unpushed"; continue
  fi
  FREED="$FREED $branch"
  WT_N=$((WT_N+1))
  if [ $APPLY = 1 ]; then
    if git worktree remove "$path" 2>/dev/null; then echo "WT removed $(short "$path") $branch $why clean"
    else echo "WT keep $(short "$path") $branch remove-failed"; WT_N=$((WT_N-1)); FREED=${FREED% $branch}; fi
  else
    echo "WT remove $(short "$path") $branch $why clean"
  fi
done < <(wt_list)

# Clears registrations for vanished directories, which is what frees their
# branches for the pass below. --expire=now overrides the 3-month default that
# otherwise makes this a silent no-op.
[ $APPLY = 1 ] && git worktree prune --expire=now >/dev/null 2>&1

# --- branches --------------------------------------------------------------

HELD=""   # branches a worktree still holds after the pass above
while IFS=$'\t' read -r path branch; do
  [ -z "$branch" ] && continue
  [ "$path" = "$MAIN_WT" ] && continue   # this repo's own checkout is $CURRENT, not a foreign hold
  case " $FREED " in *" $branch "*) continue;; esac
  HELD="$HELD $branch"
done < <(wt_list)

BR_N=0; FF_N=0
while IFS= read -r b; do
  up=$(git rev-parse --abbrev-ref --symbolic-full-name "$b@{u}" 2>/dev/null)
  behind=0; ahead=0
  if [ -n "$up" ]; then
    behind=$(git rev-list --count "$b..$up" 2>/dev/null || echo 0)
    ahead=$(git rev-list --count "$up..$b" 2>/dev/null || echo 0)
  fi

  held=0
  case " $HELD " in *" $b "*) held=1;; esac

  # Proof beats everything except protection, a live upstream, and a worktree.
  if ! protected "$b" && [ $held = 0 ]; then
    if why=$(proof "$b"); then
      # A local tip can be an ancestor of the default branch while the upstream
      # has since gained unmerged work. Fast-forward that, do not delete it.
      if [ -n "$up" ] && [ "$behind" -gt 0 ] && ! proof "$up" >/dev/null; then
        why=""
      fi
      if [ -n "$why" ]; then
        if [ $APPLY = 1 ]; then
          # Captured before the delete: recovery is `git branch <name> <sha>`.
          sha=$(git rev-parse --short "$b" 2>/dev/null)
          if git branch -d "$b" >/dev/null 2>&1 || git branch -D "$b" >/dev/null 2>&1; then
            BR_N=$((BR_N+1)); echo "BR deleted $b $why was:$sha"
          else
            echo "BR keep $b delete-failed"
          fi
        else
          BR_N=$((BR_N+1)); echo "BR delete $b $why was:$(git rev-parse --short "$b")"
        fi
        continue
      fi
    fi
  fi

  tags=""
  protected "$b" && tags="protected"
  [ $held = 1 ] && tags="${tags:+$tags }other-worktree"

  if [ -z "$up" ]; then echo "BR keep $b ${tags:+$tags }no-proof no-upstream"; continue; fi
  if [ "$behind" = 0 ]; then echo "BR keep $b ${tags:+$tags }up-to-date"; continue; fi
  if [ "$ahead" -gt 0 ]; then echo "BR keep $b ${tags:+$tags }diverged +$ahead/-$behind"; continue; fi
  if [ $held = 1 ]; then echo "BR keep $b other-worktree $behind-behind"; continue; fi

  if [ $APPLY = 1 ]; then
    if [ "$b" = "$CURRENT" ]; then git merge --ff-only "$up" >/dev/null 2>&1
    else git fetch . "$up:$b" >/dev/null 2>&1; fi
    if [ $? = 0 ]; then FF_N=$((FF_N+1)); echo "BR ff $b -> $(git rev-parse --short "$b")"
    else echo "BR keep $b ff-failed"; fi
  else
    FF_N=$((FF_N+1)); echo "BR ff $b $behind-behind"
  fi
done < <(git branch --format='%(refname:short)')

if [ $APPLY = 1 ]; then
  echo "DONE $WT_N worktrees, $BR_N branches, $FF_N fast-forwards"
else
  echo "PLAN $WT_N worktrees, $BR_N branches, $FF_N fast-forwards. Re-run with --apply."
fi
