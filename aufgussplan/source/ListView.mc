import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Tagesliste: der gewählte Aufguss steht ausführlich in der Mitte, je zwei Einträge darüber und darunter
class ListView extends WatchUi.View {

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

        var status = _model.status;
        if (status != null) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            Draw.fitted(dc, cx, h * 0.08, status, w * 0.52, [Graphics.FONT_XTINY]);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.08, Graphics.FONT_XTINY, Draw.clockText(), Draw.CENTER);
        }

        var entries = _model.entries;
        if (entries.size() == 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            Draw.fitted(dc, cx, h * 0.5, _model.plan == null ? "Kein Plan geladen" : "Heute keine Aufgüsse", w * 0.9,
                [Graphics.FONT_SMALL, Graphics.FONT_TINY]);
            return;
        }

        var now = PlanStore.nowMinutes();
        var sel = _model.sel;

        var offsets = [-2, -1, 1, 2];
        var ys = [0.18, 0.29, 0.72, 0.83];
        var widths = [0.73, 0.88, 0.88, 0.71];
        for (var i = 0; i < offsets.size(); i++) {
            var idx = sel + offsets[i];
            if (idx >= 0 && idx < entries.size()) {
                drawRow(dc, cx, (h * ys[i]).toNumber(), entries[idx] as Dictionary, w * widths[i], now);
            }
        }

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(w * 0.12, h * 0.345, w * 0.88, h * 0.345);
        dc.drawLine(w * 0.12, h * 0.665, w * 0.88, h * 0.665);

        drawSelected(dc, cx, w, h, entries[sel] as Dictionary, now);
    }

    private function drawSelected(dc as Graphics.Dc, cx as Number, w as Number, h as Number, entry as Dictionary, now as Number) as Void {
        var skipped = _model.isSkipped(entry);
        var diff = PlanStore.entryMinutes(entry) - now;
        var textColor = skipped ? Graphics.COLOR_LT_GRAY : Graphics.COLOR_WHITE;

        // Zeile 1: Markierung, Uhrzeit, Tropfen
        var r = h / 55;
        var gap = r * 2;
        var time = entry["t"] as String;
        var timeWidth = dc.getTextWidthInPixels(time, Graphics.FONT_MEDIUM);
        var dropsWidth = Draw.dropsWidth(entry["i"], r);
        var markWidth = _model.isMarked(entry) ? r * 4 : 0;
        var total = markWidth + timeWidth + (dropsWidth > 0 ? gap + dropsWidth : 0);
        var x = cx - total / 2;
        var y = (h * 0.41).toNumber();
        if (markWidth > 0) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + r, y, r);
            x += markWidth;
        }
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_MEDIUM, time, Draw.LEFT);
        Draw.drops(dc, x + timeWidth + gap, y, entry["i"], r, false);

        // Zeile 2: Name
        dc.setColor(textColor, Graphics.COLOR_TRANSPARENT);
        Draw.fitted(dc, cx, h * 0.51, entry["n"] as String, w * 0.94,
            [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);

        // Zeile 3: Sauna und Countdown
        var font = Graphics.FONT_XTINY;
        var info = skipped ? "entfällt" : PlanStore.countdownText(diff);
        var infoWidth = dc.getTextWidthInPixels(info, font);
        var sauna = Draw.truncate(dc, entry["s"] as String, font, w * 0.90 - infoWidth - gap * 2);
        var saunaWidth = dc.getTextWidthInPixels(sauna, font);
        x = cx - (saunaWidth + gap * 2 + infoWidth) / 2;
        y = (h * 0.605).toNumber();
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, sauna, Draw.LEFT);
        dc.setColor(!skipped && diff > -15 ? Graphics.COLOR_GREEN : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + saunaWidth + gap * 2, y, font, info, Draw.LEFT);
    }

    // Einzeilige Nachbarzeile: Markierung, Uhrzeit, Name, Tropfen
    private function drawRow(dc as Graphics.Dc, cx as Number, y as Number, entry as Dictionary, maxWidth as Float, now as Number) as Void {
        var font = Graphics.FONT_XTINY;
        var dim = _model.isSkipped(entry) || PlanStore.entryMinutes(entry) < now - 14;
        var r = dc.getHeight() / 90;
        var gap = r * 2;
        var dropsWidth = Draw.dropsWidth(entry["i"], r);
        if (dropsWidth > 0) {
            dropsWidth += gap;
        }
        var markWidth = _model.isMarked(entry) ? r * 4 : 0;
        var text = Draw.truncate(dc, (entry["t"] as String) + " " + (entry["n"] as String), font, maxWidth - dropsWidth - markWidth);
        var textWidth = dc.getTextWidthInPixels(text, font);
        var x = cx - (markWidth + textWidth + dropsWidth) / 2;
        if (markWidth > 0) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x + r, y, r);
            x += markWidth;
        }
        dc.setColor(dim ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, Draw.LEFT);
        Draw.drops(dc, x + textWidth + gap, y, entry["i"], r, dim);
    }
}

class ListDelegate extends WatchUi.BehaviorDelegate {

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

    // START-Taste bzw. Tippen: Details zum gewählten Aufguss
    function onSelect() as Boolean {
        if (_model.selected() != null) {
            WatchUi.pushView(new DetailView(_model), new DetailDelegate(_model), WatchUi.SLIDE_LEFT);
        }
        return true;
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new MainMenu(_model), new MainMenuDelegate(_model), WatchUi.SLIDE_UP);
        return true;
    }
}
