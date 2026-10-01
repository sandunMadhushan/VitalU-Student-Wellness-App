import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Native build of [DeviceUsage]: reads today's on-device screen time from
/// the OS usage-stats API, via a small platform channel ([MainActivity])
/// that filters the raw per-app totals down to apps a student would
/// actually recognise (the home launcher and system components are
/// excluded — otherwise idle home-screen time inflates the total well past
/// what the phone's own Digital Wellbeing/Screen Time figure shows).
///
/// Android exposes this via `UsageStatsManager`, gated behind the "Usage
/// access" special permission — there is no runtime dialog for it, so the
/// first call opens that settings screen directly and returns no data
/// until the student grants it there and taps again.
///
/// iOS has no equivalent public API: Apple's own Screen Time data is only
/// readable by apps with a special, selectively-granted Family Controls
/// entitlement (parental-control apps), not by regular App Store apps, so
/// this always reports "not supported" there.
class DeviceUsage {
  DeviceUsage._();

  static const _channel = MethodChannel('vitalu/usage_stats');

  static bool get supported => Platform.isAndroid;

  static Future<int?> readTodayMinutes() async {
    if (!Platform.isAndroid) return null;
    try {
      final hasAccess = await _channel.invokeMethod<bool>('hasAccess') ?? false;
      if (!hasAccess) {
        await _channel.invokeMethod('openSettings');
        return null;
      }
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final minutes = await _channel.invokeMethod<int>('screenTimeMinutes', {
        'start': start.millisecondsSinceEpoch,
        'end': now.millisecondsSinceEpoch,
      });
      return minutes;
    } catch (_) {
      return null;
    }
  }
}
