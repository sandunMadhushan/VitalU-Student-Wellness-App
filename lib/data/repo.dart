import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_state.dart';
import '../core/badges.dart';
import '../core/push.dart';
import 'food_db.dart';
import 'models.dart';

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
    int kcal = 0,
    List<String> groups = const [],
    List<LoggedItem> items = const [],
    String status = 'logged',
    DateTime? date,
  }) async {
    final d = date ?? DateTime.now();
    final row = <String, dynamic>{
      'meal_type': mealType,
      'name': name,
      'source': source,
      'kcal': kcal,
      'food_groups': groups,
      'status': status,
      'meal_date': isoDate(d),
      if (items.isNotEmpty) 'items': [for (final i in items) i.toJson()],
    };
    try {
      await db.from('meals').insert(row);
    } on PostgrestException catch (e) {
      // meals.items arrives with a database migration; log without it until then.
      if (e.code != 'PGRST204' && e.code != '42703') rethrow;
      await db.from('meals').insert({...row}..remove('items'));
    }
    if (status == 'logged' && groups.isNotEmpty) {
      String foodFor(String g) => items.where((i) => i.groups.contains(g)).map((i) => i.name).firstOrNull ?? name;
      await db.from('diversity_logs').insert([for (final g in groups) {'food_group': g, 'food_name': foodFor(g), 'log_date': isoDate(d)}]);
    }
    await refreshBadges();
  }

  /// Logs a meal built from foods in the shared food database.
  static Future<void> logMeal(String mealType, List<LoggedItem> items, {String source = 'Meal log', DateTime? date}) => addMeal(
        mealType: mealType,
        name: items.map((i) => '${i.name} (${i.portion})').join(', '),
        source: source,
        kcal: items.fold(0, (a, i) => a + i.kcal),
        groups: {for (final i in items) ...i.groups}.toList(),
        items: items,
        date: date,
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


  // ---------------- Diversity ----------------
  static Future<List<Rec>> diversityBetween(DateTime from, DateTime to) async => List<Rec>.from(
      await db.from('diversity_logs').select().eq('user_id', _uid).gte('log_date', isoDate(from)).lte('log_date', isoDate(to)).order('logged_at'));

  static Future<void> addDiversity(String group, String food) async {
    await db.from('diversity_logs').insert({'food_group': group, 'food_name': food});
    await refreshBadges();
  }

  // ---------------- Budget planner ----------------
  static Future<void> saveGroceryList(DateTime week, double budget, double total, List<Rec> items) =>
      db.from('grocery_lists').insert({'week_start': isoDate(week), 'budget': budget, 'total': total, 'items': items});

  // ---------------- Tools ----------------
  static Future<void> saveToolResult(String tool, {num? score, String? category, Map<String, dynamic> data = const {}}) async {
    await db.from('tool_results').insert({'tool': tool, 'score': score, 'category': category, 'data': data});
    await refreshBadges();
  }

  static Future<List<Rec>> toolResults(String tool, {int limit = 20}) async =>
      List<Rec>.from(await db.from('tool_results').select().eq('user_id', _uid).eq('tool', tool).order('created_at', ascending: false).limit(limit));

  static Future<Rec?> latestToolResult(String tool) async {
    final rows = await toolResults(tool, limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Logs blood pressure, fasting blood glucose and/or triglycerides, as
  /// measured at a clinic or from a lab report.
  static Future<void> saveVitals({int? systolic, int? diastolic, double? fastingGlucose, double? triglycerides, required DateTime measuredOn}) =>
      saveToolResult('vitals', data: {
        'systolic': ?systolic,
        'diastolic': ?diastolic,
        'fasting_glucose': ?fastingGlucose,
        'triglycerides': ?triglycerides,
        'measured_on': isoDate(measuredOn),
      });

  /// The most recent reading of each lab-type vital, from the student's own
  /// logs, the CVD checker or an analysed blood report.
  static Future<LatestVitals> latestVitals() async {
    // Read the id first: failing part-way through building the list below
    // would leave the queries already started with unhandled errors.
    final id = _uid;
    final results = await Future.wait([
      toolResults('vitals', limit: 30),
      toolResults('cvd', limit: 10),
      db.from('blood_reports').select('results, created_at').eq('user_id', id).eq('status', 'done').order('created_at', ascending: false).limit(10),
    ]);
    VitalReading? bp, fbg, tg;
    void offer(VitalReading? cur, VitalReading next, void Function(VitalReading) set) {
      if (cur == null || next.at.isAfter(cur.at)) set(next);
    }

    for (final r in results[0]) {
      final d = Map<String, dynamic>.from(r['data'] ?? {});
      final at = DateTime.tryParse('${d['measured_on']}') ?? DateTime.parse(r['created_at']).toLocal();
      if (d['systolic'] != null && d['diastolic'] != null) offer(bp, VitalReading((d['systolic'] as num).toDouble(), at, extra: (d['diastolic'] as num).toDouble()), (v) => bp = v);
      if (d['fasting_glucose'] != null) offer(fbg, VitalReading((d['fasting_glucose'] as num).toDouble(), at), (v) => fbg = v);
      if (d['triglycerides'] != null) offer(tg, VitalReading((d['triglycerides'] as num).toDouble(), at), (v) => tg = v);
    }
    for (final r in results[1]) {
      final d = Map<String, dynamic>.from(r['data'] ?? {});
      final at = DateTime.parse(r['created_at']).toLocal();
      if (d['systolic'] != null && d['diastolic'] != null) offer(bp, VitalReading((d['systolic'] as num).toDouble(), at, extra: (d['diastolic'] as num).toDouble(), source: 'CVD check'), (v) => bp = v);
      if (d['glucose'] != null) offer(fbg, VitalReading((d['glucose'] as num).toDouble(), at, source: 'CVD check'), (v) => fbg = v);
    }
    for (final r in results[2]) {
      final at = DateTime.parse(r['created_at']).toLocal();
      for (final v in (r['results'] as List? ?? const [])) {
        if (v is! Map) continue;
        final name = '${v['name']}'.toLowerCase();
        final value = v['value'] is num ? (v['value'] as num).toDouble() : double.tryParse('${v['value']}');
        if (value == null) continue;
        if (name.contains('triglycer')) offer(tg, VitalReading(value, at, source: 'Blood report'), (x) => tg = x);
        if (name.contains('glucose') && (name.contains('fasting') || name.contains('fbs') || name.contains('fbg'))) offer(fbg, VitalReading(value, at, source: 'Blood report'), (x) => fbg = x);
      }
    }
    return LatestVitals(bp: bp, fastingGlucose: fbg, triglycerides: tg);
  }

  // ---------------- Usage summary ----------------

  static Future<int> mealsLoggedCount() async => (await db.from('meals').select('id').eq('user_id', _uid).eq('status', 'logged')).length;

  /// How many times each health tool has been used, by tool key.
  static Future<Map<String, int>> toolUseCounts() async {
    final rows = await db.from('tool_results').select('tool').eq('user_id', _uid);
    final m = <String, int>{};
    for (final r in rows) {
      m[r['tool'] as String] = (m[r['tool'] as String] ?? 0) + 1;
    }
    return m;
  }

  /// Distinct days in the last [days] on which anything was tracked (water,
  /// meals, activity, sleep or mood).
  static Future<Set<String>> activeDays(int days) async {
    final id = _uid;
    final from = dayStart(DateTime.now()).subtract(Duration(days: days - 1));
    final r = await Future.wait([
      db.from('water_logs').select('logged_at').eq('user_id', id).gte('logged_at', utc(from)),
      db.from('meals').select('meal_date').eq('user_id', id).eq('status', 'logged').gte('meal_date', isoDate(from)),
      db.from('activity_logs').select('activity_date').eq('user_id', id).gte('activity_date', isoDate(from)),
      db.from('sleep_logs').select('sleep_date').eq('user_id', id).gte('sleep_date', isoDate(from)),
      db.from('mood_logs').select('logged_at').eq('user_id', id).gte('logged_at', utc(from)),
    ]);
    return {
      for (final x in r[0]) isoDate(DateTime.parse(x['logged_at']).toLocal()),
      for (final x in r[1]) x['meal_date'] as String,
      for (final x in r[2]) x['activity_date'] as String,
      for (final x in r[3]) x['sleep_date'] as String,
      for (final x in r[4]) isoDate(DateTime.parse(x['logged_at']).toLocal()),
    };
  }

  // ---------------- Anonymous consultation ----------------

  /// Sends a question to the health centre without any link to the account.
  /// Returns the ticket code the student uses to read the reply.
  static Future<String> submitAnonConsultation({required String topic, required String message, required String urgency}) async {
    final code = await db.rpc('submit_anon_consultation', params: {'p_topic': topic, 'p_message': message, 'p_urgency': urgency});
    return code as String;
  }

  static Future<List<Rec>> anonConsultations(List<String> codes) async {
    if (codes.isEmpty) return [];
    final rows = await db.rpc('anon_consultations_by_codes', params: {'p_codes': codes});
    return List<Rec>.from(rows as List);
  }

  // ---------------- Periodic assessment questionnaire ----------------

  static Future<List<Rec>> assessmentDomains() async => List<Rec>.from(await db.from('assessment_domains').select().order('position'));

  static Future<List<Rec>> assessmentQuestions() async =>
      List<Rec>.from(await db.from('assessment_questions').select().eq('active', true).order('domain_id').order('position'));

  // ---------------- Menstrual ----------------
  static Future<List<Rec>> cycles() async => List<Rec>.from(await db.from('menstrual_cycles').select().eq('user_id', _uid).order('start_date', ascending: false));

  static Future<void> addCycleStart(DateTime start) async {
    await db.from('menstrual_cycles').upsert({'user_id': _uid, 'start_date': isoDate(start)}, onConflict: 'user_id,start_date');
    await refreshBadges();
  }

  static Future<void> endCycle(String id, DateTime end) => db.from('menstrual_cycles').update({'end_date': isoDate(end)}).eq('id', id);

  /// Logs a whole period at once (for example, a past month), with its end
  /// date when known.
  static Future<void> addCycle(DateTime start, {DateTime? end}) async {
    await db.from('menstrual_cycles').upsert({'user_id': _uid, 'start_date': isoDate(start), 'end_date': end == null ? null : isoDate(end)}, onConflict: 'user_id,start_date');
    await refreshBadges();
  }

  static Future<void> deleteCycle(String id) => db.from('menstrual_cycles').delete().eq('id', id);

  static Future<List<Rec>> dailyLogsBetween(DateTime from, DateTime to) async =>
      List<Rec>.from(await db.from('menstrual_daily_logs').select().eq('user_id', _uid).gte('log_date', isoDate(from)).lte('log_date', isoDate(to)).order('log_date'));

  static Future<Rec?> dailyLog(DateTime day) async =>
      await db.from('menstrual_daily_logs').select().eq('user_id', _uid).eq('log_date', isoDate(day)).maybeSingle();

  static Future<void> upsertDailyLog(DateTime day, Map<String, dynamic> values) =>
      db.from('menstrual_daily_logs').upsert({'user_id': _uid, 'log_date': isoDate(day), ...values, 'updated_at': utc(DateTime.now())}, onConflict: 'user_id,log_date');

  static Future<List<Rec>> dailyLogsSince(DateTime from) async =>
      List<Rec>.from(await db.from('menstrual_daily_logs').select().eq('user_id', _uid).gte('log_date', isoDate(from)).order('log_date'));

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

  /// Removes upcoming, not-yet-shown notifications that open [route], so a
  /// tracker can replace its own schedule without touching anything else.
  static Future<void> clearScheduled(String route) async {
    await db.from('notifications').delete().eq('user_id', _uid).eq('route', route).isFilter('read_at', null).gt('scheduled_for', utc(DateTime.now()));
    Push.sync();
  }

  static Future<void> scheduleMany(List<Rec> rows) async {
    if (rows.isEmpty) return;
    await db.from('notifications').insert(rows);
    Push.sync();
  }

  static Future<void> schedule({required String title, String? body, String category = 'reminder', String? label, String? icon, String? route, required DateTime at}) async {
    await db.from('notifications').insert({
        'title': title,
        'body': body,
        'category': category,
        'label': label,
        'icon': icon,
        'route': route,
        'scheduled_for': utc(at),
      });
    Push.sync();
  }

  // ---------------- Badges ----------------
  static Future<List<Rec>> badges() async => List<Rec>.from(await db.from('badges').select().order('sort_order'));

  static Future<Map<String, DateTime>> earnedBadges() async {
    final rows = await db.from('user_badges').select().eq('user_id', _uid);
    return {for (final r in rows) r['badge_code'] as String: DateTime.parse(r['earned_at']).toLocal()};
  }

  static Future<void> refreshBadges() async {
    try {
      final res = await db.rpc('refresh_badges');
      if (res is List && res.isNotEmpty) {
        // SETOF text comes back as bare strings (or one-key rows on older PostgREST).
        BadgeCenter.announce([for (final c in res) (c is Map ? c.values.first : c).toString()]);
        await AppState.instance.refreshUnread();
      }
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
