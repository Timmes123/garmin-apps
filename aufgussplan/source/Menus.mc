import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class MainMenu extends WatchUi.Menu2 {

    function initialize(model as PlanModel) {
        Menu2.initialize({ :title => "Aufgussplan" });
        addItem(new WatchUi.MenuItem("Sauna", model.saunaName(), :sauna, null));
        addItem(new WatchUi.MenuItem("Plan aktualisieren", model.planInfo(), :refresh, null));
        addItem(new WatchUi.MenuItem("Erinnerung", model.lead() + " min vorher", :lead, null));
        addItem(new WatchUi.ToggleMenuItem("Masken & Rituale",
            { :enabled => "werden angezeigt", :disabled => "ausgeblendet" }, :rituals, !PlanStore.hideRituals(), null));
    }
}

class MainMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _model as PlanModel;

    function initialize(model as PlanModel) {
        Menu2InputDelegate.initialize();
        _model = model;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :sauna) {
            WatchUi.pushView(new SaunaMenu(_model), new SaunaMenuDelegate(_model), WatchUi.SLIDE_LEFT);
        } else if (id == :refresh) {
            _model.fetchPlan(true, true);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        } else if (id == :lead) {
            item.setSubLabel(_model.cycleLead() + " min vorher");
            WatchUi.requestUpdate();
        } else if (id == :rituals) {
            Application.Storage.setValue(PlanStore.KEY_HIDE_RITUALS, !(item as WatchUi.ToggleMenuItem).isEnabled());
            _model.reload();
        }
    }
}

class SaunaMenu extends WatchUi.Menu2 {

    function initialize(model as PlanModel) {
        Menu2.initialize({ :title => "Sauna" });
        var saunas = model.saunaList();
        for (var i = 0; i < saunas.size(); i++) {
            var sauna = saunas[i] as Dictionary;
            addItem(new WatchUi.MenuItem(sauna["name"] as String, sauna["city"] as String?, sauna["id"] as String, null));
        }
    }
}

class SaunaMenuDelegate extends WatchUi.Menu2InputDelegate {

    private var _model as PlanModel;

    function initialize(model as PlanModel) {
        Menu2InputDelegate.initialize();
        _model = model;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        _model.selectSauna(item.getId() as String);
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
