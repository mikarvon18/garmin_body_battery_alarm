import Toybox.Application;
import Toybox.SensorHistory;
import Toybox.Time;
import Toybox.Background;
import Toybox.System;

(:background)
module RecoveryStore {
    function target() {
        var value = Application.Storage.getValue("target");
        if (value == null || value < 1 || value > 100) { return 80; }
        return value;
    }
    function enabled() { return Application.Storage.getValue("enabled") == true; }
    function load() { return new RecoveryEngine(Application.Storage.getValue("recovery-v1")); }
    function save(engine) { Application.Storage.setValue("recovery-v1", engine.state); }

    function poll() {
        if (!enabled()) { return false; }
        if (!(Toybox has :SensorHistory) ||
            !(Toybox.SensorHistory has :getBodyBatteryHistory)) { return false; }
        var iterator = SensorHistory.getBodyBatteryHistory({ :period => 1,
            :order => SensorHistory.ORDER_NEWEST_FIRST });
        var sample = iterator.next();
        if (sample == null || sample.data == null || sample.when == null) { return false; }
        var engine = load();
        var fired = engine.accept(sample.data, sample.when.value(), Time.now().value(), target());
        save(engine);
        return fired;
    }
}

(:background)
class RecoveryService extends System.ServiceDelegate {
    function initialize() { ServiceDelegate.initialize(); }
    function onTemporalEvent() {
        var testAt = Application.Storage.getValue("background-test-at");
        var testDue = testAt != null && Time.now().value() >= testAt;
        if (testDue) {
            // Consume before requesting the prompt: this test is strictly one-shot.
            Application.Storage.deleteValue("background-test-at");
            Application.Storage.setValue("background-test-fired", Time.now().value());
        }
        var fired = RecoveryStore.poll();
        if (fired) {
            Background.requestApplicationWake("Recovery target reached. Open Rested?");
        } else if (testDue) {
            Background.requestApplicationWake("Rested background test. Did your watch vibrate?");
        }
        if (testDue) {
            if (RecoveryStore.enabled()) {
                Background.registerForTemporalEvent(new Time.Duration(300));
            } else {
                Background.deleteTemporalEvent();
            }
        }
        Background.exit(fired);
    }
}
