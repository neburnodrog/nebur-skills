---
name: allhands
description: Build the monthly all-hands block from your own git activity, pick the repos, and write it as Markdown into the vault. A second run with --notion transfers it to the All Hands page. --auto runs the whole thing unattended for the launchd routine.
disable-model-invocation: true
---

Builds Ruben's block for the monthly All Hands page: which projects moved in the
last four weeks, as bullets in the tone of the existing entries.

The skill is written in English. Everything it produces (the Markdown file, the
Notion entry) is German.

Two separate runs. `/allhands` writes the Markdown file, you read and fix it,
`/allhands --notion` transfers it. Whatever reaches the shared board has passed a
human eye first.

## Modes

`--since <date>` sets the start of the period. Without it, use four weeks back.
The launchd gate passes the date of the previous All Hands, so the report covers
exactly the span since the last meeting.

`--auto` runs unattended, launched by the gate on the morning of an All Hands.
Three deltas, and nothing else changes:

- Step 2 does not run. Every repo the scan finds goes into the report.
- Step 6 never runs. Notion stays a human decision.
- Step 5 ends by printing one line to stdout, `OK|<path>|<block>,<block>,...`,
  which the gate turns into a desktop banner. An empty scan prints `EMPTY` and
  writes no file.

Nobody is there to answer a question in `--auto`. Where the interactive run would
ask, take the stated default and note the choice in the file.

## Step 1 — Scan

```
rtk proxy bash ~/.claude/skills/allhands/scripts/scan.sh 4
```

The script finds every repo under `~/Repos/work` with commits in the last four
weeks **that you authored or co-authored**, and prints one line per repo as
`commits|repo|group|last-commit`, sorted by commit count descending.

The period is the argument, in weeks. Translate a `--since <date>` into the
matching number of weeks, rounded up, so no day of the span falls outside it.

Done when the list is in hand. If it is empty, say so and stop — no commits, no
report.

## Step 2 — Select

Skipped under `--auto`.

Show the repos found with commit count and last commit date, then ask via
`AskUserQuestion` with `multiSelect: true` which ones go into the report.

The widget holds four options per question and four questions per call. Above 16
repos, ask in **waves**: the first 16, then the next, until every repo has been
offered. Sort by commit count so the important ones land in the first wave.

The selection is also the Notion filter — whatever is unchecked here appears
nowhere later.

Done when every repo found has been offered once.

## Step 3 — Dig in

Launch **one subagent per selected repo, all in a single message**, so they run in
parallel. Above ten, go in waves of ten.

Each subagent gets this brief, with repo path and period filled in:

> Untersuche das Repo `<pfad>` und fasse zusammen, was dort zwischen `<seit>` und
> heute **vom User** gemacht wurde. Stelle jedem Shell-Kommando `rtk` voran.
>
> Betrachte ausschliesslich Commits, in denen Ruben Karlsson Autor oder Co-Author
> ist. Er committet unter mehreren Identitaeten (Teclead-Mail, E.ON-Kuerzel
> R45792, GitHub-noreply, "Nebur", "Karlsson, Ruben"):
> `rtk proxy git -C <pfad> log --all --since=<seit> --author='Ruben Karlsson\|Karlsson, Ruben\|ruben.karlsson\|rubenkarlsson\|R45792\|Nebur' --stat`
>
> `rtk proxy` ist hier zwingend: `rtk git log` kappt die Ausgabe bei 50 Commits
> und liefert sonst stillschweigend eine unvollstaendige Auswertung.
>
> Lies die Commit-Betreffe und die geänderten Dateinamen. Den Inhalt der Diffs
> brauchst du nicht. Gibt es gemergte Pull Requests im Zeitraum, nutze deren Titel
> und Beschreibung — sie sind meist schon fachlich formuliert.
>
> Ermittle ausserdem den **Projektnamen**: aus `package.json` (`name`),
> `pom.xml` (`<name>` oder `artifactId`), der ersten Überschrift des README oder
> dem Verzeichnisnamen. Nenne beides — den gefundenen Namen und das
> Elternverzeichnis, das meist der Kunde ist.
>
> Liefere zurück:
> - `PROJEKT: <Name>` und `GRUPPE: <Elternverzeichnis>`
> - `COMMITS: <Anzahl>`
> - **2 bis 5 Stichpunkte** zu dem, was fachlich und technisch passiert ist.
>
> Für die Stichpunkte gilt strikt:
> - 3 bis 10 Wörter, kein ganzer Satz, kein Punkt am Ende.
> - Telegrafischer Nominalstil: "Meine Bewertungen Screen (app)", "Backend
>   übernommen", "gluestack migration → react native reusables". Nicht "Ich
>   habe…", nicht "Es wurde…".
> - Deutsch mit echten Umlauten: "Verfügbarkeit", nicht "Verfuegbarkeit".
>   Englische Fachbegriffe bleiben unübersetzt.
> - **Verständlich für jemanden, der das Projekt nicht kennt.** Im All-Hands
>   sitzen auch HR, Office und Business Development. Benenne, was die Änderung
>   bewirkt, nicht wie sie im Code heisst.
> - Etablierte Begriffe bleiben (DATEV, SEO, Slack, Monorepo, Migration), interne
>   Namen fliegen raus: keine Datenbankspalten, keine Klassennamen, keine
>   Variablen, keine Feldtypen. "Wechselkurse manuell pflegbar" statt "manuelle
>   Kurserfassung in fx_rates, quote_currency jenseits char(3)".
> - **Keine PR-Nummern, keine Commit-Hashes, keine Ticket-IDs.**
> - Fasse zusammen, statt Commits aufzuzählen. Zwanzig Commits an derselben
>   Komponente sind ein Stichpunkt.
> - Reine Wartung (Dependency-Bumps, Formatierung, Merge-Commits) nur erwähnen,
>   wenn sonst nichts passiert ist.
>
> Erfinde nichts. Sagen die Commits zu wenig, schreibe weniger Stichpunkte oder
> `UNKLAR: <was du nicht bestimmen konntest>`.

