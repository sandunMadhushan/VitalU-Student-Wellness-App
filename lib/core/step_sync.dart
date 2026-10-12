import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repo.dart';

/// Reads the phone's built-in step counter and saves today's total, shared
/// by every screen that shows steps (Home, Activity tracker) so the figure
/// updates automatically no matter which one the student opens first.
class StepSync {
  StepSync._();

  static bool _busy = false;

  /// Syncs steps from the device sensor, requesting permission if it
  /// hasn't been granted yet. Safe to call on every screen open or app
  /// resume: once a student has answered the system prompt, Android does
  /// not show it again on later calls, so this never nags, it just quietly
  /// does nothing until permission is granted.
  static Future<int?> sync() async {
    if (kIsWeb || _busy) return null;
    _busy = true;
    try {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted && !status.isLimited) return null;
      final event = await Pedometer.stepCountStream.first.timeout(const Duration(seconds: 15));
      final prefs = await SharedPreferences.getInstance();
      final today = isoDate(DateTime.now());
      var base = prefs.getInt('ped_base') ?? event.steps;
      final baseDate = prefs.getString('ped_date');
      if (baseDate != today || event.steps < base) {
        // New day (or phone restarted): start counting from the current sensor value.
        final carried = baseDate == today ? (prefs.getInt('ped_today') ?? 0) : 0;
        base = event.steps - carried;
        await prefs.setString('ped_date', today);
        await prefs.setInt('ped_base', base);
      }
      final steps = (event.steps - base).clamp(0, 100000);
      await prefs.setInt('ped_today', steps);
      await prefs.setString('ped_last_sync', DateTime.now().toIso8601String());
      await Repo.upsertSensorSteps(steps);
      return steps;
    } catch (_) {
      return null;
    } finally {
      _busy = false;
    }
  }
}
