import Toybox.Application;
import Toybox.Background;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class RecoveryApp extends Application.AppBase {
    function initialize() { AppBase.initialize(); }

    (:foreground)
    function onStart(state) { schedule(); }

    (:foreground)
    function schedule() {
        var testAt = Application.Storage.getValue("background-test-at");
        if (testAt != null) {
            // Reopening the app must not cancel an armed test.
            var nextAt = testAt;
            if (nextAt < Time.now().value() + 300) { nextAt = Time.now().value() + 300; }
            Background.registerForTemporalEvent(new Time.Moment(nextAt));
        } else if (RecoveryStore.enabled()) {
            Background.registerForTemporalEvent(new Time.Duration(300));
        } else {
            Background.deleteTemporalEvent();
        }
    }

    (:foreground)
    function getInitialView() {
        var view = new RecoveryView();
        return [view, new RecoveryDelegate(view)];
    }

    function getServiceDelegate() { return [new RecoveryService()]; }

    (:foreground)
    function onBackgroundData(data) { WatchUi.requestUpdate(); }
}
