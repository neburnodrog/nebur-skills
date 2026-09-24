# Working on these skills

Notes to myself, written down because this setup is obvious today and gone in three months.

## How it fits together

Two repos hold skills, and `~/.claude/skills` is a symlink into one of them:

```
~/.claude/skills -> ~/Repos/dotClaude/skills
                      |- <name>/                                   private skill, lives here
                      |- <name> -> ../../nebur-skills/skills/...   published, lives in this repo
                      \- <name> -> ../../.agents/skills/...        Matt Pocock's set
```

Claude reads a skill from disk every time it fires, so an edit in either working tree takes effect in the next message. No rebuild, no restart.

Other machines do not work this way. They install the plugin, which copies `skills/` into `~/.claude/plugins/cache/` and keys that copy by version. That difference drives everything below.

## Editing a skill

Find out which repo owns it:

```bash
ls -l ~/.claude/skills/<name>
```

A symlink into `nebur-skills` means it is published and the edit is public. A symlink into `.agents` means it is someone else's and an edit forks it locally. A real directory means it is private to `dotClaude`.

Then edit the file and carry on. Commit in whichever repo owns it. `nebur-skills` has a public remote, `dotClaude` has none, so its commits stay on the machine.

## Adding a skill

Pick the repo first, because that decides who can read it.

Public:

```bash
mkdir ~/Repos/nebur-skills/skills/<name>
ln -s ../../nebur-skills/skills/<name> ~/Repos/dotClaude/skills/<name>
```

Private:

```bash
mkdir ~/Repos/dotClaude/skills/<name>
```

The symlink is the part worth remembering. Without it the skill sits in the repo and Claude never loads it here.

When in doubt start it private. Promoting it later is a `git mv` and a symlink.

## Publishing a change

```bash
cd ~/Repos/nebur-skills
# raise "version" in .claude-plugin/plugin.json
git commit -am "..."
git push
```

Raise the version or the update is a no-op. `plugin update` compares version numbers, not file contents, so a push alone leaves every other machine on the old copy while reporting success. This is not theoretical: cutting the set from 22 skills to 10 needed a bump before any install noticed.

Docs like this file do not need a bump. Only `skills/` ships.

On another machine:

```
/plugin marketplace update nebur-skills
/plugin update nebur-skills
```

First time there:

```
/plugin marketplace add neburnodrog/nebur-skills
/plugin install nebur-skills@nebur-skills
```

## Never edit the cache

`~/.claude/plugins/cache/` holds installed copies. Editing one looks like it works and then vanishes on the next update. Edit the working tree.

## Testing

`clean-branches` has a test, because it deletes things. It builds a throwaway repo with a real remote, covers every branch and worktree case, and asserts each verdict:

```bash
bash skills/clean-branches/test.sh          # fixture removed on pass
bash skills/clean-branches/test.sh --keep   # fixture kept for poking
```

It exits non-zero on failure and keeps the fixture so the failing case can be inspected. It earned its keep during development by catching four bugs, including a `git worktree prune` that silently did nothing because of a three month expiry default.

Any skill that deletes or rewrites files should get the same treatment.

## Token cost

A skill's `description` sits in context on every turn of every session, because that is what Claude reads to decide whether to load it. The body costs nothing until the skill fires. So keep descriptions short and put the detail in the body.

For a skill that should only ever run when I type its name, the frontmatter line is:

```yaml
disable-model-invocation: true
```

That drops the description from context entirely, taking the always-on cost to zero. The trade is that nothing will remind me the skill exists. For anything destructive, that is the right trade.

Check what the set costs with:

```bash
claude plugin details nebur-skills@nebur-skills
```

## If you are not me

Issues and pull requests are welcome. A few of these skills assume my machine, and the README says which. If one is useful to you but wired to my paths, say so in an issue and I will make it configurable.
