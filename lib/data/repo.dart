import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_state.dart';

typedef Rec = Map<String, dynamic>;

String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime weekStart(DateTime d) => dayStart(d).subtract(Duration(days: d.weekday - 1));
String utc(DateTime d) => d.toUtc().toIso8601String();
int weekOfYear(DateTime d) {
  final start = DateTime(d.year, 1, 1);
  return ((d.difference(start).inDays + start.weekday - 1) / 7).floor() + 1;
}

/// Thin data-access layer over Supabase. Every table is protected by RLS so
/// queries only ever return the signed-in student's own rows.
class Repo {
  Repo._();

  static String get _uid => uid!;

  // ---------------- Account ----------------

  /// Whether no other student has taken [name] (case-insensitive). Backed by
  /// a security-definer function since row-level security otherwise hides
  /// every profile but the caller's own.
  static Future<bool> usernameAvailable(String name) async {
    final r = await db.rpc('username_available', params: {'name': name});
    return r as bool;
  }

  // ---------------- Water ----------------
  static Future<List<Rec>> waterOn(DateTime day) async {
    final s = dayStart(day);
    final rows = await db
        .from('water_logs')
        .select()
        .eq('user_id', _uid)
        .gte('logged_at', utc(s))
        .lt('logged_at', utc(s.add(const Duration(days: 1))))
        .order('logged_at');
    return List<Rec>.from(rows);
  }

  static Future<int> waterTotal(DateTime day) async => (await waterOn(day)).fold<int>(0, (a, r) => a + (r['amount_ml'] as int));

  static Future<Map<String, int>> waterByDay(int days) async {
    final from = dayStart(DateTime.now()).subtract(Duration(days: days - 1));
    final rows = await db.from('water_logs').select('amount_ml, logged_at').eq('user_id', _uid).gte('logged_at', utc(from));
    final m = <String, int>{};
    for (final r in rows) {
      final k = isoDate(DateTime.parse(r['logged_at']).toLocal());
      m[k] = (m[k] ?? 0) + (r['amount_ml'] as int);
    }
    return m;
  }

  static Future<void> addWater(int ml, {String? label, String? location, DateTime? at}) async {
    await db.from('water_logs').insert({'amount_ml': ml, 'label': label, 'location': location, if (at != null) 'logged_at': utc(at)});
    await refreshBadges();
  }

  static Future<void> deleteWater(String id) => db.from('water_logs').delete().eq('id', id);

  // ---------------- Activity ----------------
  static Future<List<Rec>> activityBetween(DateTime from, DateTime to) async {
    final rows = await db
        .from('activity_logs')
        .select()
        .eq('user_id', _uid)
        .gte('activity_date', isoDate(from))
        .lte('activity_date', isoDate(to))
        .order('logged_at');
    return List<Rec>.from(rows);
  }

  static Future<Rec> activityTotals(DateTime day) async {
    final rows = await activityBetween(day, day);
    int steps = 0, mins = 0, kcal = 0;
    double km = 0;
    for (final r in rows) {
      steps += (r['steps'] as num).toInt();
      mins += (r['active_minutes'] as num).toInt();
      kcal += (r['kcal'] as num).toInt();
      km += (r['distance_km'] as num).toDouble();
    }
    return {'steps': steps, 'minutes': mins, 'kcal': kcal, 'km': km, 'logs': rows};
  }

  static Future<Map<String, int>> stepsByDay(DateTime from, DateTime to) async {
    final rows = await activityBetween(from, to);
    final m = <String, int>{};
    for (final r in rows) {
      final k = r['activity_date'] as String;
      m[k] = (m[k] ?? 0) + (r['steps'] as num).toInt();
    }
    return m;
  }

  static Future<Map<String, int>> minutesByDay(DateTime from, DateTime to) async {
    final rows = await activityBetween(from, to);
    final m = <String, int>{};
    for (final r in rows) {
      final k = r['activity_date'] as String;
      m[k] = (m[k] ?? 0) + (r['active_minutes'] as num).toInt();
    }
    return m;
  }

  static Future<void> addActivity({required String type, int steps = 0, int minutes = 0, double km = 0, int kcal = 0, DateTime? date, String source = 'manual', String? note}) async {
    await db.from('activity_logs').insert({
      'activity_type': type,
      'steps': steps,
      'active_minutes': minutes,
      'distance_km': km,
      'kcal': kcal,
      'activity_date': isoDate(date ?? DateTime.now()),
      'source': source,
      'note': note,
    });
    await refreshBadges();
  }

