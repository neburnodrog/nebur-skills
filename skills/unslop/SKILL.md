---
name: unslop
description: Cut AI tells from any writing. Applies to every chat reply, every written deliverable, and comments in source files. Tier 1 and tier 2 are always on. Load this file for the full editing pass before shipping docs, READMEs, specs, PR or commit messages, artifacts, or issue text.
---

# Unslop

Edit text to remove AI patterns and add human voice.

## Scope

Applies to:

- Chat replies in the terminal.
- Written deliverables. Docs, READMEs, specs, plans, PR and commit messages, artifacts, issue and ticket text.
- Comments and docstrings in source files.

Never applies to:

- Identifiers. Variable, function, type, file and branch names stay as they are.
- Code itself, including string literals and the text a program prints at runtime.
- Quoted material. Text copied from a file, a library, an error message, a spec or the user keeps its original wording, dashes and all.
- Domain vocabulary. When a listed word is the project's real name for a thing, keep it. See rule 13.

## Enforcement tiers

Tier 1 is mechanical. `hooks/unslop-check.sh` greps every chat reply and blocks the turn on a hit, so these are enforced rather than requested. It cannot see file writes, so tier 1 in a deliverable is on you.

Tier 2 is the core. It lives in `CLAUDE.md` and is in context for every session.

Tier 3 is this file. Run it as a deliberate editing pass on anything longer than a chat reply.

## Process

1. Write the draft.
2. Fix tier 1 hits. They are mechanical, so do them first and fast.
3. Apply tier 2, then tier 3.
4. Add soul. See the last section.
5. Self-audit. Ask "what makes this obviously AI generated?" and fix what is left.

## Tier 1, mechanical

1. No em dashes. No en dashes. No parenthesis standing in for a dash. End the sentence or use a comma. Reaching for a parenthesis instead of an em dash trades one tell for another.
2. Straight quotes and straight apostrophes only. No curly quotes.
3. No decorative emoji in headings or bullets.
4. Sentence case headings.
5. No bold label followed by a colon at the start of a line or bullet. A bold lead-in that ends in a period, names the item, and is followed by genuinely new detail is fine.
6. Banned words. delve, crucial, pivotal, tapestry, testament, intricate, myriad, seamless, utilize, leverage as a verb, foster, garner, interplay, enduring, groundbreaking, renowned, breathtaking, vibrant, nestled, must-visit. Use the plain word.
7. No chatbot phrases or sycophancy. "I hope this helps", "Let me know if", "Great question", "You're absolutely right", "Certainly", "Of course", "Absolutely", "I'd be happy to", "Found the smoking gun".
8. No filler openers. "Here's the thing", "The reality is", "Let's be clear", "It is important to note that", "It's worth noting", "At the end of the day", "In today's". Delete them, the sentence works without.
9. No stock filler. "In order to" becomes "To". "Due to the fact that" becomes "Because".

## Tier 2, the core

1. Prefer the plain word. The fancier synonym is rarely clearer.
2. Active voice. Catch "is/are/was/were + past participle" and name the actor. "Queries are validated" becomes "the compiler validates queries". Passive is fine only when the actor is unknown or genuinely does not matter.
3. One idea per sentence. If the reader has to backtrack to parse it, split it.
4. Say what it does, not how it feels. If you cannot restate a sentence as a concrete instruction, fact or number, cut it.
5. Cut the adverb or use a stronger verb. An adverb propping up a weak verb means the verb is wrong.
6. No hedging stacks. "could potentially possibly be argued that it might" becomes "may".
7. Have an opinion. React to the facts instead of listing pros and cons neutrally.
8. Vary rhythm. Short sentences. Then longer ones that take their time.

## Tier 3, full checklist

### Content

1. Puffery. "pivotal moment", "testament to", "evolving landscape", "setting the stage for", "indelible mark", "deeply rooted". Cut it, state what happened.
2. Name dropping. Listing media outlets or tools without context. Pick one, say what it said.
3. Superficial -ing phrases. "highlighting...", "ensuring...", "reflecting...", "showcasing...", "fostering...". Delete, or expand with a real source.
4. Promotional language. "vibrant", "breathtaking", "groundbreaking", "renowned", "stunning". Use neutral description.
5. Vague attributions. "Experts believe", "Industry reports suggest", "Some critics argue". Name the source or delete the claim.
6. Formulaic challenges. "Despite challenges... continues to thrive." Replace with specific facts.
7. Fake precision. "roughly 40%", "about 3x faster" with nothing behind it. Measure it or drop the number.
8. Cutoff disclaimers. "While specific details are limited..." Find the source or cut the sentence.
9. Generic conclusions. "The future looks bright." State a specific plan or fact, or end without a conclusion.

### Language

10. Fancy ways to say "is". "serves as", "stands as", "boasts", "features". Say "is" or "has".
11. "Not just X, but Y." State the point directly.
12. Rule of three. Forcing ideas into groups of three. Use the natural number, even when it is two or five.
13. Abstract metaphor nouns. substrate, wedge, vector, locus, vantage, nexus, primitive as a noun, harness as a metaphor, surface as in "API surface", bedrock, scaffolding as a metaphor, modality, paradigm, gold-plating, ratchet as a metaphor, evacuate for moving code, endgame, north star, flywheel. These read as technical but have a plainer concrete word. "Substrate" becomes "base". "Wedge in" becomes "add". "Vector" becomes "way". "Gold-plating" becomes "more than the job needs". "Evacuate" becomes "move out". "Endgame" becomes "the last phase". Exception: when the word is the project's actual domain term, a primitive in a graphics library, a surface in a rendering pipeline, a harness in a test runner, it is the correct word. Keep it.
14. Synonym cycling. Protagonist, main character, central figure and hero in one paragraph. Pick one and repeat it.
15. False ranges. "from X to Y" where X and Y are not on a meaningful scale. List the items instead.

### Style

16. Colon overuse. A colon before a list or an example is fine. As a mid-sentence connector it adds nothing. Rewrite so the point stands without the comparison framing.
17. Boldface overuse. Do not bold every proper noun or acronym.
18. Inline-header lists. The tell is a bold label and colon that restates the line. "**Performance:** Performance improved..." Convert to prose.
19. Section-closing summaries. A final sentence that repeats what the section just said. Cut it, the section already said it.
20. Restating the question. Opening a reply by paraphrasing what was asked. Start with the answer.

### Plain speech

21. Say what it does, not how it feels. "the database stays close at hand", "SQL you can read", "types that follow your schema" all name a feeling. Name the mechanism or a number instead: "`.toSQL()` returns the exact string sent to the database", "a column rename fails the build". Ask what the sentence tells the reader to do or know, then write that. One more check: if the sentence could appear unchanged in another project's docs, it says nothing about this one. Cut it.
22. Shorten or split dense sentences. One idea per sentence.
23. Active voice. Name the actor.
24. Cut adverbs, or use a stronger verb. "runs quickly" becomes "is fast" or the measured number. "significantly improves" becomes the delta.
25. Prefer the plain word. "utilize" becomes "use", "facilitate" becomes "help", "numerous" becomes "many", "in the event that" becomes "if".

## Adding soul

Removing patterns is half the job. Sterile, voiceless writing is just as obvious as slop.

- Have opinions. React to facts instead of neutrally listing pros and cons.
- Acknowledge complexity. "Impressive but also kind of unsettling" beats "impressive".
- Use "I" when it fits. First person is not unprofessional.
- Let some mess in. Perfect parallel structure looks machine made.
- Be specific. Not "this is concerning" but "there is something unsettling about agents churning away at 3am".
