import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Buzzes the phone in an unmistakable "something is wrong" pattern.
/// Used when an SOS push arrives while the app is OPEN. When the app is
/// closed or backgrounded the phone vibrates by itself, via the
/// `sos_alerts` notification channel created in MainActivity.kt.
///
/// Pattern is [wait, buzz, pause, buzz, pause, buzz] in milliseconds.
Future<void> vibrateForSos() async {
  try {
    if (await Vibration.hasVibrator() == true) {
      await Vibration.vibrate(pattern: [0, 600, 300, 600, 300, 600]);
      return;
    }
  } catch (_) {
    // Fall through to the basic haptic below.
  }
  // No vibration motor, or the plugin failed: give a single haptic tap.
  await HapticFeedback.heavyImpact();
}
