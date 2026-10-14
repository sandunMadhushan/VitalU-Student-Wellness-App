import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final female = AppState.instance.profile?.sex != 'male';
    void go(String r) => context.push(r);

    return VPage(
      header: const MainHeader('Health tools'),
      nav: NavTab.tools,
      topPadding: 0,
      children: [
        HeroBanner(
          title: 'Quick checks,\nclear answers',
          subtitle: 'Results stay private to you.',
          accent: AppColors.mind,
          illustration: 'hero_tools',
        ),
        TileGrid(children: [
          // Check-ups first, then the daily trackers.
          ToolBlock(icon: Symbols.monitor_weight_rounded, color: AppColors.body, kind: 'Body', title: 'BMI calculator', text: 'Category, target range and tips', action: 'Check', onTap: () => go('/tools/bmi')),
          ToolBlock(icon: Symbols.straighten_rounded, color: AppColors.water, kind: 'Proportion', title: 'WHR calculator', text: 'Where your body stores weight', action: 'Check', onTap: () => go('/tools/whr')),
          ToolBlock(icon: Symbols.cardiology_rounded, color: AppColors.heart, kind: 'Heart', title: 'CVD risk indicator', text: 'A cardiovascular risk factor check', action: 'Check', onTap: () => go('/tools/heart-risk')),
          ToolBlock(icon: Symbols.psychology_rounded, color: AppColors.mind, kind: 'Mind', title: 'Anxiety tracker', text: 'The validated DASS-21 self-check', action: 'Start', onTap: () => go('/tools/stress')),
          ToolBlock(icon: Symbols.water_drop_rounded, color: AppColors.water, kind: 'Hydration', title: 'Water intake tracker', text: 'A weight-based daily target', action: 'Log', onTap: () => go('/tools/water')),
          ToolBlock(icon: Symbols.directions_walk_rounded, color: AppColors.activity, kind: 'Movement', title: 'Activity tracker', text: 'IPAQ-SF check-in and daily logging', action: 'Log', onTap: () => go('/tools/activity')),
          ToolBlock(icon: Symbols.bedtime_rounded, color: AppColors.sleep, kind: 'Rest', title: 'Sleep tracker', text: 'Bedtime, wake time and quality', action: 'Log', onTap: () => go('/tools/sleep')),
          if (female) ToolBlock(icon: Symbols.menstrual_health_rounded, color: AppColors.cycle, kind: 'Cycle', title: 'Cycle tracker', text: 'Phases, symptoms and predictions', action: 'Track', onTap: () => go('/tools/cycle')),
        ]),
        ToolBlock(
          icon: Symbols.stethoscope_rounded,
          color: AppColors.primary,
          kind: 'Support',
          title: 'Talk to a professional',
          text: 'Free campus counsellors and doctors',
          action: 'Book',
          wide: true,
          onTap: () => go('/professionals'),
        ),
        // Last on purpose: the reader sits at the very end of the tools list.
        ToolBlock(icon: Symbols.lab_profile_rounded, color: AppColors.heart, kind: 'Lab results', title: 'Blood report reader', text: 'Understand your lab results', action: 'Read', wide: true, onTap: () => go('/blood-report')),
        const PrivacyNote('These tools are for self-awareness, not diagnosis.'),
      ],
    );
  }
}

/// Tinted tool card: icon badge, category, title, one-line description and
/// an action pill.
class ToolBlock extends StatelessWidget {
  const ToolBlock({super.key, required this.icon, required this.color, required this.kind, required this.title, required this.text, required this.action, required this.onTap, this.wide = false});
  final IconData icon;
  final Color color;
  final String kind;
  final String title;
  final String text;
  final String action;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final bg = Color.alphaBlend(color.withValues(alpha: dark ? 0.16 : 0.10), AppColors.surfaceContainerLowest);
    final raised = dark ? Colors.white.withValues(alpha: 0.07) : Colors.white;
    final badge = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: raised,
        shape: BoxShape.circle,
        boxShadow: dark ? null : [BoxShadow(color: color.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4), spreadRadius: -4)],
      ),
      child: Icon(icon, size: 24, color: color, fill: 1),
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
              ? Row(children: [
                  badge,
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
                  const SizedBox(width: 10),
                  pill,
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  badge,
                  const SizedBox(height: 14),
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
