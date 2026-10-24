import Toybox.Application;
import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

class RecoveryView extends WatchUi.View {
    var timer;
    var ticks = 0;
    var alarm = false;
    var demo = null;
    var demoIndex = 0;
    var demoStamp = 0;
    var demoTarget = 80;

    function initialize() { View.initialize(); timer = new Timer.Timer(); }
    function onShow() {
        if (demo == null) { RecoveryStore.poll(); }
        timer.start(method(:tick), 1000, true);
        WatchUi.requestUpdate();
    }
    function onHide() { timer.stop(); stopVibration(); }
    function tick() {
        ticks += 1;
        if (demo == null && ticks % 300 == 0) { RecoveryStore.poll(); }
        if (demo == null && !RecoveryStore.enabled()) { alarm = false; }
        var engine = current();
        if (engine.state["pending"] && (demo != null || RecoveryStore.enabled())) {
            engine.state["pending"] = false;
            if (demo == null) { RecoveryStore.save(engine); }
            alarm = true;
            vibrate();
        }
        if (alarm && ticks % 4 == 0) { vibrate(); }
        WatchUi.requestUpdate();
    }
    function current() { return demo == null ? RecoveryStore.load() : demo; }
    function vibrate() {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(70, 700),
                new Attention.VibeProfile(0, 300), new Attention.VibeProfile(70, 700)]);
        }
    }
    function stopVibration() {
        if (Attention has :vibrate) { Attention.vibrate([]); }
    }
    function dismiss() { alarm = false; stopVibration(); WatchUi.requestUpdate(); }

    function startDemo() {
        // Demo state is in memory only; real monitoring and its lockout are untouched.
        demo = new RecoveryEngine(null);
        demoIndex = 0;
        demoStamp = 0;
        demoTarget = RecoveryStore.target();
        alarm = false;
        advanceDemo();
    }
    function advanceDemo() {
        // Advance 0, 5, 10, ... 100, then hold at 100 until the demo exits.
        if (demoIndex > 20) { return; }
        demoStamp += 300;
        demo.accept(demoIndex * 5, demoStamp, demoStamp, demoTarget);
        demoIndex += 1;
        tick();
    }
    function exitDemo() { dismiss(); demo = null; WatchUi.requestUpdate(); }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var center = w / 2;
        var engine = current();
        var value = engine.state["previous"];
        var target = demo == null ? RecoveryStore.target() : demoTarget;
        var accent = alarm ? 0xFFCF85 : 0x85E0B0;
        // Stack measured font boxes rather than independently positioning text.
        // NUMBER_HOT is taller on Venu 2 than the old percentage gap allowed.
        var gap = (h * 0.025).toNumber();
        var smallHeight = dc.getFontHeight(Graphics.FONT_SMALL);
        var tinyHeight = dc.getFontHeight(Graphics.FONT_XTINY);
        var numberFont = Graphics.FONT_NUMBER_HOT;
        var numberHeight = dc.getFontHeight(numberFont);
        var blockHeight = smallHeight * 2 + tinyHeight * 3 + numberHeight + gap * 5;
        if (blockHeight > h * 0.80) {
            numberFont = Graphics.FONT_NUMBER_MEDIUM;
            numberHeight = dc.getFontHeight(numberFont);
            blockHeight = smallHeight * 2 + tinyHeight * 3 + numberHeight + gap * 5;
        }
        var y = ((h - blockHeight) / 2).toNumber();
        dc.setColor(0x101B22, 0x101B22);
        dc.clear();
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, y, Graphics.FONT_SMALL,
            demo != null ? "RESTED / DEMO" : "RESTED", Graphics.TEXT_JUSTIFY_CENTER);
        y += smallHeight + gap;
        dc.drawText(center, y, numberFont,
            value == null ? "--" : value.format("%d"), Graphics.TEXT_JUSTIFY_CENTER);
        y += numberHeight + gap;
        dc.setColor(0xAEC0CA, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, y, Graphics.FONT_XTINY,
            "BODY BATTERY / 100", Graphics.TEXT_JUSTIFY_CENTER);
        y += tinyHeight + gap;
        var label = "Waiting for recovery";
        if (engine.state["phase"].equals("recovering")) { label = "Recovering"; }
        if (engine.state["phase"].equals("alarmed")) { label = "Alarm completed"; }
        if (demo == null && !RecoveryStore.enabled()) { label = "Monitoring paused"; }
        else if (demo == null && (engine.state["stamp"] == null ||
            Time.now().value() - engine.state["stamp"] > 1200)) { label = "Waiting for fresh data"; }
        if (alarm) { label = "Target reached"; }
        var testAt = Application.Storage.getValue("background-test-at");
        if (!alarm && demo == null && testAt != null) { label = "Test armed: exit app"; }
        var statusFont = Graphics.FONT_SMALL;
        if (dc.getTextWidthInPixels(label, statusFont) > w * 0.82) {
            statusFont = Graphics.FONT_XTINY;
        }
        dc.setColor(accent, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, y, statusFont, label, Graphics.TEXT_JUSTIFY_CENTER);
        y += smallHeight + gap;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(center, y, Graphics.FONT_XTINY,
            "Target " + target + "%", Graphics.TEXT_JUSTIFY_CENTER);
        y += tinyHeight + gap;
        dc.drawText(center, y, Graphics.FONT_XTINY,
            alarm ? "Tap to dismiss" : (demo != null ? "Tap +5 / Back exits" : "Tap for settings"),
            Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class RecoveryDelegate extends WatchUi.BehaviorDelegate {
    var view;
    function initialize(v) { BehaviorDelegate.initialize(); view = v; }
    function onTap(event) { return onSelect(); }
    function onSelect() {
        if (view.alarm) { view.dismiss(); }
        else if (view.demo != null) { view.advanceDemo(); }
        else { showSettings(); }
        return true;
    }
    function onMenu() {
        if (view.alarm) { view.dismiss(); }
        if (view.demo != null) { view.exitDemo(); }
        showSettings();
        return true;
    }
    function onBack() {
        if (view.alarm) { view.dismiss(); return true; }
        if (view.demo != null) { view.exitDemo(); return true; }
        return false;
    }
    function showSettings() {
        var menu = new WatchUi.Menu2({ :title => "Rested" });
        menu.addItem(new WatchUi.MenuItem("Recovery target", RecoveryStore.target() + "%", :target, {}));
        menu.addItem(new WatchUi.MenuItem(RecoveryStore.enabled() ? "Pause monitoring" : "Enable monitoring", null, :toggle, {}));
        menu.addItem(new WatchUi.MenuItem("Try demo", "Tap through recovery", :demo, {}));
        var testAt = Application.Storage.getValue("background-test-at");
        menu.addItem(new WatchUi.MenuItem(testAt == null ? "Test background alert" : "Cancel background test",
            testAt == null ? "In 5 min; then exit app" : "Test is armed", :backgroundTest, {}));
        WatchUi.pushView(menu, new SettingsDelegate(view), WatchUi.SLIDE_UP);
    }
}

class SettingsDelegate extends WatchUi.Menu2InputDelegate {
    var view;
    function initialize(v) { Menu2InputDelegate.initialize(); view = v; }
    function onSelect(item) {
        var id = item.getId();
        if (id == :target) {
            var picker = new WatchUi.Menu2({ :title => "Target percentage" });
            for (var n = 5; n <= 100; n += 5) {
                picker.addItem(new WatchUi.MenuItem(n + "%", null, n, {}));
            }
            WatchUi.pushView(picker, new TargetDelegate(item), WatchUi.SLIDE_UP);
            return;
        }
        if (id == :toggle) {
            var enable = !RecoveryStore.enabled();
            Application.Storage.setValue("enabled", enable);
            // Preserve an existing alarm lockout when toggling monitoring.
            var engine = RecoveryStore.load();
            engine.state["pending"] = false;
            if (!engine.state["phase"].equals("alarmed")) {
                engine = new RecoveryEngine(null);
            }
            RecoveryStore.save(engine);
            Application.getApp().schedule();
        } else if (id == :demo) { view.startDemo(); }
        else if (id == :backgroundTest) {
            if (Application.Storage.getValue("background-test-at") == null) {
                Application.Storage.setValue("background-test-at", Time.now().value() + 300);
                Application.Storage.deleteValue("background-test-fired");
            } else {
                Application.Storage.deleteValue("background-test-at");
            }
            Application.getApp().schedule();
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class TargetDelegate extends WatchUi.Menu2InputDelegate {
    var parentItem;
    function initialize(item) { Menu2InputDelegate.initialize(); parentItem = item; }
    function onSelect(item) {
        Application.Storage.setValue("target", item.getId());
        parentItem.setSubLabel(item.getId() + "%");
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
