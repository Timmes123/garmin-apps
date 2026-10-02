import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

(:glance)
class SaunaGlanceView extends WatchUi.GlanceView {

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        var h = dc.getHeight();
        var top = "Aufgussplan";
        var bottom = "App öffnen";

        var plan = PlanStore.getPlan();
        if (plan != null) {
            var entries = PlanStore.todaysEntries(plan);
            var next = PlanStore.nextIndex(entries, PlanStore.isLateDay(plan));
            if (next >= 0) {
                var entry = entries[next] as Dictionary;
                var diff = PlanStore.entryMinutes(entry) - PlanStore.nowMinutes();
                top = (entry["t"] as String) + " · " + PlanStore.countdownText(diff);
                bottom = entry["n"] as String;
            } else {
                bottom = "Heute keine Aufgüsse mehr";
            }
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 0.28, Graphics.FONT_TINY, top, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(0, h * 0.72, Graphics.FONT_XTINY, bottom, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
