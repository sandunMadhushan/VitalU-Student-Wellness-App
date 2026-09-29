import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

const mealTypes = <(String, String, IconData)>[
  ('breakfast', 'Breakfast', Symbols.bakery_dining),
  ('lunch', 'Lunch', Symbols.rice_bowl),
  ('dinner', 'Dinner', Symbols.skillet),
  ('snack', 'Snacks', Symbols.nutrition),
];

class DietHubScreen extends StatefulWidget {
  const DietHubScreen({super.key});
  @override
  State<DietHubScreen> createState() => _DietHubScreenState();
}

class _DietHubScreenState extends State<DietHubScreen> {
  bool _loading = true;
  List<Rec> _meals = [];

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

  Future<void> _go(String path) async {
    await context.push(path);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final logged = _meals.where((m) => m['status'] == 'logged').toList();
    final kcal = logged.fold<int>(0, (a, m) => a + (m['kcal'] as int));
    final target = AppState.instance.profile?.calorieTarget ?? 2100;
    final typesLogged = mealTypes.where((t) => logged.any((m) => m['meal_type'] == t.$1)).length;

    return VPage(
      header: const MainHeader('Vitalu   Diet & Nutrition'),
      nav: NavTab.diet,
      onRefresh: _load,
      children: [
        VCard(
          clip: true,
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF4FBF4), Color(0xFFFDFEF6)]),
          shadow: Shadows.card,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(top: -48, right: -48, child: Glow(color: AppColors.tertiaryFixed.withValues(alpha: 0.3), size: 192)),
            Positioned(bottom: -32, left: -32, child: Glow(color: AppColors.secondaryFixed.withValues(alpha: 0.4), size: 144)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Pill(
                color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
                shadow: Shadows.tiny,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🥗', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Flexible(child: Text('MINDFUL NOURISHMENT • CAMPUS DINING', style: T.labelSm.c(AppColors.tertiary).tracking(0.6), overflow: TextOverflow.ellipsis)),
                ]),
              ),
              const SizedBox(height: 8),
              Text('Dietary Health', style: T.headlineLg),
              Text('Eat well, without the guesswork', style: T.headlineSm.c(AppColors.tertiary).medium),
              const SizedBox(height: 4),
              Text('Nourish your mind and body across study sessions and canteen runs. No calorie guilt or restrictive dieting, just balanced campus eating.',
                  style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
            ]),
          ]),
        ),
        VCard(
          shadow: Shadows.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text("Today's Nourishment", style: T.headlineSm),
                  Text('$typesLogged of 4 mindful meals logged', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
              IconCircle(Symbols.restaurant, size: 40, iconSize: 22, bg: AppColors.surfaceContainerLow),
            ]),
            const SizedBox(height: Sp.sm),
            Container(
              height: 224,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Rad.lg),
                gradient: LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: [AppColors.surfaceContainerLow, AppColors.surfaceContainerHigh]),
                boxShadow: Shadows.tiny,
              ),
              padding: const EdgeInsets.all(12),
              child: Stack(children: [
                const Positioned.fill(child: AssetImg('nourishment_bowl', radius: Rad.lg, fit: BoxFit.cover)),
                Positioned(
                  top: 8,
                  right: 8,
                  child: TagPill('Campus Fresh', icon: Symbols.eco, fill: 1, iconColor: AppColors.tertiary, bg: AppColors.surfaceContainerLowest.withValues(alpha: 0.9), fg: AppColors.onSurface),
                ),
              ]),
            ),
            const SizedBox(height: Sp.md),
            if (_loading)
              const Loading()
            else
              for (final t in mealTypes) Padding(padding: const EdgeInsets.only(bottom: 8), child: _mealRow(t)),
            const SizedBox(height: 8),
            Pressable(
              onTap: () => _go('/diet/today'),
              child: Container(
                padding: const EdgeInsets.all(Sp.sm),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.lg)),
                child: Row(children: [
                  Ring(
                    value: kcal / target,
                    size: 80,
                    stroke: 7,
                    color: AppColors.tertiary,
                    track: AppColors.surfaceContainerHighest,
                    child: Icon(Symbols.bolt, size: 22, color: AppColors.tertiary, fill: 1),
                  ),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('MINDFUL ENERGY BALANCE', style: T.labelSm.c(AppColors.onSurfaceVariant).tracking(0.8)),
                      const SizedBox(height: 2),
                      Text.rich(TextSpan(text: Fmt.thousands(kcal), style: T.headlineSm.bold, children: [TextSpan(text: ' / ~${Fmt.thousands(target)} kcal', style: T.bodySm.c(AppColors.onSurfaceVariant))])),
                      const SizedBox(height: 6),
                      Pill(
                        color: AppColors.surfaceContainerLowest,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        shadow: Shadows.tiny,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(kcal > target * 1.1 ? 'Above gentle target' : 'On Track for Study Energy', style: T.labelSm.s(11).c(AppColors.tertiary)),
                        ]),
                      ),
                    ]),
                  ),
                  Icon(Symbols.chevron_right, color: AppColors.onSurfaceVariant),
                ]),
              ),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Nourishment Hub', style: T.headlineSm),
              Text('Tools designed around university routines', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: Sp.sm),
          _hubItem(Symbols.photo_camera, const Color(0xFFEAF7EE), AppColors.tertiary, 'Log a Meal', 'Snap canteen food or quick-search hostel snacks', '/diet/log'),
          _hubItem(Symbols.energy_savings_leaf, const Color(0xFFFEF9E7), const Color(0xFFA07E00), 'Dietary Diversity', 'Check your weekly food groups and colourful micronutrients', '/diet/diversity'),
          _hubItem(Symbols.pie_chart, const Color(0xFFE8F4FC), const Color(0xFF1B659C), 'Healthy Plate Guide', 'Visual portions for canteens without food scales', '/diet/plate'),
          _hubItem(Symbols.calendar_month, AppColors.primaryFixed, AppColors.primary, 'Meal Planner', 'Prep stress-free weekly meals around lecture schedules', '/diet/planner'),
          _hubItem(Symbols.savings, AppColors.secondaryFixed, AppColors.secondary, 'Budget Meal Planner', 'Nutritious hostel-friendly meals within your weekly budget', '/diet/budget'),
        ]),
        VCard(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF2F9F5), AppColors.surfaceContainerLow]),
          shadow: Shadows.card,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(Symbols.lightbulb, size: 40, iconSize: 22, bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixed, shadow: Shadows.tiny),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CAMPUS DINING HACK', style: T.labelSm.c(AppColors.tertiary).tracking(0.8)),
                const SizedBox(height: 4),
                Text('Adding a leafy mallum (gotukola or mukunuwenna) and a spoon of dhal to your canteen rice boosts fibre, iron and steady afternoon focus.',
                    style: T.bodyMd.lh(1.4)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _go('/diet/log'),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Explore campus menu', style: T.labelMd.c(AppColors.primary)),
                    const SizedBox(width: 4),
                    Icon(Symbols.arrow_forward, size: 16, color: AppColors.primary),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        const PrivacyNote('Dietary and nutrition logs are private to your account. Never shared with university services.', icon: Symbols.lock),
      ],
    );
  }

  Widget _mealRow((String, String, IconData) t) {
    final list = _meals.where((m) => m['meal_type'] == t.$1).toList();
    final m = list.isEmpty ? null : (list.lastWhere((x) => x['status'] == 'logged', orElse: () => list.last));
    final logged = m?['status'] == 'logged';
    return Pressable(
      onTap: () => _go(m == null ? '/diet/log?type=${t.$1}' : '/diet/today'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: m != null && !logged ? AppColors.surfaceContainerLow.withValues(alpha: 0.6) : AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full)),
        child: Row(children: [
          IconCircle(t.$3, size: 32, iconSize: 18, fg: AppColors.onSurfaceVariant, shadow: Shadows.tiny),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t.$2, style: T.labelMd),
              Text(m == null ? 'Tap to log' : '${m['name']}${list.length > 1 ? ' +${list.length - 1}' : ''}', style: T.bodySm.c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
            ]),
          ),
          if (m != null)
            TagPill(logged ? 'Logged' : 'Planned', icon: logged ? Symbols.check : Symbols.schedule, bg: logged ? AppColors.tertiaryFixed : AppColors.surfaceContainerHighest, fg: logged ? AppColors.onTertiaryFixed : AppColors.onSurfaceVariant)
          else
            Icon(Symbols.add_circle, color: AppColors.primary, size: 22),
        ]),
      ),
    );
  }

  Widget _hubItem(IconData icon, Color bg, Color fg, String title, String sub, String route) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.xs),
        child: VCard(
          padding: const EdgeInsets.all(16),
          shadow: Shadows.card,
          onTap: () => _go(route),
          child: Row(children: [
            IconCircle(icon, size: 48, iconSize: 24, bg: bg, fg: fg, shadow: Shadows.tiny),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.headlineSm.s(16)),
                Text(sub, style: T.bodySm.c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              ]),
            ),
            Icon(Symbols.chevron_right, size: 20, color: AppColors.onSurfaceVariant),
          ]),
        ),
      );
}
