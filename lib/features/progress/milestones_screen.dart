import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/badges.dart';
import '../../data/repo.dart';
import '../../ui/badge_ui.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../tools/tool_widgets.dart';

/// The five badges, each with how to earn it and live progress.
class MilestonesScreen extends StatefulWidget {
  const MilestonesScreen({super.key});
  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  bool _loading = true;
  List<Rec> _badges = [];
  Map<String, DateTime> _earned = {};
  final _streaks = <String, StreakInfo>{};
  final _steps = <String, List<BadgeStep>>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await Repo.refreshBadges();
      _badges = await Repo.badges();
      _earned = await Repo.earnedBadges();
      await Future.wait([
        for (final k in StreakKind.values) Streaks.of(k).then((i) => _streaks[StreakBadge.of(k).code] = i).catchError((_) => const StreakInfo(streak: 0, todayDone: false, earned: false)),
        for (final c in const ['heart_minded', 'curious_learner']) badgeSteps(c).then((s) => _steps[c] = s).catchError((_) => const <BadgeStep>[]),
      ]);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _explain() => showInfoSheet(context, title: 'How badges work', icon: Symbols.military_tech_rounded, paragraphs: const [
        'Aqua Achiever, Active Aura and Smart Eater are streak badges: meet the goal on days in a row. Miss a day and the streak simply starts again.',
        'Smart Eater rewards regular, varied, balanced eating, never eating less. It needs three main meals a day from 5 or more food groups for 7 days, and a diet quality score of at least 22 out of 42 for that week.',
        'Heart Minded is for knowing your numbers, and Curious Learner for reading widely in Learn.',
        'Badges are private and never compared with anyone else.',
      ]);

  @override
  Widget build(BuildContext context) {
    final n = _earned.keys.where(badgeCodes.contains).length;
    return VPage(
      header: TitleHeader('Achievements', onLeading: () => goBack(context, '/profile'), actions: [
        IconButton(tooltip: 'How badges work', icon: const Icon(Symbols.info_rounded), onPressed: _explain),
      ]),
      onRefresh: _load,
      children: [
        VCard(
          child: Row(children: [
            Ring(value: n / badgeCodes.length, size: 64, stroke: 6, color: AppColors.warning, child: Icon(Symbols.military_tech_rounded, color: AppColors.warning, fill: 1)),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                MetricValue('$n', unit: 'of ${badgeCodes.length} badges earned', size: 28),
                const SizedBox(height: 2),
                Text(n == 0 ? 'Start with Aqua Achiever: reach your water goal three days in a row.' : 'Keep going. Each badge celebrates a healthy habit.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        if (_loading) const Loading() else for (final b in _badges) _card(b),
        const PrivacyNote('Badges are private and never compared with other students.'),
      ],
    );
  }

  Widget _card(Rec b) {
    final code = b['code'] as String;
    final at = _earned[code];
    final c = badgeColor(code, b['category']);
    final streak = _streaks[code];
    final steps = _steps[code];
    return VCard(
      onTap: at == null ? null : () => showBadgePopup(context, code: code, title: b['title'], description: b['description'], icon: b['icon'], category: b['category']),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          BadgeArt(code: code, icon: b['icon'], category: b['category'], size: 72, locked: at == null),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(b['title'], style: T.headlineSm)),
                if (at != null) TagPill('Earned ${DateFormat('d MMM').format(at.toLocal())}', icon: Symbols.verified_rounded, fill: 1, bg: AppColors.tint(c), fg: c),
              ]),
              const SizedBox(height: 4),
              Text(b['description'] ?? '', style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.4)),
            ]),
          ),
        ]),
        if (at == null && streak != null) ...[
          const SizedBox(height: 12),
          Row(children: [
            StreakStars(filled: streak.stars, count: streak.length, size: streak.length > 3 ? 17 : 22),
            const Spacer(),
            Text(streak.stars == 0 ? 'Start today' : '${streak.remaining} ${streak.remaining == 1 ? 'day' : 'days'} to go', style: T.labelMd.c(c)),
          ]),
          if (streak.weekPdqs != null) ...[
            const SizedBox(height: 6),
            Text('Diet quality this week: ${streak.weekPdqs} of 42 (needs $smartEaterPdqs)', style: T.labelSm.c(AppColors.onSurfaceVariant)),
          ],
        ],
        if (at == null && steps != null && steps.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final s in steps)
            InkWell(
              onTap: s.done || s.route == null ? null : () => context.push(s.route!),
              borderRadius: BorderRadius.circular(Rad.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Icon(s.done ? Symbols.check_circle_rounded : Symbols.radio_button_unchecked_rounded, size: 20, color: s.done ? AppColors.tertiary : AppColors.outline, fill: s.done ? 1 : 0),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.label, style: T.bodyMd.c(s.done ? AppColors.onSurfaceVariant : AppColors.onSurface))),
                  if (s.detail != null) Text(s.detail!, style: T.labelSm.c(AppColors.onSurfaceVariant)),
                  if (!s.done && s.route != null) Icon(Symbols.chevron_right_rounded, size: 18, color: AppColors.outline),
                ]),
              ),
            ),
        ],
      ]),
    );
  }
}
