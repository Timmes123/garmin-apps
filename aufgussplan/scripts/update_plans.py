#!/usr/bin/env python3
"""Liest die Aufgusspläne von den Websites der Saunen und aktualisiert plans/*.json.

Pro Sauna gibt es eine Funktion, die die Einträge von der Website liest. Geschrieben
wird nur, wenn sich die Einträge geändert haben; dann steigt "version", damit die Uhr
den neuen Plan übernimmt. Aufruf: python update_plans.py [sauna …] [--check]
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
    return entries


def fuerthermare():
    """Tagesplan von aufgussplan.de: zeigt nur die heute noch kommenden Aufgüsse."""
    # Die Legende ordnet den Symbolbildern ihre Bedeutung zu ("Stufe 3 (normal)", "Musik", …)
    legend_page = fetch("https://www.aufgussplan.de/standort/fuerth")
    legend = {
        icon: text(label)
        for icon, label in re.findall(
            r'eigenschaft/([a-f0-9-]+)\.png" alt="" class="icon" />\s*<span class="txt">(.*?)</span>', legend_page, re.S)
    }
    page = fetch("https://www.aufgussplan.de/content/fuerth")
    entries = []
    for row in re.findall(r"<tr[^>]*>(.*?)</tr>", page, re.S):
        cells = dict(re.findall(r'<td class="(\w+)\s*">(.*?)</td>', row, re.S))
        if "zeit" not in cells:
            continue
        # Die nächsten Aufgüsse und die späteren Zeilen sind unterschiedlich aufgebaut
        name = re.search(r'<(?:span class="title"|div class="aufguss")>(.*?)</(?:span|div)>', cells["aufguss"], re.S)
        sauna = text(cells["sauna"])
        place = re.match(r"(.*?)\s*\[(.*)\]\s*$", sauna)
        entry = {
            "t": re.search(r"\d{1,2}:\d{2}", text(cells["zeit"])).group(0).zfill(5),
            "n": text(name.group(1)) if name else "Aufguss",
            "s": place.group(1) if place else sauna,
        }
        if place:
            entry["c"] = place.group(2)
        tags = []
        for icon in re.findall(r"eigenschaft/([a-f0-9-]+)\.png", cells.get("duft", "")):
            label = legend.get(icon, "")
            level = re.match(r"Stufe (\d)", label)
            if level:
                entry["i"] = [int(level.group(1))]
            elif label == "Salz-Peeling":
                entry["r"] = 1
            elif label and label != "Aufguss":
                tags.append(label)
        if tags:
            entry["g"] = ", ".join(tags)
        scent = re.search(r'<span class="dufttext[^"]*">(.*?)</span>', cells.get("duft", ""), re.S)
        if scent and text(scent.group(1)):
            entry["d"] = text(scent.group(1))
        entries.append(entry)
    return entries


# Wochenpläne prüft die Action regelmäßig; Tagespläne ("live") nur, wenn die Uhr sie anfordert
SCRAPERS = {"obermaintherme": obermaintherme, "fuerthermare": fuerthermare}
SCHEDULED = ["obermaintherme"]


def merge_day(old, new):
    """Die Seite zeigt nur kommende Aufgüsse; bereits gelesene frühere des Tages bleiben erhalten."""
    merged = {(e["t"], e["s"]): e for e in old}
    merged.update({(e["t"], e["s"]): e for e in new})
    return sorted(merged.values(), key=lambda e: e["t"])


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
    try:
        from zoneinfo import ZoneInfo
        today = datetime.datetime.now(ZoneInfo("Europe/Berlin")).date()
    except Exception:  # Windows ohne tzdata: lokale Zeit
        today = datetime.date.today()
    today_number = int(today.strftime("%Y%m%d"))
    today = today.isoformat()
    failed = False
    for sauna in [arg for arg in sys.argv[1:] if arg and not arg.startswith("--")] or SCHEDULED:
        scrape = SCRAPERS[sauna]
        path = PLANS / f"{sauna}.json"
        plan = json.loads(path.read_text(encoding="utf-8"))
        try:
            entries = scrape()
        except Exception as error:  # eine kaputte Seite soll die anderen Saunen nicht blockieren
            print(f"{sauna}: FEHLER {error}")
            failed = True
            continue
        if plan.get("live"):
            if plan.get("date") == today_number:
                entries = merge_day(plan["schedules"][0]["entries"], entries)
        elif len(entries) < 10:
            print(f"{sauna}: FEHLER nur {len(entries)} Einträge gelesen")
            failed = True
            continue
        if plan["schedules"][0]["entries"] == entries and plan.get("date", today_number) == today_number:
            print(f"{sauna}: unverändert ({len(entries)} Einträge)")
            continue
        print(f"{sauna}: geändert ({len(entries)} Einträge)")
        if not check_only:
            plan["schedules"][0]["entries"] = entries
            plan["version"] += 1
            plan["updated"] = today
            if plan.get("live"):
                plan["date"] = today_number
            path.write_text(dump(plan), encoding="utf-8", newline="\n")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