## Step 4 — Merge

Group the replies **by project, not by repo**. Several repos of the same customer
become one block; repos with no recognisable project run under their parent
directory.

Directory names are internal, the all-hands names are the ones the room knows:

| Directory | Block name |
|---|---|
| `msb` | MSB |
| `datasharper` | EON |
| `tlv` | Teclead intern |

A directory outside this table keeps its own name, capitalised as the customer
writes it.

Block order: by summed commit count descending, so the biggest thing sits on top.

When a subagent reports `UNKLAR`, carry it into the file visibly instead of
smoothing it over — the user decides whether the point ships.

## Step 5 — Write

Under `--auto`, leave the vault file uncommitted and print the `OK|` line from
the Modes section as the last thing you do.

Write to `~/vault/Areas/Teclead/all-hands/allhands-<YYYY-MM>.md`, creating the
`all-hands` folder if it is missing:

```markdown
# All Hands <Monat Jahr>

Zeitraum: <seit> bis <heute>

## MSB  (34 Commits)

- Tippspiel generalisierung (cms)
- Meine Bewertungen Screen (app)

## EON  (124 Commits)

- Erstes roll-out in ein anderes Bundesland
- frontend und backend wurden migriert zum monorepo
```

The commit count is your own check: 124 commits behind one thin bullet means
something is missing. It drops out on the way to Notion.

Then name the path and the blocks to the user in one line, so he sees what is in
the file without opening it.

## Step 6 — To Notion (`--notion`)

Only on an explicit `--notion`, and never under `--auto`.

1. Find the current page via Notion search for `All Hands <Monat> <Jahr>`. It sits
   **outside** the shared pages and has no parent page. When you cannot find it,
   ask for the URL instead of guessing.
2. Read the page and find the `Ruben` block under **Team Faker**. It usually holds
   the placeholder `PROJEKT` with an empty bullet.
3. Show the user **verbatim** what you want to replace and with what, and wait for
   his confirmation.
4. Write only then, and only inside his own block. The page carries 15 to 20
   entries by other people; leave every one of them untouched.

The commit counts from the Markdown file drop out. Page format: project name as an
indented line without a bullet, the points below it.

Tone samples of real entries live in `FORMAT.md` — read them when the bullets come
out too wordy.

## The routine

`scripts/gate.sh` runs daily at 08:07 under the LaunchAgent
`com.neburnodrog.allhands`. On a day with no All Hands it exits in a couple of
seconds. On the day, before the meeting starts, it runs `/allhands --auto --since
<previous instance>` and banners the result. It writes nothing when the month's
draft already exists, so your edits survive a rerun.

It reads the calendar through `claude -p` with `--permission-prompts none`, so an
unexpected permission prompt fails the run instead of hanging it. `--strict-mcp-config`
is unusable here: it drops the claude.ai connectors along with the local servers,
and the calendar goes with them.

The plist pins node at `~/.nvm/versions/node/v24.15.0/bin`. An nvm upgrade breaks
it, and the gate then banners `node not found at <path>`. Fix both the plist and
`NODE_BIN` in `gate.sh`.

Installing or updating it after an edit:

```
cp scripts/com.neburnodrog.allhands.plist ~/Library/LaunchAgents/
launchctl bootout gui/$(id -u)/com.neburnodrog.allhands 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.neburnodrog.allhands.plist
```

The installed plist is a copy, so an edit in this repo reaches launchd only
through those three lines. `gate.sh` needs no reinstall; launchd runs it through
the `~/.claude/skills` symlink.

It must stay a LaunchAgent. A daemon runs outside your login session and cannot
read the keychain, so `claude` reports "Not logged in" and every run fails.
