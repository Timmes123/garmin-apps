import Toybox.Lang;
import Toybox.WatchUi;

class SaunaDelegate extends WatchUi.BehaviorDelegate {

    private var _view as SaunaView;

    function initialize(view as SaunaView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.move(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.move(-1);
        return true;
    }

    // START-Taste bzw. Tippen: Plan neu laden
    function onSelect() as Boolean {
        _view.fetchPlan(true);
        return true;
    }
}
