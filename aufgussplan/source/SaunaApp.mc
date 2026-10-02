import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

(:background, :glance)
class SaunaApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var model = new PlanModel();
        model.start();
        return [new ListView(model), new ListDelegate(model)];
    }

    function getGlanceView() as [GlanceView] or [GlanceView, GlanceViewDelegate] or Null {
        return [new SaunaGlanceView()];
    }

    function getServiceDelegate() as [System.ServiceDelegate] {
        return [new SaunaService()];
    }
}
