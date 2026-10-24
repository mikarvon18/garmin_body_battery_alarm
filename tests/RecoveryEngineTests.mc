import Toybox.Test;

(:test)
function demoSequenceTriggersAtTarget(logger) {
    var e = new RecoveryEngine(null);
    Test.assert(!e.accept(0, 300, 300, 80));
    Test.assert(!e.accept(1, 600, 600, 80));
    Test.assert(!e.accept(2, 900, 900, 80));
    Test.assert(e.state["phase"].equals("recovering"));
    Test.assert(e.accept(80, 1200, 1200, 80));
    Test.assert(e.state["pending"]);
    // Dismissal consumes the alert, but must retain the session lockout.
    e.state["pending"] = false;
    Test.assert(!e.accept(80, 1500, 1500, 80));
    Test.assert(!e.state["pending"]);
    Test.assert(e.state["phase"].equals("alarmed"));
    return true;
}

(:test)
function restoredStringValuesPreserveLockout(logger) {
    var e = new RecoveryEngine({ "phase" => "ALARMED".toLower(),
        "previous" => 80, "stamp" => 900, "rises" => 2,
        "peak" => 80, "pending" => false });
    Test.assert(!e.accept(81, 1200, 1200, 80));
    Test.assert(e.state["peak"] == 81);
    Test.assert(!e.accept(76, 1500, 1500, 80));
    Test.assert(e.state["phase"].equals("waiting"));
    return true;
}

(:test)
function reachesTargetOnce(logger) {
    var e = new RecoveryEngine(null);
    Test.assert(!e.accept(77, 300, 300, 80));
    Test.assert(!e.accept(78, 600, 600, 80));
    Test.assert(e.accept(80, 900, 900, 80));
    Test.assert(!e.accept(81, 1200, 1200, 80));
    Test.assert(!e.accept(85, 1500, 1500, 80));
    return true;
}

(:test)
function duplicateAndMissingSamplesDoNotCreateTrend(logger) {
    var e = new RecoveryEngine(null);
    e.accept(78, 300, 300, 80);
    e.accept(79, 600, 600, 80);
    Test.assert(!e.accept(80, 600, 600, 80));
    Test.assert(!e.accept(null, 900, 900, 80));
    Test.assert(!e.accept(80, 900, 2401, 80));
    Test.assert(!e.accept(80, 3000, 2401, 80));
    Test.assert(e.state["previous"] == 79);
    return true;
}

(:test)
function lockoutSurvivesRestartAndMidnight(logger) {
    var e = new RecoveryEngine(null);
    e.accept(78, 85500, 85500, 80);
    e.accept(79, 85800, 85800, 80);
    Test.assert(e.accept(80, 86100, 86100, 80));
    var restored = new RecoveryEngine(e.state);
    Test.assert(!restored.accept(81, 86400, 86400, 80));
    Test.assert(restored.state["phase"].equals("alarmed"));
    return true;
}

(:test)
function fivePointDropRearmsAndRequiresNewRecovery(logger) {
    var e = new RecoveryEngine(null);
    e.accept(78, 300, 300, 80);
    e.accept(79, 600, 600, 80);
    e.accept(80, 900, 900, 80);
    e.accept(84, 1200, 1200, 80);
    e.accept(80, 1500, 1500, 80);
    Test.assert(e.state["phase"].equals("alarmed"));
    Test.assert(!e.accept(79, 1800, 1800, 80));
    Test.assert(e.state["phase"].equals("waiting"));
    Test.assert(!e.accept(80, 2100, 2100, 80));
    Test.assert(e.accept(81, 2400, 2400, 80));
    return true;
}

(:test)
function flatRecoveryAndUnreachableTarget(logger) {
    var e = new RecoveryEngine(null);
    e.accept(50, 300, 300, 80);
    e.accept(51, 600, 600, 80);
    e.accept(52, 900, 900, 80);
    Test.assert(!e.accept(52, 1200, 1200, 80));
    Test.assert(e.state["phase"].equals("recovering"));
    Test.assert(!e.accept(51, 1500, 1500, 80));
    Test.assert(e.state["phase"].equals("waiting"));
    return true;
}

(:test)
function longGapRequiresNewBaseline(logger) {
    var e = new RecoveryEngine(null);
    e.accept(78, 300, 300, 80);
    e.accept(79, 600, 600, 80);
    Test.assert(!e.accept(80, 3000, 3000, 80));
    Test.assert(!e.accept(81, 3300, 3300, 80));
    Test.assert(e.accept(82, 3600, 3600, 80));
    return true;
}

(:test)
function maximumTargetAndInvalidReadings(logger) {
    var e = new RecoveryEngine(null);
    Test.assert(!e.accept(-1, 100, 100, 100));
    Test.assert(!e.accept(101, 200, 200, 100));
    e.accept(98, 300, 300, 100);
    e.accept(99, 600, 600, 100);
    Test.assert(e.accept(100, 900, 900, 100));
    Test.assert(!e.accept(100, 1200, 1200, 100));
    return true;
}
