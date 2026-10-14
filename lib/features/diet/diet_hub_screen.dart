import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/badges.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/badge_ui.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'diet_science.dart';
import 'pdqs_screen.dart' show pdqsBand;

class DietHubScreen extends StatefulWidget {
  const DietHubScreen({super.key});
  @override
  State<DietHubScreen> createState() => _DietHubScreenState();
}

class _DietHubScreenState extends State<DietHubScreen> {
  int _kcal = 0;
  int _target = 2100;
  int _mealsToday = 0;
  LoggedDietQuality? _quality;
  Rec? _pdqs;
  int _streakVersion = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _target = await effectiveCalorieTarget();
      final now = DateTime.now();
      final week = await Repo.mealsBetween(dayStart(now).subtract(const Duration(days: 6)), now);
      final today = isoDate(now);
      final logged = week.where((m) => m['status'] == 'logged' && m['meal_date'] == today).toList();
      _kcal = logged.fold<int>(0, (a, m) => a + (m['kcal'] as num).toInt());
      _mealsToday = logged.length;
      _quality = loggedDietQuality(week);
    } catch (_) {}
    try {
      _pdqs = await Repo.latestToolResult('pdqs');
    } catch (_) {}
    if (mounted) setState(() => _streakVersion++);
  }

  Future<void> _go(String path) async {
    await context.push(path);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: const MainHeader('Diet'),
      nav: NavTab.diet,
      onRefresh: _load,
      topPadding: 0,
      children: [
        HeroBanner(
          title: 'Eat well,\nfeel your best',
          subtitle: 'Balanced meals, tracked simply.',
          accent: AppColors.nutrition,
          illustration: 'hero_diet',
        ),
        DietFeatureCard(
          image: 'calorie_counter',
          color: AppColors.nutrition,
          kind: 'Energy',
          title: 'Calorie counter',
          text: _mealsToday == 0 ? 'Your personal daily target, worked out from your profile' : '${Fmt.thousands(_kcal)} of ${Fmt.thousands(_target)} kcal today · $_mealsToday ${_mealsToday == 1 ? 'meal' : 'meals'}',
          action: 'Open',
          wide: true,
          progress: _target == 0 ? null : _kcal / _target,
          onTap: () => _go('/diet/today'),
        ),
        TileGrid(children: [
          DietFeatureCard(image: 'meal_diary', color: AppColors.mind, kind: 'Logging', title: 'Meal diary', text: 'Log meals by portion or with a photo', action: 'Log', onTap: () => _go('/diet/diary')),
          DietFeatureCard(image: 'plate_guide', color: AppColors.water, kind: 'Portions', title: 'Healthy plate', text: 'Portions with your own hand', action: 'Learn', onTap: () => _go('/diet/plate')),
          DietFeatureCard(image: 'diversity', color: AppColors.tertiary, kind: 'Variety', title: 'Dietary diversity', text: 'Ten food groups, scored daily', action: 'Check', onTap: () => _go('/diet/diversity')),
          DietFeatureCard(image: 'budget', color: AppColors.warning, kind: 'Budget', title: 'Budget planner', text: 'Balanced meals within your budget', action: 'Plan', onTap: () => _go('/diet/budget')),
        ]),
        _qualityCard(),
        StreakBadgeCard(kind: StreakKind.smart, version: _streakVersion),
        const PrivacyNote('Meal logs are private to your account.'),
      ],
    );
  }

  /// Diet quality from the last 7 days of meal logs, with the latest PDQS
  /// self-check alongside.
  Widget _qualityCard() {
    final q = _quality;
    final last = _pdqs;
    final score = q != null && q.daysLogged > 0 ? q.score : (last?['score'] as num?)?.round();
    final (band, color) = score == null ? ('Not checked yet', AppColors.onSurfaceVariant) : pdqsBand(score);
    final String note;
    if (q != null && q.daysLogged > 0) {
      note = q.reliable ? 'Estimated from your meal logs over the last 7 days.' : 'From ${q.daysLogged} logged ${q.daysLogged == 1 ? 'day' : 'days'} this week. Log at least 4 days for a fair estimate.';
    } else if (last != null) {
      note = 'From your last weekly check-in.';
    } else {
      note = 'Log your meals, or take the 2 minute check-in, to see your score.';
    }
    return VCard(
      onTap: () => _go('/diet/pdqs'),
      child: Row(children: [
        Ring(
          value: (score ?? 0) / 42,
          size: 72,
          stroke: 7,
          color: color,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(score == null ? '–' : '$score', style: T.metric(22)),
            Text('/ 42', style: T.labelSm.c(AppColors.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(width: Sp.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CategoryLabel('Diet quality', icon: Symbols.verified_rounded, color: AppColors.nutrition),
            const SizedBox(height: 4),
            Text(band, style: T.headlineSm.c(score == null ? AppColors.onSurface : color)),
            const SizedBox(height: 2),
            Text(note, style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ]),
        ),
        Icon(Symbols.chevron_right_rounded, color: AppColors.outline),
      ]),
    );
  }
}

/// Diet tool card in the style of the Health tools cards, with a 3D image
/// (`assets/icons3d/<image>.jpg`) in place of the icon badge.
class DietFeatureCard extends StatelessWidget {
  const DietFeatureCard({
    super.key,
    required this.image,
    required this.color,
    required this.kind,
    required this.title,
    required this.text,
    required this.action,
    required this.onTap,
    this.wide = false,
    this.progress,
  });
  final String image;
  final Color color;
  final String kind;
  final String title;
  final String text;
  final String action;
  final VoidCallback onTap;
  final bool wide;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final bg = Color.alphaBlend(color.withValues(alpha: dark ? 0.16 : 0.10), AppColors.surfaceContainerLowest);
    final raised = dark ? Colors.white.withValues(alpha: 0.07) : Colors.white;
    final art = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.asset('assets/icons3d/$image.jpg', width: wide ? 76 : 64, height: wide ? 76 : 64, fit: BoxFit.cover),
    );
    final pill = Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: raised, borderRadius: BorderRadius.circular(19)),
      child: Row(mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max, children: [
        Text(action, style: T.labelMd.c(AppColors.onSurface).w(FontWeight.w700)),
        if (wide) const SizedBox(width: 8) else const Spacer(),
        Icon(Symbols.arrow_forward_rounded, size: 18, color: AppColors.onSurface),
      ]),
    );
    final label = Text(kind, style: T.labelSm.c(color).w(FontWeight.w700).tracking(0.2));
    final heading = Text(title, style: T.headlineSm.s(17), maxLines: 1, overflow: TextOverflow.ellipsis);
    final desc = Text(text, style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(Rad.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: wide
              ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    art,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        label,
                        const SizedBox(height: 2),
                        heading,
                        const SizedBox(height: 2),
                        desc,
                      ]),
                    ),
                  ]),
                  if (progress != null) ...[
                    const SizedBox(height: 12),
                    Bar(value: progress!.clamp(0, 1).toDouble(), height: 8, color: color),
                  ],
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: pill),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  art,
                  const SizedBox(height: 12),
                  label,
                  const SizedBox(height: 2),
                  heading,
                  const SizedBox(height: 4),
                  desc,
                  const Spacer(),
                  const SizedBox(height: 14),
                  pill,
                ]),
        ),
      ),
    );
  }
}
