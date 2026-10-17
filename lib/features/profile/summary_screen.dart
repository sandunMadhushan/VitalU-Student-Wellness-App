import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/catalog.dart' show minDietaryDiversity;
import '../../data/repo.dart';
import '../../ui/badge_ui.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../diet/pdqs_screen.dart' show pdqsBand;
import '../../core/health_report.dart';
import '../diet/diet_science.dart' show diversityByDay;

Future<R> _safe<R>(Future<R> f, R fallback) async {
  try {
    return await f;
  } catch (e) {
    debugPrint('summary: $e');
    return fallback;
  }
}

/// How the student has been using VitalU, from their own records only.
/// Nothing is estimated: a number that has no data behind it is not shown.
class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});
  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  bool _loading = true;
  List<Rec> _assessments = [];
  List<Rec> _windows = [];
  int _meals = 0;
  Rec? _pdqs;
  List<Rec> _diversityWeek = [];
  Map<String, int> _tools = {};
  Map<String, DateTime> _earned = {};
  List<Rec> _badges = [];
  Set<String> _active = {};

  static const _toolNames = {
    'bmi': ('BMI calculator', Symbols.monitor_weight_rounded),
    'whr': ('WHR calculator', Symbols.straighten_rounded),
    'cvd': ('CVD risk indicator', Symbols.cardiology_rounded),
    'stress': ('Anxiety tracker', Symbols.psychology_rounded),
    'ipaq': ('Activity check-in', Symbols.directions_walk_rounded),
    'pdqs': ('Diet quality score', Symbols.restaurant_rounded),
    'vitals': ('Lab readings', Symbols.lab_profile_rounded),
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now();
    final r = await Future.wait<Object?>([
      _safe(Repo.assessments(), <Rec>[]),
      _safe(Repo.windows(), <Rec>[]),
      _safe(Repo.mealsLoggedCount(), 0),
      _safe(Repo.latestToolResult('pdqs'), null),
      _safe(Repo.diversityBetween(dayStart(now).subtract(const Duration(days: 6)), now), <Rec>[]),
      _safe(Repo.toolUseCounts(), <String, int>{}),
      _safe(Repo.earnedBadges(), <String, DateTime>{}),
      _safe(Repo.badges(), <Rec>[]),
      _safe(Repo.activeDays(30), <String>{}),
    ]);
    _assessments = r[0] as List<Rec>;
    _windows = r[1] as List<Rec>;
    _meals = r[2] as int;
    _pdqs = r[3] as Rec?;
    _diversityWeek = r[4] as List<Rec>;
    _tools = r[5] as Map<String, int>;
    _earned = r[6] as Map<String, DateTime>;
    _badges = r[7] as List<Rec>;
    _active = r[8] as Set<String>;
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: TitleHeader('Summary', onLeading: () => goBack(context, '/profile')),
      onRefresh: _load,
      children: _loading ? [const Loading()] : _content(),
    );
  }

  List<Widget> _content() {
    final p = AppState.instance.profile;
    final now = DateTime.now();
    final joined = p?.createdAt ?? DateTime(2000);
    final mine = _windows.where((w) => w['faculty'] == null || w['faculty'] == p?.faculty).toList();
    // Expected: windows for this student's faculty that have opened since they joined.
    final expected = mine.where((w) {
      final o = DateTime.parse(w['opens_at']).toLocal(), c = DateTime.parse(w['closes_at']).toLocal();
      return o.isBefore(now) && c.isAfter(joined);
    }).toList();
    final completed = _assessments.where((a) => a['status'] == 'completed').toList();
    final completedIds = completed.map((a) => a['window_id']).toSet();
    final pending = expected.where((w) => DateTime.parse(w['closes_at']).toLocal().isAfter(now) && !completedIds.contains(w['id'])).toList();
    final next = mine.where((w) => DateTime.parse(w['opens_at']).toLocal().isAfter(now)).toList()..sort((a, b) => (a['opens_at'] as String).compareTo(b['opens_at'] as String));
    final latest = completed.isEmpty ? null : DateTime.parse(completed.first['completed_at']).toLocal();

    final goodDays = diversityByDay(_diversityWeek).values.where((g) => g.length >= minDietaryDiversity).length;
    final pdqsScore = (_pdqs?['score'] as num?)?.round();

    return [
      Text('Your activity in VitalU, from your own records.', style: T.bodyLg.c(AppColors.onSurfaceVariant)),
      Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rad.xl),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
            Color.alphaBlend(AppColors.heart.withValues(alpha: AppColors.isDark ? 0.24 : 0.12), AppColors.surfaceContainerLowest),
            Color.alphaBlend(AppColors.primary.withValues(alpha: AppColors.isDark ? 0.12 : 0.05), AppColors.surfaceContainerLowest),
          ]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconCircle(Symbols.picture_as_pdf_rounded, size: 48, iconSize: 26, fg: AppColors.heart, fill: 1),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Personal Health Report', style: T.headlineSm),
                Text('Your measurements against healthy ranges, heart risk, diet, stress, sleep and activity, with simple recommendations.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          PrimaryButton('Download my report (PDF)', leadingIcon: Symbols.download_rounded, onTap: () async {
            try {
              await HealthReport.share();
            } catch (_) {
              if (mounted) toast(context, 'Could not create the report. Please try again.', error: true);
            }
          }),
        ]),
      ),
      const SectionHeader('Periodic health assessments'),
      VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Ring(
              value: expected.isEmpty ? 0 : completed.length / expected.length,
              size: 84,
              stroke: 9,
              color: AppColors.primary,
              child: Text('${completed.length}/${expected.isEmpty ? completed.length : expected.length}', style: T.metric(20)),
            ),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${completed.length} completed', style: T.headlineSm),
                Text(expected.isEmpty ? 'No assessment has opened for you yet.' : 'of ${expected.length} offered to you since you joined', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(latest == null ? 'Most recent: none yet' : 'Most recent: ${DateFormat('d MMM yyyy').format(latest)}', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
          const SizedBox(height: Sp.md),
          _status(
            pending.isNotEmpty ? Symbols.pending_actions_rounded : Symbols.event_upcoming_rounded,
            pending.isNotEmpty ? AppColors.warning : AppColors.primary,
            pending.isNotEmpty
                ? 'Pending: ${pending.first['term']} closes ${DateFormat('d MMM').format(DateTime.parse(pending.first['closes_at']).toLocal())}'
                : next.isNotEmpty
                    ? 'Next: ${next.first['term']} opens ${DateFormat('d MMM').format(DateTime.parse(next.first['opens_at']).toLocal())}'
                    : 'No upcoming assessment scheduled',
            onTap: () => context.push('/assessments'),
          ),
        ]),
      ),
      const SectionHeader('Eating', subtitle: 'Optional activities'),
      TileGrid(gap: 10, children: [
        _stat(Symbols.restaurant_rounded, AppColors.nutrition, 'Meals logged', '$_meals', 'in total', () => context.push('/diet')),
        _stat(Symbols.verified_rounded, pdqsScore == null ? AppColors.onSurfaceVariant : pdqsBand(pdqsScore).$2, 'Diet quality', pdqsScore == null ? '–' : '$pdqsScore/42',
            pdqsScore == null ? 'No check-in yet' : 'Checked ${DateFormat('d MMM').format(DateTime.parse(_pdqs!['created_at']).toLocal())}', () => context.push('/diet/pdqs')),
        _stat(Symbols.nutrition_rounded, AppColors.nutrition, 'Varied days', '$goodDays/7', 'days with 5+ food groups', () => context.push('/diet/diversity')),
        _stat(Symbols.calendar_month_rounded, AppColors.water, 'Active days', '${_active.length}/30', 'days with any tracking', null),
      ]),
      const SectionHeader('Health tools used'),
      if (_tools.isEmpty)
        VCard(child: Text('You have not used a health tool yet. They are all in the Tools tab.', style: T.bodyMd.c(AppColors.onSurfaceVariant)))
      else
        VCard(
          child: Column(children: [
            for (final e in _toolNames.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(e.value.$2, size: 20, color: (_tools[e.key] ?? 0) > 0 ? AppColors.primary : AppColors.outline, fill: 1),
                  const SizedBox(width: 10),
                  Expanded(child: Text(e.value.$1, style: T.bodyMd)),
                  Text((_tools[e.key] ?? 0) == 0 ? 'Not yet' : '${_tools[e.key]}×', style: T.labelMd.c((_tools[e.key] ?? 0) > 0 ? AppColors.onSurface : AppColors.onSurfaceVariant)),
                ]),
              ),
          ]),
        ),
      SectionHeader('Achievements', trailing: TextLinkButton('See all', onTap: () => context.push('/milestones'))),
      VCard(
        onTap: () => context.push('/milestones'),
        child: Row(children: [
          Ring(value: _badges.isEmpty ? 0 : _earned.length / _badges.length, size: 64, stroke: 7, color: AppColors.warning, child: Icon(Symbols.military_tech_rounded, color: AppColors.warning, fill: 1)),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_earned.length} of ${_badges.length} badges', style: T.headlineSm),
              const SizedBox(height: 6),
              if (_earned.isEmpty)
                Text('Your first badge is a few logs away.', style: T.bodySm.c(AppColors.onSurfaceVariant))
              else
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final b in _badges.where((b) => _earned.containsKey(b['code'])).take(6)) BadgeArt(code: b['code'], icon: b['icon'], category: b['category'], size: 36, ribbon: false),
                ]),
            ]),
          ),
        ]),
      ),
      const PrivacyNote('Only you can see this summary.'),
    ];
  }

  Widget _status(IconData icon, Color c, String text, {VoidCallback? onTap}) => Material(
        color: AppColors.tint(c),
        borderRadius: BorderRadius.circular(Rad.base),
        child: InkWell(
          borderRadius: BorderRadius.circular(Rad.base),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 18, color: c, fill: 1),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: T.labelMd.c(AppColors.onSurface))),
              Icon(Symbols.chevron_right_rounded, size: 18, color: AppColors.outline),
            ]),
          ),
        ),
      );

  Widget _stat(IconData icon, Color c, String label, String value, String caption, VoidCallback? onTap) => VCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconCircle(icon, size: 32, iconSize: 18, fg: c, radius: 10, fill: 1),
          const SizedBox(height: 10),
          Text(label, style: T.labelMd.c(AppColors.onSurfaceVariant)),
          MetricValue(value, size: 22),
          Text(caption, style: T.bodySm.c(AppColors.outline), maxLines: 2),
        ]),
      );
}
