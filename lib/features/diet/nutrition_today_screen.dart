import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Mifflin-St Jeor estimate × light-moderate activity (1.55).
int? suggestedCalories() {
  final p = AppState.instance.profile;
  if (p == null || p.weightKg == null || p.heightCm == null || p.age == null || p.sex == null) return null;
  final bmr = 10 * p.weightKg! + 6.25 * p.heightCm! - 5 * p.age! + (p.sex == 'male' ? 5 : -161);
  return ((bmr * 1.55) / 50).round() * 50;
}

class NutritionTodayScreen extends StatefulWidget {
  const NutritionTodayScreen({super.key});
  @override
  State<NutritionTodayScreen> createState() => _NutritionTodayScreenState();
}

class _NutritionTodayScreenState extends State<NutritionTodayScreen> {
  bool _loading = true;
  List<Rec> _meals = [];
  bool _details = false;

  int get _target => AppState.instance.profile?.calorieTarget ?? 2100;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _meals = await Repo.mealsOn(DateTime.now());
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _adjustTarget() async {
    double v = _target.toDouble();
    final s = suggestedCalories();
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Mindful Calorie Target', style: T.headlineMd),
            const SizedBox(height: 4),
            Text(s == null ? 'Add your age, sex, height and weight in your profile for a personal suggestion.' : 'Suggested for you: ~${Fmt.thousands(s)} kcal/day (Mifflin-St Jeor, moderately active).',
                style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            Center(child: Text('${Fmt.thousands(v)} kcal', style: T.headlineXlMobile)),
            VSlider(value: v, min: 1200, max: 3500, divisions: 46, onChanged: (x) => set(() => v = x)),
            if (s != null) Center(child: TextLinkButton('Use suggestion', color: AppColors.primary, onTap: () => set(() => v = s.toDouble()))),
            const SizedBox(height: Sp.sm),
            PrimaryButton('Save Target', onTap: () async {
              await AppState.instance.updateProfile({'calorie_target': v.round()});
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) setState(() {});
            }),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final logged = _meals.where((m) => m['status'] == 'logged').toList();
    final planned = _meals.where((m) => m['status'] == 'planned').toList();
    int sum(String k) => logged.fold<int>(0, (a, m) => a + (m[k] as num).toInt());
    final kcal = sum('kcal');
    final remaining = (_target - kcal).clamp(0, 99999);
    final pct = kcal / _target;
    final carbT = (_target * 0.5 / 4).round(), protT = (_target * 0.18 / 4).round(), fatT = (_target * 0.3 / 9).round();

    return VPage(
      header: const MainHeader('VitalU Diet & Nutrition'),
      nav: NavTab.diet,
      onRefresh: _load,
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainerHigh, fg: AppColors.onSurface, shadow: Shadows.tiny, onTap: () => goBack(context, '/diet')),
          const Spacer(),
          TagPill('🍊  Mindful Fuel • ${DateFormat('MMM d').format(DateTime.now())}', bg: AppColors.secondaryFixed, fg: AppColors.onSecondaryFixed),
          const SizedBox(width: 6),
          TagPill('Private', icon: Symbols.lock, bg: AppColors.surfaceContainerHigh),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Today's Nutrition", style: T.headlineMd),
                Text('Mindful Daily Fueling', style: T.labelMd.c(AppColors.primary)),
              ]),
            ),
            IconCircle(Symbols.spa, size: 40, iconSize: 22, bg: AppColors.surfaceContainerLow, fill: 1, shadow: Shadows.tiny),
          ]),
          const SizedBox(height: 6),
          Text('Nourish your mind for lectures and late-night study sessions. Balanced, peaceful energy with zero restrictive rules.', style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
        ]),
        VCard(
          clip: true,
          shadow: const [BoxShadow(color: Color(0x14984062), blurRadius: 36, offset: Offset(0, 16), spreadRadius: -10), BoxShadow(color: Color(0x0D5B3CDD), blurRadius: 16, offset: Offset(0, 4), spreadRadius: -2)],
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(top: -48, right: -48, child: Glow(color: AppColors.secondaryFixed.withValues(alpha: 0.4), size: 176)),
            Positioned(bottom: -40, left: -40, child: Glow(color: AppColors.primaryFixed.withValues(alpha: 0.5), size: 160)),
            Column(children: [
              Ring(
                value: pct,
                size: 224,
                stroke: 18,
                track: AppColors.surfaceContainerHighest,
                gradient: [AppColors.secondaryContainer, AppColors.secondary, AppColors.primary, AppColors.secondaryContainer],
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.secondaryFixed.withValues(alpha: 0.5), shape: BoxShape.circle),
                      child: const Text('🍑', style: TextStyle(fontSize: 24)),
                    ),
                    Positioned(right: -2, bottom: -2, child: IconCircle(Symbols.bolt, size: 16, iconSize: 10, bg: AppColors.tertiary, fg: AppColors.onTertiary)),
                  ]),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text(Fmt.thousands(remaining), style: T.headlineLg),
                    const SizedBox(width: 2),
                    Text('kcal', style: T.labelSm.c(AppColors.onSurfaceVariant)),
                  ]),
                  SizedBox(width: 100, child: Text('remaining for study fuel', textAlign: TextAlign.center, style: T.labelSm.s(10).c(AppColors.onSurfaceVariant).lh(1.2))),
                ]),
              ),
              const SizedBox(height: 4),
              Pill(
                color: AppColors.surfaceContainerHigh,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${(pct * 100).round()}% of Gentle Daily Target', style: T.labelSm.c(AppColors.primary)),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(Rad.xl)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _kv('Consumed', Fmt.thousands(kcal)),
                  Container(width: 1, height: 24, color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                  _kv('Target', '~${Fmt.thousands(_target)}'),
                ]),
              ),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Brain & Body Balance', style: T.headlineSm)),
            Text('Balanced ratios', style: T.labelSm.c(AppColors.onSurfaceVariant)),
          ]),
          const SizedBox(height: Sp.sm),
          _macro('Carbohydrates', 'Study & Brain Focus Fuel', Symbols.grain, AppColors.secondaryFixed.withValues(alpha: 0.6), AppColors.secondary, AppColors.secondaryContainer, sum('carbs_g'), carbT),
          const SizedBox(height: 10),
          _macro('Protein', 'Sustained Stamina & Recovery', Symbols.egg_alt, AppColors.primaryFixed, AppColors.primary, AppColors.primaryContainer, sum('protein_g'), protT),
          const SizedBox(height: 10),
          _macro('Healthy Fats', 'Cellular & Brain Wellness', Symbols.nature_people, AppColors.tertiaryFixed, AppColors.tertiary, AppColors.tertiaryContainer, sum('fat_g'), fatT),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("Today's Meals", style: T.headlineSm),
                Text('Gentle nourishment rhythm', style: T.labelSm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
            Pressable(
              onTap: () => setState(() => _details = !_details),
              child: Pill(color: AppColors.surfaceContainer, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text(_details ? 'Hide Details' : 'View Details', style: T.labelMd.c(AppColors.primary))),
            ),
          ]),
          const SizedBox(height: Sp.sm),
          if (_loading) const Loading(),
          if (!_loading && _meals.isEmpty) const EmptyState(icon: Symbols.restaurant, title: 'No meals yet today', text: 'Log breakfast, lunch or a study snack to see your balance.'),
          for (final m in logged) Padding(padding: const EdgeInsets.only(bottom: 10), child: _mealCard(m)),
          for (final m in planned) Padding(padding: const EdgeInsets.only(bottom: 10), child: _plannedCard(m)),
        ]),
        PrimaryButton('Log an Additional Snack or Drink', leadingIcon: Symbols.add_circle, color: AppColors.inverseSurface, fg: AppColors.onPrimary, height: 52, onTap: () async {
          await context.push('/diet/log?type=snack');
          _load();
        }),
        Center(child: TextLinkButton('Adjust Mindful Calorie Target', color: AppColors.primary, onTap: _adjustTarget)),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.xl)),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Symbols.favorite, size: 15, color: AppColors.tertiary),
              const SizedBox(width: 6),
              Text('Zero-Guilt Promise', style: T.labelSm.s(11).c(AppColors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 4),
            Text('Nutrition values are gentle estimates. No restrictive alerts, no streak breaks, and no shame. Just wholesome support for student life.',
                textAlign: TextAlign.center, style: T.bodySm.s(11).c(AppColors.onSurfaceVariant).lh(1.6)),
          ]),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Column(children: [
        Text(k, style: T.labelSm.s(11).c(AppColors.onSurfaceVariant)),
        Text.rich(TextSpan(text: v, children: [TextSpan(text: ' kcal', style: T.bodySm.s(11).c(AppColors.outline))]), style: T.labelLg),
      ]);

  Widget _macro(String name, String sub, IconData icon, Color bg, Color fg, Color bar, int value, int target) {
    final p = target == 0 ? 0.0 : value / target;
    return VCard(
      padding: const EdgeInsets.all(14),
      radius: Rad.xl,
      shadow: Shadows.tiny,
      child: Column(children: [
        Row(children: [
          IconCircle(icon, size: 36, iconSize: 19, bg: bg, fg: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: T.labelMd.lh(1.2)),
              Text(sub, style: T.bodySm.s(11).c(AppColors.onSurfaceVariant)),
            ]),
          ),
          Text.rich(TextSpan(text: '${value}g', children: [TextSpan(text: ' / ${target}g', style: T.bodySm.s(11).c(AppColors.outline))]), style: T.labelMd),
        ]),
        const SizedBox(height: 8),
        Container(
          height: 12,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: AppColors.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
          child: Bar(value: p, height: 8, color: bar, track: Colors.transparent),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('${(p * 100).round()}% mindful intake', style: T.labelSm.s(11).c(AppColors.onSurfaceVariant))),
          Text(value >= target ? 'Target reached' : '${target - value}g remaining', style: T.labelSm.s(11).c(fg)),
        ]),
      ]),
    );
  }

  (IconData, Color, Color) _style(String type) => switch (type) {
        'breakfast' => (Symbols.bakery_dining, AppColors.secondaryFixed.withValues(alpha: 0.5), AppColors.secondary),
        'lunch' => (Symbols.ramen_dining, AppColors.primaryFixed, AppColors.primary),
        'dinner' => (Symbols.skillet, AppColors.primaryFixed.withValues(alpha: 0.6), AppColors.primary),
        _ => (Symbols.nutrition, AppColors.tertiaryFixed, AppColors.tertiary),
      };

  String _label(String t) => t == 'snack' ? 'Study Snack' : t[0].toUpperCase() + t.substring(1);

  Widget _mealCard(Rec m) {
    final (icon, bg, fg) = _style(m['meal_type']);
    return Dismissible(
      key: ValueKey(m['id']),
      direction: DismissDirection.endToStart,
      background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 24), child: Icon(Symbols.delete, color: AppColors.error)),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(title: const Text('Remove this meal?'), actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove')),
        ]),
      ),
      onDismissed: (_) async {
        await Repo.deleteMeal(m['id']);
        _load();
      },
      child: VCard(
        padding: const EdgeInsets.all(14),
        radius: Rad.xl,
        shadow: Shadows.tiny,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(icon, size: 44, iconSize: 22, bg: bg, fg: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${_label(m['meal_type']).toUpperCase()} • ${DateFormat('h:mm a').format(DateTime.parse(m['logged_at']).toLocal())}', style: T.labelSm.s(11).c(fg).tracking(0.8))),
                  Text('${m['kcal']} kcal', style: T.labelMd.bold),
                ]),
                Text(m['name'], style: T.labelLg, overflow: TextOverflow.ellipsis),
                if (m['source'] != null) Text(m['source'], style: T.bodySm.s(12).c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            for (final t in ['${m['carbs_g']}g C', '${m['protein_g']}g P', '${m['fat_g']}g F']) ...[
              Pill(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), child: Text(t, style: T.labelSm.s(11).c(AppColors.onSurfaceVariant))),
              const SizedBox(width: 6),
            ],
            const Spacer(),
            Icon(Symbols.check_circle, size: 14, color: AppColors.tertiary),
            const SizedBox(width: 2),
            Text('Nourished', style: T.labelSm.s(11).c(AppColors.tertiary)),
          ]),
          if (_details && (m['food_groups'] as List).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Food groups: ${(m['food_groups'] as List).join(', ').replaceAll('_', ' ')}', style: T.bodySm.s(11).c(AppColors.outline)),
          ],
        ]),
      ),
    );
  }

  Widget _plannedCard(Rec m) {
    final (icon, _, fg) = _style(m['meal_type']);
    return VCard(
      color: AppColors.surfaceContainerLow.withValues(alpha: 0.7),
      padding: const EdgeInsets.all(14),
      radius: Rad.xl,
      shadow: Shadows.tiny,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconCircle(icon, size: 44, iconSize: 22, bg: AppColors.primaryFixed.withValues(alpha: 0.6), fg: fg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('PLANNED ${_label(m['meal_type']).toUpperCase()}', style: T.labelSm.s(11).c(AppColors.primary).tracking(0.8))),
                Pill(color: AppColors.surfaceContainerHighest, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), child: Text('🕒 Planned', style: T.labelSm.s(10).c(AppColors.primary))),
              ]),
              Text(m['name'], style: T.labelLg, overflow: TextOverflow.ellipsis),
              Text('${m['source'] ?? ''} • ~${m['kcal']} kcal', style: T.bodySm.s(12).c(AppColors.onSurfaceVariant)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Ready to tap when you eat', style: T.bodySm.s(11).c(AppColors.onSurfaceVariant).copyWith(fontStyle: FontStyle.italic))),
          PrimaryButton('Confirm Meal', height: 30, expand: false, textStyle: T.labelSm.s(11), onTap: () async {
            await Repo.confirmMeal(m);
            _load();
          }),
        ]),
      ]),
    );
  }
}
