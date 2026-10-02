import Toybox.Application;
import Toybox.Attention;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

// Zustand der geöffneten App: Plan, Auswahl, Erinnerungen und Abruf von GitHub
class PlanModel {

    const BASE_URL = "https://raw.githubusercontent.com/Timmes123/garmin-apps/main/aufgussplan/plans/";
    // Die API liefert neue Commits sofort, raw.githubusercontent.com erst nach einigen Minuten
    const API_URL = "https://api.github.com/repos/Timmes123/garmin-apps/";
    const POLL_TICKS = 2;
    const MAX_POLLS = 12;
    const QUIET_POLLS = 4;
    const DEFAULT_SAUNA = "obermaintherme";
    const LEAD_CHOICES = [5, 10, 15, 20];

    const KEY_SAUNA = "sauna";
    const KEY_INDEX = "index";
    const KEY_MARKS = "marks";
    const KEY_LEAD = "lead";
    const KEY_CHECKED = "checked";

    var plan as Dictionary?;
    var entries as Array = [];
    var lateDay as Boolean = true;
    var sel as Number = 0;
    var status as String?;
    // true, solange GitHub den heutigen Tagesplan erst noch von der Website holt
    var loading as Boolean = false;

    private var _checking as Boolean = false;
    private var _polls as Number = 0;
    private var _pollIn as Number = 0;
    private var _statusTicks as Number = 0;
    private var _manual as Boolean = false;
    private var _previousSauna as String?;
    private var _timer as Timer.Timer?;

    function initialize() {
        installBundled();
        // Eine Erinnerung, über die die App gerade geweckt wurde, nicht nochmal melden
        Application.Storage.deleteValue(Reminders.KEY_FIRED);
        reload();
        rebuildPending();
    }

