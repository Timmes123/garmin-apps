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

## Neue Sauna hinzufügen

1. `<id>.json` nach dem Format oben anlegen (`id` in der Datei = Dateiname).
2. Die Sauna in `index.json` eintragen (`id`, `name`, `city`).

Die App lädt `index.json` bei jedem Start und zeigt die Saunen im Menü unter „Sauna“.
