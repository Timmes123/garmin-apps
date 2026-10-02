import Toybox.Communications;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class SaunaView extends WatchUi.View {

    const PLAN_URL = "https://raw.githubusercontent.com/Timmes123/garmin-apps/main/plans/obermaintherme.json";

    private var _plan as Dictionary?;
    private var _entries as Array = [];
    private var _lateDay as Boolean = true;
    private var _sel as Number = 0;
    private var _status as String?;
    private var _timer as Timer.Timer?;

    function initialize() {
        View.initialize();
    }

    function onShow() as Void {
        reload();
        _timer = new Timer.Timer();
        (_timer as Timer.Timer).start(method(:onTick), 30000, true);
        fetchPlan(false);
    }

    function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            _timer = null;
        }
    }

    function onTick() as Void {
        WatchUi.requestUpdate();
    }

    // Plan aus dem Speicher lesen und auf den nächsten Aufguss springen
    function reload() as Void {
        _plan = PlanStore.getPlan();
        _entries = PlanStore.todaysEntries(_plan);
        _lateDay = PlanStore.isLateDay(_plan);
        var next = PlanStore.nextIndex(_entries, _lateDay);
        _sel = (next >= 0) ? next : (_entries.size() > 0 ? _entries.size() - 1 : 0);
    }

    function move(delta as Number) as Void {
        var target = _sel + delta;
        if (target >= 0 && target < _entries.size()) {
            _sel = target;
            WatchUi.requestUpdate();
        }
    }

    function fetchPlan(manual as Boolean) as Void {
        if (!System.getDeviceSettings().phoneConnected) {
            if (manual) {
                setStatus("Kein Handy verbunden");
            }
            return;
        }
        if (manual) {
            setStatus("Lade Plan …");
        }
        Communications.makeWebRequest(
            PLAN_URL,
            null,
            {
                :method => Communications.HTTP_REQUEST_METHOD_GET,
                :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
            },
            manual ? method(:onManualResponse) : method(:onAutoResponse)
        );
    }

    function onManualResponse(code as Number, data as Dictionary or String or Null) as Void {
        handleResponse(code, data, true);
    }

    function onAutoResponse(code as Number, data as Dictionary or String or Null) as Void {
        handleResponse(code, data, false);
    }

    private function handleResponse(code as Number, data as Dictionary or String or Null, manual as Boolean) as Void {
        if (code == 200 && data instanceof Dictionary && data["schedules"] instanceof Array) {
            var stored = PlanStore.getPlan();
            if (stored == null || PlanStore.versionOf(data) > PlanStore.versionOf(stored)) {
                PlanStore.setPlan(data);
                reload();
                setStatus("Plan aktualisiert");
            } else if (manual) {
                setStatus("Plan ist aktuell");
            }
        } else if (manual) {
            setStatus("Fehler " + code);
        }
    }

    private function setStatus(text as String) as Void {
        _status = text;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var header = _status;
        if (header == null) {
            header = (_plan != null && (_plan as Dictionary)["name"] instanceof String) ? (_plan as Dictionary)["name"] as String : "Aufgussplan";
        }
        dc.setColor(_status != null ? Graphics.COLOR_YELLOW : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        drawFitted(dc, cx, h * 0.10, header, w * 0.50, [Graphics.FONT_XTINY]);

        if (_entries.size() == 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            drawFitted(dc, cx, h * 0.5, "Heute keine Aufgüsse", w * 0.9, [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
            return;
        }

        var now = PlanStore.nowMinutes();

        if (_sel > 0) {
            drawNeighbour(dc, cx, h * 0.18, _entries[_sel - 1] as Dictionary, w * 0.72);
        }
        if (_sel < _entries.size() - 1) {
            drawNeighbour(dc, cx, h * 0.87, _entries[_sel + 1] as Dictionary, w * 0.60);
        }

        var entry = _entries[_sel] as Dictionary;
        var skipped = !_lateDay && PlanStore.isLateOnly(entry);
        var diff = PlanStore.entryMinutes(entry) - now;

        dc.setColor(skipped ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawFitted(dc, cx, h * 0.33, entry["t"] as String, w * 0.9, [Graphics.FONT_NUMBER_MILD]);
        drawFitted(dc, cx, h * 0.47, entry["n"] as String, w * 0.94,
            [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        drawFitted(dc, cx, h * 0.57, (entry["s"] as String) + " · " + (entry["c"] as String), w * 0.90,
            [Graphics.FONT_TINY, Graphics.FONT_XTINY]);

        drawDrops(dc, cx, (h * 0.66).toNumber(), entry["i"], h / 50);

        var info;
        if (skipped) {
            var note = (_plan as Dictionary)["lateNote"];
            info = (note instanceof String) ? note : "entfällt heute";
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        } else {
            info = PlanStore.countdownText(diff);
            dc.setColor(diff > -15 ? Graphics.COLOR_GREEN : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        }
        drawFitted(dc, cx, h * 0.76, info, w * 0.80, [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
    }

    // Intensität als Tropfen: sichere Tropfen kräftig, die "bis zu"-Tropfen dunkel
    private function drawDrops(dc as Graphics.Dc, cx as Number, y as Number, intensity as Object?, r as Number) as Void {
        if (!(intensity instanceof Array) || intensity.size() == 0) {
            return;
        }
        var min = intensity[0] as Number;
        var max = intensity[intensity.size() - 1] as Number;
        var step = r * 3;
        var x = cx - (max - 1) * step / 2;
        for (var i = 0; i < max; i++) {
            dc.setColor(i < min ? Graphics.COLOR_RED : Graphics.COLOR_DK_RED, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x, y + r / 2, r);
            dc.fillPolygon([[x - r, y], [x + r, y], [x, y - r * 2]]);
            x += step;
        }
    }

    private function drawNeighbour(dc as Graphics.Dc, x as Number, y as Float, entry as Dictionary, maxWidth as Float) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        drawFitted(dc, x, y, (entry["t"] as String) + "  " + (entry["n"] as String), maxWidth, [Graphics.FONT_XTINY]);
    }

    // Zeichnet zentriert mit der größten Schrift, die in maxWidth passt
    private function drawFitted(dc as Graphics.Dc, x as Number, y as Float, text as String, maxWidth as Float, fonts as Array<Graphics.FontDefinition>) as Void {
        var font = fonts[fonts.size() - 1];
        for (var i = 0; i < fonts.size(); i++) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxWidth) {
                font = fonts[i];
                break;
            }
        }
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
