import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

class _Tool {
  const _Tool(this.kicker, this.title, this.desc, this.icon, this.accent, this.bg, this.cta, this.route, this.cats, {this.femaleOnly = false});
  final String kicker;
  final String title;
  final String desc;
  final IconData icon;
  final Color accent;
  final Color bg;
  final String cta;
  final String route;
  final Set<String> cats;
  final bool femaleOnly;
}

final _tools = <_Tool>[
  _Tool('Biometric', 'BMI Calculator', 'Calibrate comfortable body baselines without clinical pressure.', Symbols.scale, AppColors.tertiary, AppColors.tertiaryFixed.withValues(alpha: 0.2), 'View', '/tools/bmi', {'calculators'}),
  _Tool('Proportion', 'WHR Calculator', 'Waist-to-hip balance and healthy body composition.', Symbols.straighten, AppColors.primary, AppColors.primaryFixed.withValues(alpha: 0.35), 'View', '/tools/whr', {'calculators'}),
  _Tool('Cardio', 'CVD Risk Check', 'Gentle cardiovascular screening for student routines.', Symbols.favorite, AppColors.secondary, AppColors.secondaryFixed.withValues(alpha: 0.4), 'Start', '/tools/heart-risk', {'calculators', 'daily'}),
  _Tool('Hydration', 'Water Intake', 'Log daily sips and beat lecture hall dehydration.', Symbols.water_drop, AppColors.primaryContainer, AppColors.surfaceContainerHigh, 'Start', '/tools/water', {'daily'}),
  _Tool('Mindset', 'Stress Checker', 'Quick exam-season check-in using the DASS-21 scale.', Symbols.wb_sunny, AppColors.onSecondaryFixedVariant, AppColors.surfaceContainerLow, 'Start', '/tools/stress', {'rest'}),
  _Tool('Mobility', 'Activity Tracker', 'Campus strolls, bike rides & low-intensity movement.', Symbols.directions_walk, AppColors.tertiary, AppColors.tertiaryFixedDim.withValues(alpha: 0.2), 'View', '/tools/activity', {'daily'}),
  _Tool('Rest', 'Sleep Quality', 'Track restful hours between lectures and late study sessions.', Symbols.bedtime, AppColors.primary, AppColors.surfaceContainerHighest.withValues(alpha: 0.6), 'View', '/tools/sleep', {'daily', 'rest'}),
  _Tool('Hormonal', 'Cycle & Rhythm', 'Mindful energy tracking and gentle phase sync.', Symbols.local_florist, AppColors.secondary, AppColors.secondaryFixed.withValues(alpha: 0.25), 'Start', '/tools/cycle', {'daily'}, femaleOnly: true),
];

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});
  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final male = AppState.instance.profile?.sex == 'male';
    final available = _tools.where((t) => !(t.femaleOnly && male)).toList();
    final shown = available.where((t) => _filter == 'all' || t.cats.contains(_filter)).toList();

    return VPage(
      header: const MainHeader('VitalU Health Tools'),
      nav: NavTab.tools,
      children: [
        VCard(
          clip: true,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.secondaryFixed, AppColors.surfaceContainerLow, AppColors.primaryFixed]),
          shadow: Shadows.card,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(right: -52, bottom: -60, child: Glow(color: AppColors.surfaceContainerLowest.withValues(alpha: 0.4), size: 176)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Pill(
                color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
                shadow: Shadows.tiny,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.tertiaryContainer, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('ZERO STRESS • STUDENT VITALS', style: T.labelSm.tracking(0.8)),
                ]),
              ),
              const SizedBox(height: 8),
              Text('Health Tools', style: T.headlineLg),
              const SizedBox(height: 4),
              Text('Simple checks, whenever you need them. No judgment, no streaks. Explore at your own pace.', style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.6)),
              const SizedBox(height: 10),
              Container(height: 1, color: AppColors.outlineVariant.withValues(alpha: 0.2)),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Symbols.spa, size: 18, color: AppColors.tertiary),
                const SizedBox(width: 8),
                Expanded(child: Text('Confidential, autonomous, and tuned for campus life', style: T.labelSm.c(AppColors.onSurfaceVariant))),
              ]),
            ]),
          ]),
        ),
        FullBleed(
          child: ChipRow(children: [
            for (final f in [('all', 'All (${available.length})'), ('calculators', 'Calculators'), ('daily', 'Daily Habits'), ('rest', 'Mental Rest')])
              VChip(f.$2, selected: _filter == f.$1, color: AppColors.surfaceContainerHigh, onTap: () => setState(() => _filter = f.$1)),
          ]),
        ),
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 12) / 2;
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final t in shown) SizedBox(width: w, child: _card(t))]);
        }),
        VCard(
          color: AppColors.surfaceContainerLow,
          shadow: Shadows.card,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(Symbols.lock, size: 40, fg: AppColors.tertiary, fill: 1, shadow: Shadows.tiny),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                  Text('Campus Support Ready', style: T.headlineSm),
                  TagPill('100% Private', bg: AppColors.surfaceContainerHighest),
                ]),
                const SizedBox(height: 4),
                Text('All tools are completely confidential. If you ever feel overwhelmed by deadlines or health stress, campus support is one gentle tap away.',
                    style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => context.push('/professionals'),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Reach campus wellness counselor', style: T.labelMd.c(AppColors.primary)),
                    Icon(Symbols.chevron_right, size: 16, color: AppColors.primary),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _card(_Tool t) => Pressable(
        onTap: () => context.push(t.route),
        child: Container(
          height: 232,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(Rad.lg), boxShadow: const [BoxShadow(color: Color(0x0D2D2B38), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -6)]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(t.icon, iconSize: 24, fg: t.accent, fill: 1, shadow: Shadows.tiny),
            const SizedBox(height: 12),
            Text(t.kicker.toUpperCase(), style: T.labelSm.c(t.accent).tracking(0.8)),
            const SizedBox(height: 2),
            Text(t.title, style: T.headlineSm.lh(1.3)),
            const SizedBox(height: 4),
            Expanded(child: Text(t.desc, style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis)),
            Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(Rad.full)),
              child: Row(children: [
                Text(t.cta, style: T.labelMd),
                const Spacer(),
                const Icon(Symbols.arrow_forward, size: 16),
              ]),
            ),
          ]),
        ),
      );
}
