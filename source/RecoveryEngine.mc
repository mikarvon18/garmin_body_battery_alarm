import Toybox.Lang;

// Pure state machine shared by the foreground, background and simulator tests.
(:background)
class RecoveryEngine {
    var state;

    function initialize(saved) {
        state = saved;
        if (state == null) {
            state = { "phase" => "waiting", "previous" => null,
                "stamp" => null, "rises" => 0, "peak" => null,
                "pending" => false };
        }
    }

    // Returns true only on the transition into the alarmed state.
    function accept(value, stamp, now, target) {
        if (value == null || stamp == null || value < 0 || value > 100) {
            return false;
        }
        // Ignore stale, future, duplicate and out-of-order history entries.
        if (stamp > now || now - stamp > 1200 ||
            (state["stamp"] != null && stamp <= state["stamp"])) {
            return false;
        }

        var previous = state["previous"];
        // Missing data must not fabricate a recovery trend. Preserve lockout.
        if (state["stamp"] != null && stamp - state["stamp"] > 1800 &&
            !state["phase"].equals("alarmed")) {
            state["phase"] = "waiting";
            state["rises"] = 0;
            previous = null;
        }
        state["previous"] = value;
        state["stamp"] = stamp;

        // Stored phase strings must be compared by value, not object identity.
        if (state["phase"].equals("alarmed")) {
            if (value > state["peak"]) { state["peak"] = value; }
            if (value <= state["peak"] - 5) {
                state["phase"] = "waiting";
                state["rises"] = 0;
                state["pending"] = false;
                state["peak"] = null;
            }
            return false;
        }

        if (previous == null) { return false; }
        if (value > previous) {
            state["rises"] += 1;
            if (state["rises"] >= 2) { state["phase"] = "recovering"; }
        } else if (value < previous) {
            state["rises"] = 0;
            state["phase"] = "waiting";
        } else if (state["phase"].equals("waiting")) {
            state["rises"] = 0;
        }

        if (state["phase"].equals("recovering") && value >= target) {
            state["phase"] = "alarmed";
            state["peak"] = value;
            state["pending"] = true;
            return true;
        }
        return false;
    }
}
