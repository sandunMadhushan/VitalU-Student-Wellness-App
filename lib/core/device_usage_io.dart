import 'dart:io' show Platform;

import 'package:app_usage/app_usage.dart';

/// Native build of [DeviceUsage]: reads today's on-device screen time from
/// the OS usage-stats API.
///
/// Android exposes this via `UsageStatsManager`, gated behind the "Usage
/// access" special permission — the plugin opens that settings screen
/// itself the first time it's asked and returns no data until the student
/// grants it there, so the first call is always a prompt, not a result.
///
/// iOS has no equivalent public API: Apple's own Screen Time data is only
/// readable by apps with a special, selectively-granted Family Controls
/// entitlement (parental-control apps), not by regular App Store apps, so
/// this always reports "not supported" there.
class DeviceUsage {
  DeviceUsage._();

  static bool get supported => Platform.isAndroid;

  static Future<int?> readTodayMinutes() async {
    if (!Platform.isAndroid) return null;
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final usage = await AppUsage().getAppUsage(start, now);
      if (usage.isEmpty) return null; // no access yet, or genuinely nothing used
      final minutes = usage.fold<int>(0, (a, u) => a + u.usage.inMinutes);
      return minutes;
    } catch (_) {
      return null;
    }
  }
}
