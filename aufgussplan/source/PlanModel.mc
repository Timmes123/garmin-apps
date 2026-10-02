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
    const DEFAULT_SAUNA = "obermaintherme";
    const LEAD_CHOICES = [5, 10, 15, 20];

    const KEY_SAUNA = "sauna";
    const KEY_INDEX = "index";
    const KEY_MARKS = "marks";
    const KEY_LEAD = "lead";

    var plan as Dictionary?;
    var entries as Array = [];
    var lateDay as Boolean = true;
    var sel as Number = 0;
    var status as String?;

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

    function onPlan(code as Number, data as Dictionary or String or Null) as Void {
        var previous = _previousSauna;
        _previousSauna = null;
        if (code == 200 && data instanceof Dictionary && data["schedules"] instanceof Array) {
            var stored = PlanStore.getPlan();
            var switched = stored == null || !saunaId().equals(stored["id"]);
            if (switched || PlanStore.versionOf(data) > PlanStore.versionOf(stored as Dictionary)) {
                PlanStore.setPlan(data);
                if (switched) {
                    Application.Storage.deleteValue(KEY_MARKS);
                    rebuildPending();
                }
                reload();
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
        if (!_manual) {
            request("index.json", method(:onIndex));
        }
    }

    function onIndex(code as Number, data as Dictionary or String or Null) as Void {
        if (code == 200 && data instanceof Dictionary && data["saunas"] instanceof Array) {
            Application.Storage.setValue(KEY_INDEX, data as Dictionary<Application.PropertyKeyType, Application.PropertyValueType>);
        }
    }
}
