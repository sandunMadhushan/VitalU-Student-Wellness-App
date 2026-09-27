import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

const _slots = <(String, String, String, Color, Color)>[
  ('breakfast', 'Breakfast', '08:30', AppColors.secondary, AppColors.secondaryFixed),
  ('lunch', 'Lunch', '12:45', AppColors.tertiary, AppColors.surfaceContainerHigh),
  ('dinner', 'Dinner', '19:30', AppColors.primary, AppColors.primaryFixed),
  ('snack', 'Snack & Fuel', '16:15', AppColors.secondary, AppColors.secondaryFixedDim),
];

class MealPlannerScreen extends StatefulWidget {
  const MealPlannerScreen({super.key});
  @override
  State<MealPlannerScreen> createState() => _MealPlannerScreenState();
}

class _MealPlannerScreenState extends State<MealPlannerScreen> {
  late DateTime _week = weekStart(DateTime.now());
  late DateTime _day = dayStart(DateTime.now());
  List<Rec> _meals = [];
  List<Rec> _items = [];
  bool _loading = true;
  bool _filling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (_items.isEmpty) _items = await Repo.foodItems();
      _meals = await Repo.mealsBetween(_week, _week.add(const Duration(days: 6)));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<Rec> _mealsFor(DateTime d, String type) => _meals.where((m) => m['meal_date'] == isoDate(d) && m['meal_type'] == type).toList();

