---
name: unslop-de
description: German editing pass. The German delta on top of unslop, for when the deliverable is in German.
disable-model-invocation: true
---

# Unslop DE

`unslop` is calibrated on English. Its word lists, its filler phrases and its
banned openers are all English strings, so on a German text the mechanical tier
reports clean while the prose is still slop. German hides its slop in grammar
rather than vocabulary, which is why a separate pass exists.

This file carries only the delta. Everything else lives in `unslop` and is not
repeated here.

## Scope

Run on German prose you are shipping: a doc, an artifact, a commit message, a
chat reply. The exemptions carry over unchanged. Identifiers, code, quoted
material and the project's real domain vocabulary stay as they are.

## The pass

1. Load `unslop`. Apply tier 1 and tier 2. Both are language-agnostic and still
   bind: straight quotes, active voice, one idea per sentence, the natural
   number instead of three.
2. Apply the five levers below to every paragraph, in order. Each names a
   target. Rewrite toward the target instead of hunting the banned form.
3. Run the mechanical check at the bottom.
4. Read the result back. Nominalstil and welded compounds do not grep.

Done when all five levers have touched every paragraph and every grep either
returns nothing or returns a hit you can name a reason for keeping. Not done
when the text reads better.

## What changes rate, not rule

Two tier 1 rules fire far more often in German, so expect them rather than
discover them.

The **Gedankenstrich** is the single highest-frequency hit by a wide margin.
German typography reaches for it where English would take a comma, and the model
has absorbed that from German training text. Comma, or two sentences.

The German quotation pair is typographic. Straight quotes only, same as English.

## Lever 1: write the verb

**Nominalstil** is German's signature slop. The action moves into a noun and a
colourless verb carries the sentence.

Target: the action is the verb.

- "Die Regenerierung des Clients erfolgt beim Start" becomes "Der Generator
  schreibt den Client beim Start neu"
- "zur Anwendung kommen" becomes "anwenden"
- "eine Prüfung durchführen" becomes "prüfen"

The tell is a noun in -ung, -heit, -keit, -nis or -ion sitting next to erfolgen,
durchführen, vornehmen, stattfinden or "zum Einsatz kommen". Duden calls that
pairing a **Funktionsverbgefüge**: the verb has lost its meaning and carries
only grammar. Collapse it back into one verb.

Not every -ung noun is guilty. "Die Warnung scrollt vorbei" names a thing, not
an action in hiding. Ask whether a verb is trapped inside.

## Lever 2: name the actor

German hides the actor two ways where English has one.

Target: a named subject does something.

- werden-Passiv: "Der Client wird generiert" becomes "hey-api generiert den
  Client"
- impersonal **man**: "Man sieht dann eine veraltete Spec" becomes "Du siehst
  dann eine veraltete Spec"

Pick "du" or "Sie" once per document and hold it. Mixing "man" into a "du"
document is the usual failure and reads as two authors.

Keep the passive where the actor is genuinely unknown or irrelevant. "Die Datei
wird bei jedem Lauf gelöscht" is fine when who deletes it does not matter.

## Lever 3: split the Schachtelsatz

German grammar permits nesting that English does not, so "one idea per sentence"
needs enforcing here even when the sentence is grammatical. A **Schachtelsatz**
with a Relativsatz inside a Nebensatz survives an English-trained eye because
nothing about it is wrong.

Target: the reader never backtracks.

One mechanical signal that holds: a sentence over 28 words. Comma count does
not work here, tested and discarded. German enumerations are comma-heavy on
purpose ("Modell ändern, uvicorn startet neu, der Watcher regeneriert") and a
comma threshold flags that staccato chain, which is good writing, while missing
a 30-word Schachtelsatz that carries two commas.

The nesting itself comes out on the read in step 4, not from a pattern.

## Lever 4: plain German over Behördendeutsch

**Behördendeutsch** is the register of a letter from a German authority. It
signals effort and says nothing.

Target: the word you would say out loud.

| Behördendeutsch | say |
|---|---|
| aufgrund der Tatsache, dass | weil |
| im Rahmen von | bei, in |
| seitens | von |
| zwecks | für, um zu |
| diesbezüglich | dazu |
| in Bezug auf | zu |
| beinhaltet | enthält, hat |

Banned words, the German counterpart to unslop rule 6: nahtlos, robust, mächtig,
leistungsstark, performant, entscheidend, essenziell, maßgeblich, beleuchten,
eintauchen, "eine Vielzahl von", "spielt eine wichtige Rolle".

Banned openers, the counterpart to rules 7 to 9: "Es ist wichtig zu beachten",
"Darüber hinaus", "Des Weiteren", "Zudem" opening a paragraph, "Grundsätzlich",
"Im Wesentlichen", "Letztlich", "Zusammenfassend lässt sich sagen", "In der
heutigen".

Weak verbs propping up a sentence, the counterpart to tier 3 rule 10: ermöglicht,
gewährleistet, stellt sicher, bietet, verfügt über, dient als, stellt dar. Name
the mechanism instead.

## Lever 5: keep the team's Denglisch

**Denglisch** is an anglicism used where German has a word. Cut those.

The domain-vocabulary exception from tier 3 rule 13 binds harder in German
technical writing than in English. The team says Breaking Change, Merge, Commit,
Working Tree, Deploy, Branch. Translating those into Änderungsbruch or
Zusammenführung is worse writing, not better.

The test: would a colleague say this word in a German sentence at standup? Keep
it. Would only a translator write it? Cut it.

Welded compounds fail the same test from the other side. German lets you fuse
any two nouns, so the model does, and out comes "Typ-Unbequemlichkeit". If you
have never heard the compound, unfold it into a clause: "ändert nur den Typ,
nicht das Verhalten".

## Mechanical check

```bash
F=<datei>
grep -n "[—–“”‘’]" "$F"                                              # Gedankenstrich, Quotes
grep -nE "\bman\b" "$F"                                              # verdeckter Akteur
grep -nE "erfolgt|durchführ|vorgenommen|zum Einsatz|stattfind" "$F"  # Funktionsverbgefüge
grep -nE "ermöglicht|gewährleistet|stellt sicher|bietet|verfügt über|dient als" "$F"
grep -nE "aufgrund der Tatsache|im Rahmen von|seitens|zwecks|diesbezüglich" "$F"
grep -nE "nahtlos|robust|mächtig|leistungsstark|entscheidend|essenziell|Vielzahl von" "$F"
grep -nE "Es ist wichtig|Darüber hinaus|Des Weiteren|Zusammenfassend|Im Wesentlichen" "$F"
python3 -c "
import re,sys
t=re.sub(r'\`\`\`.*?\`\`\`','',open(sys.argv[1]).read(),flags=re.S)
t='\n'.join(l for l in t.splitlines() if not l.startswith(('|','#')))
for s in re.split(r'(?<=[.!?])\s+',' '.join(t.split())):
    if len(s.split())>28: print(len(s.split()),'Wörter:',s[:90])
" "$F"                                                               # Schachtelsatz
```

Nominalstil, nesting and welded compounds have no pattern. They come out on the
read in step 4.
