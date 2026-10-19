import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_state.dart';
import 'router.dart';

/// Phone notifications. Every reminder the app creates (water, cycle
/// phases, assessments) is a row in the `notifications` table; this mirrors
/// the upcoming, unread rows into the phone's own scheduler, so they appear
/// in the notification shade at the right time even when the app is closed
/// or the phone has restarted. Tapping one opens the screen it belongs to.
class Push {
  Push._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _syncing = false;
  static bool _again = false;
  static String? _launchRoute;

  static bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Android keeps a few hundred alarms per app and iOS only 64, so only the
  /// soonest ones are handed over; the rest follow on the next sync.
  static const _maxPending = 60;

  static const _channels = <String, (String, String)>{
    'water': ('Water reminders', 'Nudges to drink water through the day'),
    'cycle': ('Cycle tracker', 'Period and phase updates, and self-care tips'),
    'reminders': ('Reminders and check-ins', 'Health assessments and other reminders'),
    'general': ('General', 'Other updates from VitalU'),
  };

  static Future<void> init() async {
    if (!supported || _ready) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.getLocation('Asia/Colombo'));
      }
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_vitalu'),
          // Permission is asked once the student is signed in, not at launch.
          iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false),
        ),
        onDidReceiveNotificationResponse: (r) => _open(r.payload, navigate: true),
      );
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      for (final e in _channels.entries) {
        await android?.createNotificationChannel(AndroidNotificationChannel(e.key, e.value.$1, description: e.value.$2, importance: Importance.high));
      }
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        _launchRoute = await _open(launch!.notificationResponse?.payload, navigate: false);
      }
      AppLifecycleListener(onResume: sync);
      _ready = true;
    } catch (e) {
      debugPrint('push init failed: $e');
    }
  }

  /// The screen to open when the app was started by tapping a notification.
  static String? takeLaunchRoute() {
    final r = _launchRoute;
    _launchRoute = null;
    return r;
  }

  /// Marks the notification read and returns (or opens) its route.
  static Future<String?> _open(String? payload, {required bool navigate}) async {
    if (payload == null) return null;
    Map<String, dynamic> m;
    try {
      m = jsonDecode(payload) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    final id = m['id'] as String?;
    if (id != null && uid != null) {
      try {
        await db.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
        await AppState.instance.refreshUnread();
      } catch (_) {}
    }
    final route = m['route'] as String?;
    if (navigate && route != null && AppState.instance.signedIn) appRouter.push(route);
    return route;
  }

  static Future<bool> enabled() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.areNotificationsEnabled() ?? false;
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return (await ios?.checkPermissions())?.isEnabled ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shows the system permission prompt. Returns whether notifications are on.
  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
    final on = await enabled();
    if (on) await sync();
    return on;
  }

  /// Asks for permission the first time a signed-in student opens the app.
  static Future<void> askOnce() async {
    if (!_ready) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('push_permission_asked') ?? false) return;
      await prefs.setBool('push_permission_asked', true);
    } catch (_) {
      return;
    }
    await requestPermission();
  }

  static Future<void> openSettings() async {
    try {
      await _plugin.openAppNotificationSettings();
    } catch (_) {}
  }

  static Future<void> clear() async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  static Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(
      id: 1,
      title: 'Notifications are on',
      body: 'Water, cycle and check-in reminders from VitalU will appear here.',
      notificationDetails: _details('general', 'Notifications are on'),
    );
  }

  /// Re-schedules every upcoming reminder from the database. Calls that
  /// arrive mid-sync are folded into one more pass afterwards.
  static Future<void> sync() async {
    if (!_ready || uid == null) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _again = false;
        await _syncOnce();
      } while (_again);
    } catch (e) {
      debugPrint('push sync failed: $e');
    } finally {
      _syncing = false;
    }
  }

  static Future<void> _syncOnce() async {
    final id = uid;
    if (id == null) return;
    final now = DateTime.now();
    final rows = List<Map<String, dynamic>>.from(await db
        .from('notifications')
        .select('id, title, body, category, route, scheduled_for')
        .eq('user_id', id)
        .isFilter('read_at', null)
        .gt('scheduled_for', now.toUtc().toIso8601String())
        .order('scheduled_for')
        .limit(_maxPending));
    await _plugin.cancelAllPendingNotifications();
    for (final r in rows) {
      final at = _afterQuietHours(DateTime.parse(r['scheduled_for'] as String).toLocal());
      if (!at.isAfter(now)) continue;
      final channel = _channelFor(r);
      await _plugin.zonedSchedule(
        id: _intId(r['id'] as String),
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        title: r['title'] as String?,
        body: r['body'] as String?,
        notificationDetails: _details(channel, r['body'] as String?),
        // Inexact keeps us clear of the exact-alarm permission; Android may
        // deliver a few minutes late, which is fine for reminders.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: jsonEncode({'id': r['id'], 'route': r['route']}),
      );
    }
    await _scheduleDailyCheckIns(now);
  }

  // --- Morning and evening check-ins -----------------------------------------

  /// Whether the friendly morning and evening reminders are on (default on).
  static final dailyCheckIns = ValueNotifier<bool>(true);

  static Future<void> loadPreferences() async {
    try {
      dailyCheckIns.value = (await SharedPreferences.getInstance()).getBool('daily_checkins') ?? true;
    } catch (_) {}
  }

  static Future<void> setDailyCheckIns(bool on) async {
    dailyCheckIns.value = on;
    try {
      await (await SharedPreferences.getInstance()).setBool('daily_checkins', on);
    } catch (_) {}
    await sync();
  }

  static const _morning = [
    'Start with a glass of water and a proper breakfast. Your brain will thank you in that first lecture.',
    'Try walking to your first class today. Every step counts.',
    'Fill your water bottle before you head out. Small sips all day keep you fresh.',
    'Pop a fruit in your bag today. It makes a great snack between lectures.',
    'Take one slow, deep breath. You have got this today.',
    'A breakfast with some protein, like eggs, dhal or milk, keeps you full until lunch.',
    'Plan a short walk or stretch break today. Your body will love it.',
  ];

  static const _evening = [
    'How did today go? Take a minute to log your meals and water.',
    'Time to wind down. Putting screens away 30 minutes before bed helps you sleep better.',
    'Did you reach your water goal? One more glass now still counts.',
    'Well done today. A light dinner with vegetables helps you sleep well.',
    'Take two minutes to check in on your mood. Be kind to yourself.',
    'Aim for 7 to 8 hours of sleep tonight. You have earned it.',
    'A short evening walk or stretch can melt the day\'s stress away.',
  ];

  /// Schedules a friendly reminder at 7:30 and 19:30 for the next seven
  /// days, addressed to the student by first name. Refreshed on every sync.
  static Future<void> _scheduleDailyCheckIns(DateTime now) async {
    if (!dailyCheckIns.value) return;
    final name = AppState.instance.profile?.firstName;
    for (int d = 0; d < 7; d++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
      final i = (day.difference(DateTime(2026)).inDays) % 7;
      for (final (slot, hour, minute, greeting, lines, route) in [
        (0, 7, 30, 'Good Morning', _morning, '/home'),
        (1, 19, 30, 'Good Evening', _evening, '/diet/diary'),
      ]) {
        final at = DateTime(day.year, day.month, day.day, hour, minute);
        if (!at.isAfter(now)) continue;
        await _plugin.zonedSchedule(
          id: 900000 + d * 2 + slot,
          scheduledDate: tz.TZDateTime.from(_afterQuietHours(at), tz.local),
          title: name == null ? '$greeting!' : '$greeting, $name!',
          body: lines[i],
          notificationDetails: _details('reminders', lines[i]),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: jsonEncode({'route': route}),
        );
      }
    }
  }

  static String _channelFor(Map<String, dynamic> r) => switch (r['route']) {
        '/tools/water' => 'water',
        '/tools/cycle' => 'cycle',
        _ => r['category'] == 'milestone' || r['category'] == 'reminder' ? 'reminders' : 'general',
      };

  static NotificationDetails _details(String channel, String? body) => NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          _channels[channel]!.$1,
          channelDescription: _channels[channel]!.$2,
          importance: Importance.high,
          priority: Priority.high,
          color: const Color(0xFF0B7A63),
          styleInformation: body == null ? null : BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true, presentBadge: true),
      );

  /// Moves a reminder that would land in the student's quiet hours to the
  /// moment quiet hours end. Defaults match the settings screen (22:00 to 07:00).
  static DateTime _afterQuietHours(DateTime at) {
    final p = AppState.instance.profile;
    (int, int) parse(String? s, (int, int) d) {
      if (s == null) return d;
      final x = s.split(':');
      if (x.length < 2) return d;
      return (int.tryParse(x[0]) ?? d.$1, int.tryParse(x[1]) ?? d.$2);
    }

    final (sh, sm) = parse(p?.quietStart, (22, 0));
    final (eh, em) = parse(p?.quietEnd, (7, 0));
    final start = sh * 60 + sm, end = eh * 60 + em, m = at.hour * 60 + at.minute;
    if (start == end) return at;
    final inQuiet = start < end ? (m >= start && m < end) : (m >= start || m < end);
    if (!inQuiet) return at;
    var out = DateTime(at.year, at.month, at.day, eh, em);
    if (!out.isAfter(at)) out = out.add(const Duration(days: 1));
    return out;
  }

  /// Stable 31-bit id from the row's uuid (FNV-1a), so re-syncing replaces
  /// rather than duplicates a notification.
  static int _intId(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return (h & 0x7fffffff) | 0x10;
  }
}