  /// Replaces today's automatically synced step entry from the phone sensor.
  static Future<void> upsertSensorSteps(int steps) async {
    final today = isoDate(DateTime.now());
    await db.from('activity_logs').delete().eq('user_id', _uid).eq('activity_date', today).eq('source', 'sensor');
    if (steps > 0) {
      await db.from('activity_logs').insert({
        'activity_type': 'Walk',
        'steps': steps,
        'active_minutes': (steps / 100).round(),
        'distance_km': double.parse((steps * 0.00075).toStringAsFixed(2)),
        'kcal': (steps * 0.04).round(),
        'activity_date': today,
        'source': 'sensor',
      });
    }
    await refreshBadges();
  }

  // ---------------- Sleep ----------------
  static Future<List<Rec>> sleepBetween(DateTime from, DateTime to) async {
    final rows = await db.from('sleep_logs').select().eq('user_id', _uid).gte('sleep_date', isoDate(from)).lte('sleep_date', isoDate(to)).order('sleep_date');
    return List<Rec>.from(rows);
  }

  static Future<Rec?> sleepLatest() async {
    final rows = await db.from('sleep_logs').select().eq('user_id', _uid).order('sleep_date', ascending: false).limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<void> saveSleep({required DateTime bedtime, required DateTime wake, int? quality, int? deep, int? rem, int? light, String? note}) async {
    await db.from('sleep_logs').upsert({
      'user_id': _uid,
      'sleep_date': isoDate(wake),
      'bedtime': utc(bedtime),
      'wake_time': utc(wake),
      'quality': quality,
      'deep_minutes': deep,
      'rem_minutes': rem,
      'light_minutes': light,
      'note': note,
    }, onConflict: 'user_id,sleep_date');
    await refreshBadges();
  }

  static int sleepMinutes(Rec r) => DateTime.parse(r['wake_time']).difference(DateTime.parse(r['bedtime'])).inMinutes;

  // ---------------- Mood / reflections ----------------
  static Future<Rec?> moodLatest() async {
    final rows = await db.from('mood_logs').select().eq('user_id', _uid).order('logged_at', ascending: false).limit(1);
    return rows.isEmpty ? null : rows.first;
  }

  static Future<List<Rec>> moodsSince(DateTime from) async =>
      List<Rec>.from(await db.from('mood_logs').select().eq('user_id', _uid).gte('logged_at', utc(from)).order('logged_at'));

  static Future<void> addMood(String mood, {String? note}) async {
    await db.from('mood_logs').insert({'mood': mood, 'note': note});
    await refreshBadges();
  }

  // ---------------- Meals ----------------
  static Future<List<Rec>> mealsOn(DateTime day) async =>
      List<Rec>.from(await db.from('meals').select().eq('user_id', _uid).eq('meal_date', isoDate(day)).order('logged_at'));

  static Future<List<Rec>> mealsBetween(DateTime from, DateTime to) async => List<Rec>.from(
      await db.from('meals').select().eq('user_id', _uid).gte('meal_date', isoDate(from)).lte('meal_date', isoDate(to)).order('meal_date').order('logged_at'));

  static Future<void> addMeal({
    required String mealType,
    required String name,
    String? source,
    String? foodItemId,
    int kcal = 0,
    int carbs = 0,
    int protein = 0,
    int fat = 0,
    List<String> groups = const [],
    String status = 'logged',
    DateTime? date,
    String? plannedTime,
  }) async {
    final d = date ?? DateTime.now();
    await db.from('meals').insert({
      'meal_type': mealType,
      'name': name,
      'source': source,
      'food_item_id': foodItemId,
      'kcal': kcal,
      'carbs_g': carbs,
      'protein_g': protein,
      'fat_g': fat,
      'food_groups': groups,
      'status': status,
      'meal_date': isoDate(d),
      'planned_time': plannedTime,
    });
    if (status == 'logged' && groups.isNotEmpty) {
      await db.from('diversity_logs').insert([for (final g in groups) {'food_group': g, 'food_name': name, 'log_date': isoDate(d)}]);
    }
    await refreshBadges();
  }

  static Future<void> addMealFromItem(Rec item, String mealType, {String status = 'logged', DateTime? date, String? plannedTime}) => addMeal(
        mealType: mealType,
        name: item['name'],
        source: item['source'],
        foodItemId: item['id'],
        kcal: item['kcal'] ?? 0,
        carbs: item['carbs_g'] ?? 0,
        protein: item['protein_g'] ?? 0,
        fat: item['fat_g'] ?? 0,
        groups: List<String>.from(item['food_groups'] ?? const []),
        status: status,
        date: date,
        plannedTime: plannedTime,
      );

  static Future<void> confirmMeal(Rec meal) async {
    await db.from('meals').update({'status': 'logged', 'logged_at': utc(DateTime.now())}).eq('id', meal['id']);
    final groups = List<String>.from(meal['food_groups'] ?? const []);
    if (groups.isNotEmpty) {
      await db.from('diversity_logs').insert([for (final g in groups) {'food_group': g, 'food_name': meal['name'], 'log_date': meal['meal_date']}]);
    }
    await refreshBadges();
  }

  static Future<void> deleteMeal(String id) => db.from('meals').delete().eq('id', id);

  static Future<List<Rec>> foodItems() async => List<Rec>.from(await db.from('food_items').select().order('sort_order'));

  // ---------------- Diversity ----------------
  static Future<List<Rec>> diversityBetween(DateTime from, DateTime to) async => List<Rec>.from(
      await db.from('diversity_logs').select().eq('user_id', _uid).gte('log_date', isoDate(from)).lte('log_date', isoDate(to)).order('logged_at'));

  static Future<void> addDiversity(String group, String food) async {
    await db.from('diversity_logs').insert({'food_group': group, 'food_name': food});
    await refreshBadges();
  }

  // ---------------- Budget planner ----------------
  /// food_item_id -> servings per week
  static Future<Map<String, int>> budgetItems(DateTime week) async {
    final rows = await db.from('budget_plan_items').select('food_item_id, servings').eq('user_id', _uid).eq('week_start', isoDate(week));
    return {for (final r in rows) r['food_item_id'] as String: (r['servings'] as num).toInt()};
  }

  static Future<void> setBudgetItem(DateTime week, String itemId, bool on, {int servings = 5}) async {
    if (on) {
      await db.from('budget_plan_items').upsert({'user_id': _uid, 'week_start': isoDate(week), 'food_item_id': itemId, 'servings': servings}, onConflict: 'user_id,week_start,food_item_id');
    } else {
      await db.from('budget_plan_items').delete().eq('user_id', _uid).eq('week_start', isoDate(week)).eq('food_item_id', itemId);
    }
  }

  static Future<void> saveGroceryList(DateTime week, double budget, double total, List<Rec> items) =>
      db.from('grocery_lists').insert({'week_start': isoDate(week), 'budget': budget, 'total': total, 'items': items});

  // ---------------- Tools ----------------
  static Future<void> saveToolResult(String tool, {num? score, String? category, Map<String, dynamic> data = const {}}) async {
    await db.from('tool_results').insert({'tool': tool, 'score': score, 'category': category, 'data': data});
    await refreshBadges();
  }

  static Future<List<Rec>> toolResults(String tool, {int limit = 20}) async =>
      List<Rec>.from(await db.from('tool_results').select().eq('user_id', _uid).eq('tool', tool).order('created_at', ascending: false).limit(limit));

  // ---------------- Menstrual ----------------
  static Future<List<Rec>> cycles() async => List<Rec>.from(await db.from('menstrual_cycles').select().eq('user_id', _uid).order('start_date', ascending: false));

  static Future<void> addCycleStart(DateTime start) async {
    await db.from('menstrual_cycles').upsert({'user_id': _uid, 'start_date': isoDate(start)}, onConflict: 'user_id,start_date');
    await refreshBadges();
  }

  static Future<void> endCycle(String id, DateTime end) => db.from('menstrual_cycles').update({'end_date': isoDate(end)}).eq('id', id);

  static Future<Rec?> dailyLog(DateTime day) async =>
      await db.from('menstrual_daily_logs').select().eq('user_id', _uid).eq('log_date', isoDate(day)).maybeSingle();

  static Future<void> upsertDailyLog(DateTime day, Map<String, dynamic> values) =>
      db.from('menstrual_daily_logs').upsert({'user_id': _uid, 'log_date': isoDate(day), ...values, 'updated_at': utc(DateTime.now())}, onConflict: 'user_id,log_date');

  static Future<List<Rec>> dailyLogsSince(DateTime from) async =>
      List<Rec>.from(await db.from('menstrual_daily_logs').select().eq('user_id', _uid).gte('log_date', isoDate(from)).order('log_date'));

  // ---------------- Screen time ----------------
  static Future<int> screenTimeOn(DateTime day) async {
    final row = await db.from('screen_time_logs').select('minutes').eq('user_id', _uid).eq('log_date', isoDate(day)).maybeSingle();
    return (row?['minutes'] as int?) ?? 0;
  }

  static Future<void> setScreenTime(DateTime day, int minutes) async {
    await db.from('screen_time_logs').upsert({'user_id': _uid, 'log_date': isoDate(day), 'minutes': minutes, 'updated_at': utc(DateTime.now())}, onConflict: 'user_id,log_date');
    await refreshBadges();
  }

  static Future<Map<String, int>> screenTimeByDay(DateTime from, DateTime to) async {
    final rows = await db.from('screen_time_logs').select('log_date, minutes').eq('user_id', _uid).gte('log_date', isoDate(from)).lte('log_date', isoDate(to));
    return {for (final r in rows) r['log_date'] as String: r['minutes'] as int};
  }

  // ---------------- Assessments ----------------
  static Future<List<Rec>> windows() async => List<Rec>.from(await db.from('assessment_windows').select().order('opens_at'));

  /// The window that applies to this student right now (open) or next (upcoming).
  static Future<(Rec?, Rec?)> currentAndNextWindow() async {
    final faculty = AppState.instance.profile?.faculty;
    final now = DateTime.now();
    Rec? open, next;
    for (final w in await windows()) {
      final f = w['faculty'] as String?;
      if (f != null && f != faculty) continue;
      final o = DateTime.parse(w['opens_at']).toLocal();
      final c = DateTime.parse(w['closes_at']).toLocal();
      if (now.isAfter(o) && now.isBefore(c)) open ??= w;
      if (now.isBefore(o)) next ??= w;
    }
    return (open, next);
  }

  static Future<List<Rec>> assessments() async =>
      List<Rec>.from(await db.from('assessments').select('*, assessment_windows(title, term)').eq('user_id', _uid).order('started_at', ascending: false));

  static Future<Rec?> assessmentFor(String windowId) async =>
      await db.from('assessments').select().eq('user_id', _uid).eq('window_id', windowId).maybeSingle();

  static Future<Rec> startAssessment(Rec window) async {
    final existing = await assessmentFor(window['id']);
    if (existing != null) return existing;
    return await db.from('assessments').insert({'window_id': window['id'], 'title': window['title']}).select().single();
  }

  static Future<void> saveAssessmentProgress(String id, Map<String, dynamic> answers, int index) =>
      db.from('assessments').update({'answers': answers, 'current_index': index}).eq('id', id);

  static Future<void> completeAssessment(String id, Map<String, dynamic> answers, Map<String, dynamic> scores, String label) async {
    await db.from('assessments').update({
      'answers': answers,
      'scores': scores,
      'result_label': label,
      'status': 'completed',
      'completed_at': utc(DateTime.now()),
    }).eq('id', id);
    await refreshBadges();
  }

  // ---------------- Education ----------------
  static Future<List<Rec>> articles() async => List<Rec>.from(await db.from('education_articles').select().order('published_at', ascending: false));

  static Future<Rec?> article(String slug) async => await db.from('education_articles').select().eq('slug', slug).maybeSingle();

  static Future<Set<String>> bookmarkIds() async {
    final rows = await db.from('article_bookmarks').select('article_id').eq('user_id', _uid);
    return {for (final r in rows) r['article_id'] as String};
  }

  static Future<void> setBookmark(String articleId, bool on) async {
    if (on) {
      await db.from('article_bookmarks').upsert({'user_id': _uid, 'article_id': articleId}, onConflict: 'user_id,article_id');
    } else {
      await db.from('article_bookmarks').delete().eq('user_id', _uid).eq('article_id', articleId);
    }
    await refreshBadges();
  }

  static Future<bool> isHelpful(String articleId) async =>
      (await db.from('article_helpful').select('article_id').eq('user_id', _uid).eq('article_id', articleId).maybeSingle()) != null;

  static Future<void> setHelpful(String articleId, bool on) async {
    if (on) {
      await db.from('article_helpful').upsert({'user_id': _uid, 'article_id': articleId}, onConflict: 'user_id,article_id');
    } else {
      await db.from('article_helpful').delete().eq('user_id', _uid).eq('article_id', articleId);
    }
    await refreshBadges();
  }

  // ---------------- Consultation & emergency ----------------
  static Future<List<Rec>> professionals() async => List<Rec>.from(await db.from('professionals').select().eq('is_active', true).order('sort_order'));

  static Future<void> requestAppointment({String? professionalId, required String service, String kind = 'booking', DateTime? preferred, String? message}) =>
      db.from('appointments').insert({
        'professional_id': professionalId,
        'service': service,
        'kind': kind,
        'preferred_at': preferred == null ? null : utc(preferred),
        'message': message,
      });

  static Future<List<Rec>> appointments() async =>
      List<Rec>.from(await db.from('appointments').select('*, professionals(name)').eq('user_id', _uid).order('created_at', ascending: false));

  static Future<List<Rec>> emergencyContacts() async => List<Rec>.from(await db.from('emergency_contacts').select().order('sort_order'));

  static Future<Map<String, String>> appInfo() async {
    final rows = await db.from('app_info').select();
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  static Future<void> sendSupport(String topic, String message) => db.from('support_messages').insert({'topic': topic, 'message': message});

  // ---------------- Notifications ----------------
  static Future<List<Rec>> notifications() async => List<Rec>.from(await db
      .from('notifications')
      .select()
      .eq('user_id', _uid)
      .lte('scheduled_for', utc(DateTime.now()))
      .order('scheduled_for', ascending: false)
      .limit(100));

  static Future<void> markAllRead() async {
    await db.from('notifications').update({'read_at': utc(DateTime.now())}).eq('user_id', _uid).isFilter('read_at', null);
    await AppState.instance.refreshUnread();
  }

  static Future<void> markRead(String id) async {
    await db.from('notifications').update({'read_at': utc(DateTime.now())}).eq('id', id);
    await AppState.instance.refreshUnread();
  }

  static Future<void> schedule({required String title, String? body, String category = 'reminder', String? label, String? icon, String? route, required DateTime at}) =>
      db.from('notifications').insert({
        'title': title,
        'body': body,
        'category': category,
        'label': label,
        'icon': icon,
        'route': route,
        'scheduled_for': utc(at),
      });

  // ---------------- Badges ----------------
  static Future<List<Rec>> badges() async => List<Rec>.from(await db.from('badges').select().order('sort_order'));

  static Future<Map<String, DateTime>> earnedBadges() async {
    final rows = await db.from('user_badges').select().eq('user_id', _uid);
    return {for (final r in rows) r['badge_code'] as String: DateTime.parse(r['earned_at']).toLocal()};
  }

  static Future<void> refreshBadges() async {
    try {
      final res = await db.rpc('refresh_badges');
      if (res is List && res.isNotEmpty) await AppState.instance.refreshUnread();
    } catch (_) {}
  }

  // ---------------- Blood reports ----------------
  static Future<Rec> uploadReport(Uint8List bytes, String fileName, String mime) async {
    final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}_${fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}';
    await db.storage.from('blood-reports').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: mime, upsert: false));
    return await db.from('blood_reports').insert({'file_path': path, 'file_name': fileName, 'mime_type': mime}).select().single();
  }

  static Future<Rec> analyzeReport(String reportId) async {
    final res = await db.functions.invoke('analyze-blood-report', body: {'report_id': reportId});
    final data = res.data;
    if (data is Map && data['error'] != null) throw Exception(data['error']);
    return (await db.from('blood_reports').select().eq('id', reportId).single());
  }

  static Future<Rec?> report(String id) async => await db.from('blood_reports').select().eq('id', id).maybeSingle();

  static Future<List<Rec>> reports() async =>
      List<Rec>.from(await db.from('blood_reports').select().eq('user_id', _uid).order('created_at', ascending: false));

  static Future<void> deleteReport(Rec r) async {
    if (r['file_path'] != null) {
      try {
        await db.storage.from('blood-reports').remove([r['file_path']]);
      } catch (_) {}
    }
    await db.from('blood_reports').delete().eq('id', r['id']);
  }
}
