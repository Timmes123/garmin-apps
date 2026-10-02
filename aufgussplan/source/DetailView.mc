import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Ein Aufguss groß, mit Erinnerung über START
class DetailView extends WatchUi.View {

    private var _model as PlanModel;

    function initialize(model as PlanModel) {
        View.initialize();
        _model = model;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var entry = _model.selected();
        if (entry == null) {
            return;
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.09, Graphics.FONT_XTINY, Draw.clockText(), Draw.CENTER);

        var skipped = _model.isSkipped(entry);
        var diff = PlanStore.entryMinutes(entry) - PlanStore.nowMinutes();

        dc.setColor(skipped ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        Draw.fitted(dc, cx, h * 0.25, entry["t"] as String, w * 0.9, [Graphics.FONT_NUMBER_MILD]);
        Draw.fitted(dc, cx, h * 0.40, entry["n"] as String, w * 0.94,
            [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        Draw.fitted(dc, cx, h * 0.51, (entry["s"] as String) + " · " + (entry["c"] as String), w * 0.92,
            [Graphics.FONT_TINY, Graphics.FONT_XTINY]);

        var r = h / 45;
        Draw.drops(dc, cx - Draw.dropsWidth(entry["i"], r) / 2, (h * 0.615).toNumber(), entry["i"], r, false);

        var info;
        if (skipped) {
            var note = (_model.plan as Dictionary)["lateNote"];
            info = (note instanceof String) ? note : "entfällt heute";
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        } else {
            info = PlanStore.countdownText(diff);
            dc.setColor(diff > -15 ? Graphics.COLOR_GREEN : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        }
        Draw.fitted(dc, cx, h * 0.72, info, w * 0.84, [Graphics.FONT_TINY, Graphics.FONT_XTINY]);

        if (_model.isMarked(entry)) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            Draw.fitted(dc, cx, h * 0.84, "Erinnerung " + _model.lead() + " min", w * 0.66, [Graphics.FONT_XTINY]);
        } else {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            Draw.fitted(dc, cx, h * 0.84, "START: erinnern", w * 0.66, [Graphics.FONT_XTINY]);
        }
    }
}

class DetailDelegate extends WatchUi.BehaviorDelegate {

    private var _model as PlanModel;

    function initialize(model as PlanModel) {
        BehaviorDelegate.initialize();
        _model = model;
    }

    function onNextPage() as Boolean {
        _model.move(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _model.move(-1);
        return true;
    }

    // START-Taste bzw. Tippen: Erinnerung an- oder abschalten
    function onSelect() as Boolean {
        var entry = _model.selected();
        if (entry != null) {
            _model.toggleMark(entry);
        }
        return true;
    }
}

// Meldung, wenn eine Erinnerung fällig wird, während die App offen ist
class AlertView extends WatchUi.View {

    private var _texts as Array<String>;

    function initialize(texts as Array<String>) {
        View.initialize();
        _texts = texts;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.26, Graphics.FONT_SMALL, "Gleich geht's los", Draw.CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < _texts.size() && i < 3; i++) {
            Draw.fitted(dc, w / 2, h * (0.44 + 0.13 * i), _texts[i], w * 0.92,
                [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        }
    }
}

class AlertDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }
}
