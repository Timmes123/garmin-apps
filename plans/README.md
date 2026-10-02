# Aufgusspläne

Eine JSON-Datei pro Sauna. Die Uhr lädt die Datei über
`https://raw.githubusercontent.com/Timmes123/garmin-apps/main/plans/<id>.json`.

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
| `entries[].l` | `1` = findet nur bei langer Öffnung statt |
