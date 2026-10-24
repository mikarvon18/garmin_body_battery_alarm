# Rested

A Garmin Venu 2 school prototype exploring empathy through recovery: choose a Body Battery target instead of a wake-up time. Written in Monkey C for Connect IQ. No time window, deadline alarm, account, phone service, or external server.

## Current status

Compiled with Connect IQ SDK 9.2.0 for Venu 2. All nine recovery-engine tests pass in Garmin's simulator, including the demo sequence and restored-string lockout regression tests. The initial build was installed on a Venu 2; its reported demo failure was traced to string identity comparisons and corrected with value comparisons. The corrected on-watch UI/vibration behaviour and overnight operation still need device verification. Do not treat the prototype as a verified wake-up alarm.

## Behaviour

- Tap the main screen for settings. Choose a target from 5–100% in five-point steps (default 80%) and enable monitoring. Monitoring starts paused.
- Foreground and background checks run approximately every five minutes. Only a new, valid sensor timestamp can advance recovery detection. Readings older than 20 minutes are ignored.
- Two consecutive increases establish recovery. Flat readings preserve an established recovery session; a decline ends it. A gap over 30 minutes requires a new baseline unless already locked after an alarm.
- At or above the target during recovery, trigger once. A five-point decline from the highest reading after that alarm rearms detection. Closing/reopening the app, midnight, changing the target, and pausing/resuming do not remove the lockout.
- A confirmed recovery trend that starts above the target also triggers. If the target is never reached, there is no alarm.
- The app uses recovery as a heuristic; it does not establish whether someone is asleep or measure required sleep duration.

## Background limitation

`Background.requestApplicationWake()` displays a system confirmation asking the user to open the app. It is not an API for setting Garmin's native alarm and does not guarantee an unattended repeating vibration alarm. Accepting opens Rested, where a pending alert starts the vibration screen; a target reached with Rested visible also starts that screen. Tap to dismiss. The service requests the prompt only once per recovery session, even if declined. A pending alert can appear when the app is later opened, until consumed or the session rearms.

Screen-off, sleep mode, Do Not Disturb, background scheduling, battery use, sensor cadence and vibration behaviour need testing on the actual Venu 2. No display or activity-recording workaround is used to force the app to remain open overnight.

## Classroom demo

### Background vibration test

Select **Test background alert** in settings, then press Back to leave Rested and return to the normal watch face. After about five minutes, the background service requests a system prompt: **Rested background test. Did your watch vibrate?** Observe whether the watch vibrates before accepting anything. This test does not start the foreground vibration alarm, needs no Body Battery data and works with monitoring paused. It fires once and leaves the recovery state untouched when monitoring is paused. When real monitoring is enabled, normal sampling continues and a real target crossing takes priority over the test prompt.

You can cancel an armed test from settings. Reopening Rested before it fires can delay it by another five minutes to respect Garmin scheduling limits. Repeat with your intended overnight sleep/Do Not Disturb settings: prompt vibration is controlled by the device, not Rested. A successful daytime test does not establish overnight reliability.

1. Tap the screen and select **Try demo**. Real monitoring may remain paused.
2. The screen clearly says **DEMO**. It starts at 0; each tap adds 5, up to 100.
3. The target triggers the vibration screen. Tap to dismiss.
4. Continue tapping after dismissal to advance by 5 to 100 without another alarm. Further taps hold at 100. For a target of 5, recovery requires two increases, so the alarm triggers at 10.
5. Use Back to exit the demo, or Back once to dismiss an active alarm and again to exit.

Demo readings live only in memory, use the same recovery engine and never overwrite real sensor history or lockout. If real monitoring is enabled, its background service remains active during the demo. A live alert may therefore be pending on return.

## Build and run

1. Install Garmin's [Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/), a current SDK, and the **Venu 2** device package.
2. Install Garmin's Monkey C extension for VS Code. Open this folder and configure the SDK and a developer signing key through the extension. Keep the key private; do not commit it.
3. Use the extension's build/run workflow, select Venu 2, and run in the simulator. Use **Try demo** for deterministic readings.

Alternatively, from PowerShell, with your actual paths:

```powershell
.\scripts\build.ps1 -SdkPath 'C:\path\to\connectiq-sdk' -DeveloperKey 'C:\private\developer_key.der'
.\scripts\build.ps1 -SdkPath 'C:\path\to\connectiq-sdk' -DeveloperKey 'C:\private\developer_key.der' -Tests
```

Run the test build with Garmin's simulator test workflow (or `monkeydo.bat bin\Rested-tests.prg venu2 /t` with the simulator running). The nine tests cover the exact demo sequence, restored string state, target crossing, duplicate/stale/future readings, restart/midnight lockout, five-point rearming, flat/decreasing readings, gaps and the maximum threshold.

To sideload after successful compilation, connect the Venu 2 by USB and copy `bin/Rested.prg` into the device's `GARMIN/APPS` directory. Disconnect and open Rested from the watch's apps. Device copying is not performed by the build script.

## Device acceptance checks

- Check all text fits the round display; select a different threshold and reopen the app to confirm persistence.
- Run the demo; confirm vibration starts, dismissal stops it and subsequent taps do not retrigger.
- Enable real monitoring and compare its reading with Garmin's Body Battery screen after fresh samples arrive.
- Close Rested and test a background target crossing; record prompt/vibration behaviour with sleep mode and Do Not Disturb both on and off.
- Dismiss or decline an alert, reopen, and confirm no new recovery alarm occurs until a five-point drop followed by a new rising trend.
- Pause monitoring and confirm no new background prompts occur.

## Structure and scope

- `source/RecoveryEngine.mc`: platform-independent state transitions.
- `source/RecoveryMonitor.mc`: sensor access, persistence and background service.
- `source/RecoveryApp.mc`: app lifecycle and scheduling.
- `source/RecoveryView.mc`: watch UI, settings, foreground vibration and demo.
- `tests/RecoveryEngineTests.mc`: simulator unit tests.

The low-energy bedtime reminder, other watch models and Connect IQ Store publishing are deferred. Before publishing, compile and test on Venu 2, verify the background experience, prepare store assets and clearly describe its recovery heuristic and alarm limitations. The manifest deliberately targets only Venu 2.

## API references

- [Body Battery history and device support](https://developer.garmin.com/connect-iq/api-docs/Toybox/SensorHistory.html#getBodyBatteryHistory-instance_function)
- [Background scheduling and application wake prompts](https://developer.garmin.com/connect-iq/api-docs/Toybox/Background.html)
- [Vibration](https://developer.garmin.com/connect-iq/api-docs/Toybox/Attention.html)
