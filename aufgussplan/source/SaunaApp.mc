import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SaunaApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        installBundledPlan();
        var view = new SaunaView();
        return [view, new SaunaDelegate(view)];
    }

    (:glance)
    function getGlanceView() as [GlanceView] or [GlanceView, GlanceViewDelegate] or Null {
        return [new SaunaGlanceView()];
    }

    // Der mitgelieferte Plan ersetzt den gespeicherten nur, wenn er neuer ist.
    function installBundledPlan() as Void {
        var bundled = WatchUi.loadResource(Rez.JsonData.DefaultPlan) as Dictionary;
        var stored = PlanStore.getPlan();
        if (stored == null || PlanStore.versionOf(stored) < PlanStore.versionOf(bundled)) {
            PlanStore.setPlan(bundled);
        }
    }
}
