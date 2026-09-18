# Tone of the all-hands entries

Real entries from past editions. They are the yardstick, not a general feel for
"short". They are German and stay German.

## Ruben (August 2026)

```
- **Ruben**
	MSB
	- Tippspiel generalisierung (cms)
	- Meine Bewertungen Screen (app)
	- image utils im shared repo als npm lib (client-lib)
	- gluestack migration → react native reusables
	EON
	- Erstes roll-out in ein anderes Bundesland.
	- frontend und backend wurden migriert zum monorepo
```

## Others (Mai 2026, Dezember 2025, August 2026)

```
- **Thilo**
	Helsana
	- Abschluss OKP Produktseiten —> Go Live
	- Fortführung der Migration ohne QS Framework
	AEM Agent
	- Fragebogen erstellt
	- Strategische Schärfung — Tech-Hygiene, Content-Autor-Value, Pain-Point-Discovery, Management-Pitch
	🐣 🍼
```

```
- **Thilo**
	Bundeswehr:
	- Implementierung ChangeListener für Shared Asset Links
	- Erweiterung Custom Asset API mit neuen Parametern
	- Whitelist für Custom API
	- Release für neuen Policy Tab mit neuer RenderCondition
	- Implementierung von SlingPostProcessor zum automatischen publishen von Assets
	- Erweiterung der Component UI mit einer Audio Component
	- kleine Anpassungen von Rendition, Favicons, Bulk Editing
	Helsana:  - MIGRATION
```

```
- **John**
	EON
	- Übergabe von Benni immer noch nicht fertig
	- Housekeeping → sämtliche Dependencies updaten
	- Planung von Frontend UI Improvements
	Bahn
	- Projektplanung wegen großer Umstrukturierung
	- Datenpflege der Daten aus neuen Datenquellen
```

```
- **Miko**
	MSB
	- Reporting (aka Business Intelligence) Backend übernommen
	- Viel Cleanup im Code und DevTools
	- Infra Verbesserungen
	- Suche-Umbau ist in progress
	- Ansonsten normale Featureentwicklung nebenbei, viele Support und Fragenbeantworten
```

## What follows from that

**Length** 2 to 8 bullets per person, 3 to 10 words each, 30 to 60 words in total.
Outliers downward are normal and accepted — "Elternzeit", "git gud", "ist
rumgewuselt in vielen Bereichen" are real entries.

**Style** Telegraphic nominal style: a noun ("Implementierung …", "Erweiterung …")
or a participle without a subject ("Backend übernommen", "Fragebogen erstellt").
Neither "Ich habe …" nor "Es wurde …" occurs anywhere.

**Language** German, English technical terms untranslated: Housekeeping, roll-out,
in progress, Cleanup.

**Technical depth** Concrete, free of internals. Established terms stand as a
matter of course (`gluestack → react native reusables`, DATEV, SEO, Monorepo);
database columns, class names and field types stay out. In doubt: what does the
change do, not what it is called in the code. The room includes HR, office and
business development.

**Never present** PR links, commit hashes, ticket numbers. Nine editions checked,
not a single occurrence.

**Register** Loose and uncorrected. Lowercase and typos stay, emojis are usual, and
frustration gets named ("Übergabe von Benni immer noch nicht fertig", "aber leider
total kaputt"). A polished entry stands out here.

**Structure** Project name as an indented line without a bullet, the points below
it. Two projects make two blocks.