    function start() as Void {
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:onTick), 10000, true);
        fetchPlan(false);
    }

    // Mitgelieferte Daten ersetzen gespeicherte nur, wenn sie neuer sind
    private function installBundled() as Void {
        var bundled = WatchUi.loadResource(Rez.JsonData.DefaultPlan) as Dictionary;
        var stored = PlanStore.getPlan();
        if (stored == null) {
            if (saunaId().equals(DEFAULT_SAUNA)) {
                PlanStore.setPlan(bundled);
            }
        } else if (DEFAULT_SAUNA.equals(stored["id"]) && PlanStore.versionOf(stored) < PlanStore.versionOf(bundled)) {
            PlanStore.setPlan(bundled);
        }
        if (!(Application.Storage.getValue(KEY_INDEX) instanceof Dictionary)) {
            var index = WatchUi.loadResource(Rez.JsonData.DefaultIndex) as Dictionary;
            Application.Storage.setValue(KEY_INDEX, index as Dictionary<Application.PropertyKeyType, Application.PropertyValueType>);
        }
    }

    // Plan aus dem Speicher lesen und auf den nächsten Aufguss springen
    function reload() as Void {
        plan = PlanStore.getPlan();
        entries = PlanStore.todaysEntries(plan, PlanStore.hideRituals());
        lateDay = PlanStore.isLateDay(plan);
        var next = PlanStore.nextIndex(entries, lateDay);
        sel = (next >= 0) ? next : (entries.size() > 0 ? entries.size() - 1 : 0);
        WatchUi.requestUpdate();
    }

    function move(delta as Number) as Void {
        var target = sel + delta;
        if (target >= 0 && target < entries.size()) {
            sel = target;
            WatchUi.requestUpdate();
        }
    }

    function selected() as Dictionary? {
        if (sel < entries.size()) {
            return entries[sel] as Dictionary;
        }
        return null;
    }

    function isSkipped(entry as Dictionary) as Boolean {
        return !lateDay && PlanStore.isLateOnly(entry);
    }

    function setStatus(text as String) as Void {
        status = text;
        _statusTicks = 1;
        WatchUi.requestUpdate();
    }

    function onTick() as Void {
        if (status != null) {
            if (_statusTicks <= 0) {
                status = null;
            }
            _statusTicks--;
        }
        if (_pollIn > 0) {
            _pollIn--;
            if (_pollIn == 0) {
                pollLivePlan();
            }
        }
        var fired = Application.Storage.getValue(Reminders.KEY_FIRED);
        if (fired instanceof Array) {
            Application.Storage.deleteValue(Reminders.KEY_FIRED);
            alert(fired as Array<String>);
        } else {
            var due = Reminders.takeDue(0);
            if (due.size() > 0) {
                Reminders.schedule();
                alert(due);
            }
        }
        WatchUi.requestUpdate();
    }

    private function alert(texts as Array<String>) as Void {
        if (Attention has :vibrate) {
            Attention.vibrate([
                new Attention.VibeProfile(100, 400),
                new Attention.VibeProfile(0, 200),
                new Attention.VibeProfile(100, 400)
            ]);
        }
        WatchUi.pushView(new AlertView(texts), new AlertDelegate(), WatchUi.SLIDE_UP);
    }

    // ---- Erinnerungen ----

    function entryKey(entry as Dictionary) as String {
        return (entry["t"] as String) + " " + (entry["n"] as String);
    }

    function lead() as Number {
        var value = Application.Storage.getValue(KEY_LEAD);
        if (value instanceof Number) {
            return value;
        }
        return 10;
    }

    function cycleLead() as Number {
        var next = LEAD_CHOICES[(LEAD_CHOICES.indexOf(lead()) + 1) % LEAD_CHOICES.size()];
        Application.Storage.setValue(KEY_LEAD, next);
        rebuildPending();
        return next;
    }

    // Markierungen gelten nur für den Tag, an dem sie gesetzt wurden
    private function markKeys() as Array {
        var marks = Application.Storage.getValue(KEY_MARKS);
        if (marks instanceof Dictionary && marks["d"] == PlanStore.todayNumber() && marks["k"] instanceof Array) {
            return marks["k"] as Array;
        }
        return [];
    }

    function isMarked(entry as Dictionary) as Boolean {
        return markKeys().indexOf(entryKey(entry)) >= 0;
    }

    function toggleMark(entry as Dictionary) as Void {
        var keys = markKeys();
        var key = entryKey(entry);
        if (keys.indexOf(key) >= 0) {
            keys.remove(key);
        } else {
            keys.add(key);
        }
        saveMarks(keys);
    }

    private function saveMarks(keys as Array) as Void {
        var marks = { "d" => PlanStore.todayNumber(), "k" => keys };
        Application.Storage.setValue(KEY_MARKS, marks as Dictionary<Application.PropertyKeyType, Application.PropertyValueType>);
        rebuildPending();
        WatchUi.requestUpdate();
    }

    // Offene Erinnerungen aus Markierungen und Vorlaufzeit neu berechnen
    function rebuildPending() as Void {
        var keys = markKeys();
        var midnight = Time.today().value();
        var now = Time.now().value();
        var leadSeconds = lead() * 60;
        var list = [];
        for (var i = 0; i < keys.size(); i++) {
            var key = keys[i] as String;
            var when = midnight + PlanStore.parseMinutes(key) * 60 - leadSeconds;
            if (when <= now) {
                continue;
            }
            var pos = 0;
            while (pos < list.size() && ((list[pos] as Array)[0] as Number) <= when) {
                pos++;
            }
            list = list.slice(0, pos).add([when, key]).addAll(list.slice(pos, null));
        }
        Application.Storage.setValue(Reminders.KEY_PENDING, list as Array<Application.PropertyValueType>);
        Reminders.schedule();
    }

    // ---- Sauna und Abruf ----

    function saunaId() as String {
        var id = Application.Storage.getValue(KEY_SAUNA);
        if (id instanceof String) {
            return id;
        }
        return DEFAULT_SAUNA;
    }

    // Höchste Stufe der Intensitätsskala, 0 wenn die Sauna keine angibt
    function scale() as Number {
        if (plan != null && (plan as Dictionary)["scale"] instanceof Number) {
            return (plan as Dictionary)["scale"] as Number;
        }
        return 0;
    }

    function saunaName() as String {
        if (plan != null && (plan as Dictionary)["name"] instanceof String) {
            return (plan as Dictionary)["name"] as String;
        }
        return saunaId();
    }

    function planInfo() as String {
        if (plan != null && (plan as Dictionary)["updated"] instanceof String) {
            return "Stand " + ((plan as Dictionary)["updated"] as String);
        }
        return "kein Plan geladen";
    }

    function saunaList() as Array {
        var index = Application.Storage.getValue(KEY_INDEX);
        if (index instanceof Dictionary && index["saunas"] instanceof Array) {
            return index["saunas"] as Array;
        }
        return [];
    }

    function selectSauna(id as String) as Void {
        if (id.equals(saunaId()) && plan != null) {
            return;
        }
        if (!System.getDeviceSettings().phoneConnected) {
            setStatus("Kein Handy");
            return;
        }
        _previousSauna = saunaId();
        Application.Storage.setValue(KEY_SAUNA, id);
        fetchPlan(true);
    }

    function fetchPlan(manual as Boolean) as Void {
        if (!System.getDeviceSettings().phoneConnected) {
            if (manual) {
                setStatus("Kein Handy");
            }
            return;
        }
        _manual = manual;
        _polls = 0;
        _pollIn = 0;
        _checking = false;
        loading = false;
        if (manual) {
            setStatus("Lade ...");
        }
        request(saunaId() + ".json", method(:onPlan));
    }

    private function request(file as String, callback as Method(code as Number, data as Dictionary or String or Null) as Void) as Void {
        Communications.makeWebRequest(
            BASE_URL + file,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            callback
        );
    }

    // ---- Abgleich mit der Website: GitHub liest sie nur, wenn die Uhr es anfordert ----

    private function isStale() as Boolean {
        var stored = PlanStore.getPlan();
        return stored != null && stored["live"] == 1 && PlanStore.isOutdated(stored);
    }

    // Tagespläne von gestern immer, sonst einmal am Tag oder auf Wunsch
    private function needsCheck() as Boolean {
        if (isStale() || _manual) {
            return true;
        }
        var checked = Application.Storage.getValue(KEY_CHECKED);
        return !(checked instanceof Array && saunaId().equals(checked[0]) && checked[1] == PlanStore.todayNumber());
    }

    private function startCheck() as Void {
        var stale = isStale();
        var token = WatchUi.loadResource(Rez.Strings.GithubToken) as String;
        if (token.length() == 0) {
            if (stale) {
                setStatus("Kein Token");
            } else if (_manual) {
                setStatus("Aktuell");
            }
            return;
        }
        _checking = true;
        loading = stale;
        if (stale) {
            setStatus("Hole Plan");
        } else if (_manual) {
            setStatus("Prüfe ...");
        }
        Communications.makeWebRequest(
            API_URL + "actions/workflows/update-plans.yml/dispatches",
            { "ref" => "main", "inputs" => { "sauna" => saunaId() } },
            {
                :method => Communications.HTTP_REQUEST_METHOD_POST,
                :headers => {
                    "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON,
                    "Authorization" => "Bearer " + token,
                    "Accept" => "application/vnd.github+json",
                    "User-Agent" => "aufgussplan-watch"
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onDispatch)
        );
    }

    // GitHub antwortet bei Erfolg mit leerem 204; nur klare Ablehnungen sind Fehler
    function onDispatch(code as Number, data as Dictionary or String or Null) as Void {
        if (code == 401 || code == 403 || code == 404 || code == 422) {
            finishCheck((loading || _manual) ? "Fehler " + code : null);
            return;
        }
        Application.Storage.setValue(KEY_CHECKED, [saunaId(), PlanStore.todayNumber()]);
        _polls = 0;
        _pollIn = POLL_TICKS;
    }

    private function finishCheck(text as String?) as Void {
        _checking = false;
        loading = false;
        _pollIn = 0;
        if (text != null) {
            setStatus(text);
        } else {
            WatchUi.requestUpdate();
        }
    }

    private function pollLivePlan() as Void {
        _polls++;
        Communications.makeWebRequest(
            API_URL + "contents/aufgussplan/plans/" + saunaId() + ".json",
            { "t" => Time.now().value() },
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :headers => {
                    "Accept" => "application/vnd.github.raw+json",
                    "User-Agent" => "aufgussplan-watch"
                },
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            method(:onPlan)
        );
    }

    function onPlan(code as Number, data as Dictionary or String or Null) as Void {
        var previous = _previousSauna;
        _previousSauna = null;
        var first = !_checking;
        var updated = false;
        var valid = code == 200 && data instanceof Dictionary && data["schedules"] instanceof Array;
        if (valid) {
            var stored = PlanStore.getPlan();
            var switched = stored == null || !saunaId().equals(stored["id"]);
            updated = switched || PlanStore.versionOf(data as Dictionary) > PlanStore.versionOf(stored as Dictionary);
            if (updated) {
                PlanStore.setPlan(data as Dictionary);
                if (switched) {
                    Application.Storage.deleteValue(KEY_MARKS);
                    rebuildPending();
                }
                reload();
            }
        }
        if (_checking) {
            // Warten auf das Ergebnis der Action: Tagesplan von heute bzw. eine neue Version
            var done = valid && (loading ? !isStale() : updated);
            if (done) {
                finishCheck("Aktualisiert");
            } else if (_polls < (loading ? MAX_POLLS : QUIET_POLLS)) {
                _pollIn = POLL_TICKS;
            } else if (loading) {
                finishCheck("Kein Tagesplan");
            } else {
                finishCheck(_manual ? "Aktuell" : null);
            }
        } else if (valid) {
            if (needsCheck()) {
                startCheck();
            } else if (updated) {
                setStatus("Aktualisiert");
            } else if (_manual) {
                setStatus("Aktuell");
            }
        } else {
            if (previous != null) {
                Application.Storage.setValue(KEY_SAUNA, previous);
            }
            if (_manual) {
                setStatus("Fehler " + code);
            }
        }
        if (first && !_manual) {
            request("index.json", method(:onIndex));
        }
    }

    function onIndex(code as Number, data as Dictionary or String or Null) as Void {
        if (code == 200 && data instanceof Dictionary && data["saunas"] instanceof Array) {
            Application.Storage.setValue(KEY_INDEX, data as Dictionary<Application.PropertyKeyType, Application.PropertyValueType>);
        }
    }
}
