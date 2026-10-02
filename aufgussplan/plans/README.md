# Aufgusspläne

Eine JSON-Datei pro Sauna. Die Uhr lädt die Datei über
`https://raw.githubusercontent.com/Timmes123/garmin-apps/main/aufgussplan/plans/<id>.json`.

## Format

| Feld | Bedeutung |
|---|---|
| `version` | Bei jeder Änderung um 1 erhöhen |
| `lateDays` | Wochentage mit langer Öffnung (1 = Montag … 7 = Sonntag) |
| `lateRanges` | Zeiträume mit langer Öffnung, je `[JJJJMMTT, JJJJMMTT]` |
| `lateNote` | Hinweistext für Einträge, die nur bei langer Öffnung stattfinden |
| `schedules[].days` | Wochentage, an denen die Einträge gelten |
| `entries[].t` | Uhrzeit `HH:MM`, Einträge aufsteigend sortiert |
| `entries[].n` | Name des Aufgusses |
| `entries[].s` | Sauna bzw. Ort |
| `entries[].c` | Temperatur oder Zusatz |
| `entries[].i` | Intensität in Tropfen: `[3]` oder als Spanne `[2, 3]`; weglassen, wenn keine angegeben |
| `entries[].r` | `1` = Maske/Ritual statt Aufguss (in der App ausblendbar) |
| `entries[].l` | `1` = findet nur bei langer Öffnung statt |

## Automatische Aktualisierung

Es werden nur Saunen aufgenommen, deren Plan sich per Skript von der Website lesen lässt.
`scripts/update_plans.py` hat pro Sauna eine Funktion dafür; die GitHub Action
`.github/workflows/update-plans.yml` ruft es jeden Montag auf und committet Änderungen
(von Hand: Actions → „Aufgusspläne aktualisieren“ → Run workflow). Felder außerhalb von
`entries` (z. B. `lateDays`, `lateRanges`) werden nicht automatisch gepflegt.

## Neue Sauna hinzufügen

1. In `scripts/update_plans.py` eine Funktion schreiben, die die Einträge liest, und in `SCRAPERS` eintragen.
2. `<id>.json` mit Kopfdaten und leerem `entries` anlegen (`id` in der Datei = Dateiname).
3. Die Sauna in `index.json` eintragen (`id`, `name`, `city`).

Die App lädt `index.json` bei jedem Start und zeigt die Saunen im Menü unter „Sauna“.
