---
name: personal-clone
description: Create a private GitHub repo under the user's account from the current local repo, add it as the "personal" remote, and push the default branch.
user_invocable: true
---

# Skill: Personal Clone

Create a private GitHub repo mirroring the current local repo and push to it.

## Steps

1. Verify `gh auth status` succeeds. If not, tell the user to run `! gh auth login`.
2. Get the repo name from the current directory's basename.
3. Detect the default branch: use `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null` or fall back to checking if `main` or `master` exists locally.
4. Check if a remote named `personal` already exists. If it does, stop and inform the user.
5. Create the repo: `gh repo create <name> --private`
6. Add remote: `git remote add personal <new-repo-ssh-url>`
7. Push: `git push -u personal <default-branch>`
8. Print the new repo URL and confirm done.
