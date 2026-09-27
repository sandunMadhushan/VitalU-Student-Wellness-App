import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../home/home_screen.dart';
import '../tools/tool_widgets.dart';

class MilestonesScreen extends StatefulWidget {
  const MilestonesScreen({super.key});
  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  bool _loading = true;
  List<Rec> _badges = [];
  Map<String, DateTime> _earned = {};
  String _cat = 'all';

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
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  (Color, Color) _tone(String cat) => switch (cat) {
        'nourish' => (AppColors.tertiaryFixed, AppColors.tertiary),
        'rest' => (AppColors.primaryFixed, AppColors.primary),
        _ => (AppColors.secondaryFixed, AppColors.secondary),
      };

  @override
  Widget build(BuildContext context) {
    final shown = _badges.where((b) => _cat == 'all' || b['category'] == _cat).toList()
      ..sort((a, b) {
        final ea = _earned.containsKey(a['code']) ? 0 : 1, eb = _earned.containsKey(b['code']) ? 0 : 1;
        return ea != eb ? ea - eb : (a['sort_order'] as int).compareTo(b['sort_order'] as int);
      });
    final n = _earned.length, total = _badges.isEmpty ? 12 : _badges.length;

    return VPage(
      header: const MainHeader('Vitalu   Your Progress & Trends'),
      nav: NavTab.progress,
      onRefresh: _load,
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, iconSize: 20, shadow: Shadows.tiny, onTap: () => goBack(context, '/progress')),
          Expanded(
            child: Column(children: [
              Text('Milestones', style: T.headlineSm),
              Text('Self-Care Sanctuary', style: T.labelSm.c(AppColors.outline)),
            ]),
          ),
          CircleButton(Symbols.favorite, bg: AppColors.surfaceContainerLow, iconSize: 20, shadow: Shadows.tiny, onTap: () => showInfoSheet(context, title: 'How milestones work', icon: Symbols.military_tech, paragraphs: const [
                'Milestones unlock automatically as you use VitalU — hydrating, sleeping well, moving, logging meals, learning and checking in with yourself.',
                'They are optional, private and never compared with anyone else.',
              ])),
        ]),
        Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.xl),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.secondaryFixed, AppColors.surfaceContainerLow, AppColors.primaryFixed]),
            boxShadow: Shadows.tiny,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TagPill('Personal Growth • Zero Pressure', icon: Symbols.potted_plant, iconColor: AppColors.secondary, bg: AppColors.surfaceContainerLowest.withValues(alpha: 0.8), fg: AppColors.onSurface),
            const SizedBox(height: 6),
            Text('Your Milestones', style: T.headlineLg.lh(1.2)),
            const SizedBox(height: 4),
            Text('Small wins, celebrated. Every gentle step toward balance matters.', style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.6)),
            const SizedBox(height: Sp.sm),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('$n of $total Unlocked', style: T.labelLg),
                    const SizedBox(width: 8),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle)),
                  ]),
                  Text('No deadlines, take your time', style: T.bodySm.c(AppColors.outline)),
                ]),
              ),
              IconCircle(Symbols.military_tech, size: 56, iconSize: 28, bg: AppColors.surfaceContainerLowest.withValues(alpha: 0.9), fg: AppColors.secondary, shadow: Shadows.soft),
            ]),
            const SizedBox(height: 6),
            Container(
              height: 10,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLowest.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
              child: Bar(value: n / total, height: 6, track: Colors.transparent, gradient: const LinearGradient(colors: [AppColors.secondaryContainer, AppColors.primary])),
            ),
          ]),
        ),
        FullBleed(
          child: ChipRow(children: [
            for (final c in [('all', 'All Badges ($total)', Symbols.auto_awesome), ('nourish', 'Nourish & Hydrate', Symbols.water_drop), ('rest', 'Rest & Mind', Symbols.bedtime), ('milestone', 'Milestones', Symbols.menu_book)])
              VChip(c.$2, icon: c.$3, selected: _cat == c.$1, selectedColor: AppColors.surfaceContainerLowest, selectedFg: AppColors.onSurface, height: 36, onTap: () => setState(() => _cat = c.$1)),
          ]),
        ),
        if (_loading)
          const Loading()
        else
          LayoutBuilder(builder: (context, c) {
            final w = (c.maxWidth - 20) / 3;
            return Wrap(spacing: 10, runSpacing: 10, children: [for (final b in shown) SizedBox(width: w, child: _badge(b))]);
          }),
        VCard(
          radius: Rad.xl,
          shadow: Shadows.tiny,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(Symbols.self_improvement, size: 40, iconSize: 22, bg: AppColors.primaryFixed.withValues(alpha: 0.4)),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Feeling accomplished today?', style: T.labelLg),
                const SizedBox(height: 2),
                Text('Honor whatever you accomplished today—even simply pausing between study blocks counts as mindful restoration.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => showMoodPicker(context, onSaved: _load),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Log a gentle reflection', style: T.labelMd.c(AppColors.primary)),
                    const SizedBox(width: 4),
                    const Icon(Symbols.arrow_forward, size: 16, color: AppColors.primary),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.xl),
            gradient: const LinearGradient(colors: [AppColors.surfaceContainerHigh, AppColors.surfaceContainer]),
            boxShadow: Shadows.tiny,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const IconCircle(Symbols.favorite, size: 36, iconSize: 20, bg: AppColors.secondaryFixed, fg: AppColors.secondary, fill: 1),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('A gentle reminder for your journey', style: T.labelMd),
                const SizedBox(height: 4),
                Text('Wellness is never a competition. There are no streaks to lose, no penalty for busy exam weeks, and no ranks to climb. Celebrate these tokens simply as gentle reminders that you prioritised yourself.',
                    style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
              ]),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _badge(Rec b) {
    final earned = _earned[b['code']];
    final (bg, fg) = _tone(b['category']);
    return Pressable(
      onTap: () => showInfoSheet(context, title: b['title'], icon: iconByName(b['icon']), paragraphs: [
        b['description'] ?? '',
        earned != null ? 'Earned on ${DateFormat('d MMMM yyyy').format(earned)} 🎉' : 'Not yet unlocked — ${b['pending_label']?.toString().toLowerCase() ?? 'take your time'}.',
      ]),
      child: Opacity(
        opacity: earned != null ? 1 : 0.6,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: earned != null ? AppColors.surfaceContainerLowest : AppColors.surfaceContainerLow.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(Rad.xl),
            boxShadow: earned != null ? Shadows.tiny : null,
          ),
          child: Column(children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: earned != null ? bg.withValues(alpha: 0.4) : AppColors.surfaceContainer, shape: BoxShape.circle),
                  child: Icon(iconByName(b['icon']), size: earned != null ? 28 : 26, color: earned != null ? fg : AppColors.outline, fill: earned != null ? 1 : 0),
                ),
                if (earned != null)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, shape: BoxShape.circle, boxShadow: Shadows.tiny),
                      child: Icon(Symbols.check_circle, size: 14, color: fg),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            Text(b['title'], style: T.labelMd, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Pill(
              color: earned != null ? bg.withValues(alpha: 0.4) : AppColors.surfaceContainerHigh,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Text(earned != null ? 'Earned ${DateFormat('MMM d').format(earned)}' : (b['pending_label'] ?? 'Take your time'),
                  style: T.labelSm.s(10).c(earned != null ? fg : AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      ),
    );
  }
}