  String _fmtTime(String? t) {
    if (t == null) return '';
    final p = t.split(':');
    return DateFormat('h:mm a').format(DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1])));
  }

  Future<Rec?> _pickItem(String type) => showVSheet<Rec>(context, builder: (ctx) {
        final options = _items.where((i) => List<String>.from(i['meal_types'] ?? const []).contains(type)).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Choose a ${_slots.firstWhere((s) => s.$1 == type).$2.toLowerCase()}', style: T.headlineMd),
          const SizedBox(height: Sp.sm),
          for (final i in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VCard(
                color: AppColors.surfaceContainerLow,
                radius: Rad.md,
                padding: const EdgeInsets.all(12),
                onTap: () => Navigator.pop(ctx, i),
                child: Row(children: [
                  Text(i['emoji'] ?? '🍽️', style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(i['name'], style: T.labelLg),
                      Text('${i['source'] ?? ''} • ${i['kcal']} kcal', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]);
      });

  Future<void> _plan(String type, {Rec? replace}) async {
    final item = await _pickItem(type);
    if (item == null) return;
    if (replace != null) await Repo.deleteMeal(replace['id']);
    await Repo.addMealFromItem(item, type, status: 'planned', date: _day, plannedTime: _slots.firstWhere((s) => s.$1 == type).$3);
    _load();
  }

  Future<void> _more(Rec m) async {
    final action = await showVSheet<String>(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(m['name'], style: T.headlineSm),
          const SizedBox(height: Sp.md),
          if (m['status'] == 'planned') SoftButton('Mark as eaten', icon: Symbols.check_circle, iconColor: AppColors.tertiary, onTap: () => Navigator.pop(ctx, 'eat')),
          const SizedBox(height: 8),
          SoftButton('Swap meal', icon: Symbols.swap_horiz, iconColor: AppColors.primary, onTap: () => Navigator.pop(ctx, 'swap')),
          const SizedBox(height: 8),
          SoftButton('Remove', icon: Symbols.delete, iconColor: AppColors.error, onTap: () => Navigator.pop(ctx, 'delete')),
        ]));
    if (action == 'eat') await Repo.confirmMeal(m);
    if (action == 'swap') return _plan(m['meal_type'], replace: m);
    if (action == 'delete') await Repo.deleteMeal(m['id']);
    _load();
  }

  Future<void> _smartFill({bool wholeWeek = false}) async {
    setState(() => _filling = true);
    final rnd = math.Random(_day.day + _day.month * 31);
    try {
      final days = wholeWeek ? [for (int i = 0; i < 7; i++) _week.add(Duration(days: i))].where((d) => !d.isBefore(dayStart(DateTime.now()))).toList() : [_day];
      int added = 0;
      for (final d in days) {
        for (final s in _slots) {
          if (_mealsFor(d, s.$1).isNotEmpty) continue;
          final opts = _items.where((i) => List<String>.from(i['meal_types'] ?? const []).contains(s.$1)).toList();
          if (opts.isEmpty) continue;
          await Repo.addMealFromItem(opts[rnd.nextInt(opts.length)], s.$1, status: 'planned', date: d, plannedTime: s.$3);
          added++;
        }
      }
      await _load();
      if (mounted) toast(context, added == 0 ? 'Every slot is already planned 🌿' : 'Planned $added balanced meal${added == 1 ? '' : 's'} for you');
    } catch (_) {
      if (mounted) toast(context, 'Could not fill slots right now.', error: true);
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = [for (int i = 0; i < 7; i++) _week.add(Duration(days: i))];
    final weekNo = weekOfYear(_week);
    final special = _items.where((i) => i['category'] == 'Dining Hall').toList();
    final pick = special.isEmpty ? null : special[(_week.day + weekNo) % special.length];
    final pickDay = _week.add(Duration(days: (weekNo % 5) + 1));

    return VPage(
      header: const MainHeader('Vitalu   Diet & Nutrition'),
      nav: NavTab.diet,
      onRefresh: _load,
      bottom: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.margin),
            child: Pressable(
              onTap: _filling ? null : () => _smartFill(),
              child: Container(
                height: 52,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(Rad.full), boxShadow: const [BoxShadow(color: Color(0x5C5B3CDD), blurRadius: 36, offset: Offset(0, 16), spreadRadius: -6)]),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _filling
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Symbols.auto_awesome, color: AppColors.tertiaryFixed, size: 22),
                  const SizedBox(width: 8),
                  Text('Smart Fill Open Slots', style: T.labelLg.c(AppColors.onPrimary)),
                ]),
              ),
            ),
          ),
        ),
      ),
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainerLowest, fg: AppColors.onSurface, shadow: Shadows.soft, onTap: () => goBack(context, '/diet')),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Meal Planner', style: T.headlineSm.lh(1.2)),
              Text('Stress-free campus fueling', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          Pressable(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime.now().subtract(const Duration(days: 60)), lastDate: DateTime.now().add(const Duration(days: 60)));
              if (d != null) {
                setState(() {
                  _day = dayStart(d);
                  _week = weekStart(d);
                  _loading = true;
                });
                _load();
              }
            },
            child: TagPill('${DateFormat('MMM d').format(days.first)}–${DateFormat('d').format(days.last)} • Wk $weekNo', icon: Symbols.calendar_month, iconColor: AppColors.primary),
          ),
        ]),
        VCard(
          color: AppColors.surfaceContainerLow,
          padding: EdgeInsets.zero,
          clip: true,
          shadow: Shadows.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(fit: StackFit.expand, children: [
                const AssetImg('bento_planner'),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [AppColors.surfaceContainerLow, Color(0x33F7F1FF), Colors.transparent]),
                  ),
                ),
                Positioned(top: 12, right: 12, child: TagPill('Campus Fresh', icon: Symbols.check_circle, iconColor: AppColors.tertiary, bg: AppColors.surfaceContainerLowest.withValues(alpha: 0.9), fg: AppColors.onSurface)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, Sp.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('SANCTUARY ROUTINE', style: T.labelMd.c(AppColors.tertiary).tracking(1)),
                ]),
                const SizedBox(height: 6),
                Text('Plan around lectures, canteen specials, and easy hostel prep. Flexible routines built for steady focus, never restriction.', style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.6)),
              ]),
            ),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Weekly Flow', style: T.headlineSm)),
            Text('${DateFormat('EEEE').format(_day)} Active', style: T.labelSm.c(AppColors.primary)),
          ]),
          const SizedBox(height: 8),
        ]),
        FullBleed(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(Sp.margin, 4, Sp.margin, 8),
            child: Row(children: [
              for (final d in days) ...[
                Pressable(
                  onTap: () => setState(() => _day = d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 56,
                    height: 72,
                    decoration: BoxDecoration(
                      color: d == _day ? AppColors.primary : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(Rad.lg),
                      boxShadow: d == _day ? Shadows.tinted(AppColors.primary, opacity: 0.28, blur: 20, y: 8, spread: 0) : Shadows.tiny,
                    ),
                    child: Stack(children: [
                      if (_meals.any((m) => m['meal_date'] == isoDate(d)))
                        Positioned(top: 8, right: 8, child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.secondaryContainer, shape: BoxShape.circle))),
                      Center(
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(DateFormat('EEE').format(d), style: T.labelSm.c(d == _day ? AppColors.primaryFixed : AppColors.onSurfaceVariant)),
                          Text('${d.day}', style: T.headlineSm.c(d == _day ? AppColors.onPrimary : AppColors.onSurface)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ]),
          ),
        ),
        if (_loading) const Loading() else ...[for (final s in _slots) _slotCard(s)],
        if (pick != null)
          VCard(
            color: AppColors.surfaceContainerHigh,
            shadow: Shadows.soft,
            child: Row(children: [
              IconCircle(Symbols.sync, size: 40, iconSize: 20, shadow: Shadows.tiny),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('CAMPUS DINING SYNC', style: T.labelSm.c(AppColors.primary).tracking(0.8)),
                  const SizedBox(height: 2),
                  Text('${pick['source']} serves ${pick['name']} — try it on ${DateFormat('EEEE').format(pickDay)}!', style: T.bodySm.medium.lh(1.3)),
                ]),
              ),
              const SizedBox(width: 8),
              PrimaryButton('Quick Plan', color: AppColors.inverseSurface, fg: AppColors.inverseOnSurface, height: 38, expand: false, textStyle: T.labelMd, onTap: () => _smartFill(wholeWeek: true)),
            ]),
          ),
      ],
    );
  }

  Widget _slotCard((String, String, String, Color, Color) s) {
    final list = _mealsFor(_day, s.$1);
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Sp.sm),
        child: VCard(
          color: AppColors.surfaceContainerLow,
          shadow: Shadows.tiny,
          onTap: () => _plan(s.$1),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconCircle(Symbols.add, size: 40, iconSize: 20, shadow: Shadows.tiny),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${s.$2.toUpperCase()} • OPEN SLOT', style: T.labelSm.c(AppColors.primary)),
                  Text(s.$1 == 'dinner' ? 'What are you craving tonight?' : 'Add something nourishing', style: T.headlineSm),
                ]),
              ),
              const Icon(Symbols.chevron_right, color: AppColors.outline, size: 20),
            ]),
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Text('Tap to pick canteen specials or quick 15-minute hostel recipes.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ),
          ]),
        ),
      );
    }
    return Column(children: [
      for (final m in list)
        Padding(
          padding: const EdgeInsets.only(bottom: Sp.sm),
          child: VCard(
            shadow: Shadows.soft,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: s.$5, shape: BoxShape.circle, boxShadow: Shadows.tiny),
                child: Text(_items.where((i) => i['id'] == m['food_item_id']).firstOrNull?['emoji'] ?? '🍽️', style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(s.$2.toUpperCase(), style: T.labelSm.c(s.$4)),
                    if (m['planned_time'] != null) ...[
                      Text('  •  ', style: T.labelSm.c(AppColors.outlineVariant)),
                      Text(_fmtTime(m['planned_time']), style: T.labelSm.c(AppColors.onSurfaceVariant)),
                    ],
                  ]),
                  Text(m['name'], style: T.headlineSm, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    if (m['source'] != null) TagPill(m['source']),
                    TagPill('${m['kcal']} kcal', bg: AppColors.primaryFixed, fg: AppColors.onPrimaryFixedVariant),
                    if (m['status'] == 'logged') TagPill('Eaten', icon: Symbols.check, bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixed),
                  ]),
                ]),
              ),
              if (m['status'] == 'planned' && s.$1 == 'breakfast')
                CircleButton(Symbols.check, size: 36, iconSize: 20, bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixed, onTap: () async {
                  await Repo.confirmMeal(m);
                  _load();
                })
              else if (s.$1 == 'lunch')
                CircleButton(Symbols.swap_horiz, size: 36, iconSize: 18, bg: AppColors.surfaceContainer, onTap: () => _plan('lunch', replace: m))
              else
                CircleButton(Symbols.more_vert, size: 36, iconSize: 18, bg: AppColors.surfaceContainer, onTap: () => _more(m)),
            ]),
          ),
        ),
    ]);
  }
}
