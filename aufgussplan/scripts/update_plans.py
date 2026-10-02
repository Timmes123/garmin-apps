#!/usr/bin/env python3
"""Liest die Aufgusspläne von den Websites der Saunen und aktualisiert plans/*.json.

Pro Sauna gibt es eine Funktion, die die Einträge von der Website liest. Geschrieben
wird nur, wenn sich die Einträge geändert haben; dann steigt "version", damit die Uhr
den neuen Plan übernimmt. Aufruf: python update_plans.py [--check]
"""
import datetime
import html
import json
import re
import sys
import urllib.request
from pathlib import Path

PLANS = Path(__file__).resolve().parent.parent / "plans"
USER_AGENT = "garmin-apps-aufgussplan (+https://github.com/Timmes123/garmin-apps)"


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", errors="replace")


def text(fragment):
    return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()


def obermaintherme():
    """Tabelle "Unser Aufguss- & Wohlfühlprogramm": Zeit, Name, Sauna (Temperatur), Tropfen."""
    page = fetch("https://www.obermaintherme.de/saunaland/termine/")
    table = re.search(r'<table class="zeitplan">(.*?)</table>', page, re.S)
    if not table:
        raise ValueError("Tabelle 'zeitplan' nicht gefunden")
    entries = []
    for row in re.findall(r"<tr>(.*?)</tr>", table.group(1), re.S):
        cells = dict(re.findall(r'<td class="timetable-(\w+)">(.*?)</td>', row, re.S))
        time = re.match(r"(\d{1,2})\.(\d{2})", text(cells["time"]))
        name = text(cells["title"])
        place = re.match(r"(.*?)\s*\((.*)\)\s*$", text(cells["description"]))
        entry = {
            "t": f"{int(time.group(1)):02d}:{time.group(2)}",
            "n": name.rstrip("*"),
            "s": place.group(1) if place else text(cells["description"]),
        }
        if place:
            entry["c"] = place.group(2)
        # Tropfen: "2 - 3" ist eine Spanne, Einträge ganz ohne Tropfen sind Masken/Rituale
        drops = [part.count("icon-tropfen") for part in cells.get("icon", "").split(" - ")]
        drops = [count for count in drops if count]
        if drops:
            entry["i"] = drops
        else:
            entry["r"] = 1
        # "*" und alles nach 20:10 Uhr findet nur bei langer Öffnung statt (Fußnoten der Seite)
        if name.endswith("*") or entry["t"] > "20:10":
            entry["l"] = 1
        entries.append(entry)
    if len(entries) < 10:
        raise ValueError(f"nur {len(entries)} Einträge gelesen, Seite vermutlich umgebaut")
    return entries


SCRAPERS = {"obermaintherme": obermaintherme}


def dump(plan):
    """JSON mit einem Eintrag pro Zeile, damit Änderungen im Diff lesbar bleiben."""
    marker = "@@ENTRIES{}@@"
    blocks = [schedule["entries"] for schedule in plan["schedules"]]
    slim = dict(plan, schedules=[dict(s, entries=marker.format(i)) for i, s in enumerate(plan["schedules"])])
    out = json.dumps(slim, ensure_ascii=False, indent=2)
    for i, entries in enumerate(blocks):
        lines = ",\n".join("        " + json.dumps(e, ensure_ascii=False) for e in entries)
        out = out.replace(json.dumps(marker.format(i)), "[\n" + lines + "\n      ]")
    return out + "\n"


def main():
    check_only = "--check" in sys.argv
    today = datetime.date.today().isoformat()
    failed = False
    for sauna, scrape in SCRAPERS.items():
        path = PLANS / f"{sauna}.json"
        plan = json.loads(path.read_text(encoding="utf-8"))
        try:
            entries = scrape()
        except Exception as error:  # eine kaputte Seite soll die anderen Saunen nicht blockieren
            print(f"{sauna}: FEHLER {error}")
            failed = True
            continue
        if plan["schedules"][0]["entries"] == entries:
            print(f"{sauna}: unverändert ({len(entries)} Einträge)")
            continue
        print(f"{sauna}: geändert ({len(entries)} Einträge)")
        if not check_only:
            plan["schedules"][0]["entries"] = entries
            plan["version"] += 1
            plan["updated"] = today
            path.write_text(dump(plan), encoding="utf-8", newline="\n")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
