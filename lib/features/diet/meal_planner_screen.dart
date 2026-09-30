import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

const _slots = <(String, String, String, IconData)>[
  ('breakfast', 'Breakfast', '08:30', Symbols.bakery_dining_rounded),
  ('lunch', 'Lunch', '12:45', Symbols.rice_bowl_rounded),
  ('snack', 'Snack', '16:15', Symbols.nutrition_rounded),
  ('dinner', 'Dinner', '19:30', Symbols.skillet_rounded),
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
          Text('Choose ${_slots.firstWhere((s) => s.$1 == type).$2.toLowerCase()}', style: T.headlineMd),
          const SizedBox(height: Sp.md),
          if (options.isEmpty) Text('No suggestions for this meal yet.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          if (options.isNotEmpty)
            ListGroup(children: [
              for (final i in options)
                ListRow(
                  icon: iconByName(i['icon']),
                  color: AppColors.nutrition,
                  title: i['name'],
                  subtitle: '${i['kcal']} kcal${i['source'] != null ? ' · ${i['source']}' : ''}',
                  onTap: () => Navigator.pop(ctx, i),
                ),
            ]),
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
          Text(m['name'], style: T.headlineMd),
          const SizedBox(height: Sp.md),
          ListGroup(children: [
            if (m['status'] == 'planned') ListRow(icon: Symbols.check_circle_rounded, color: AppColors.tertiary, title: 'Mark as eaten', chevron: false, onTap: () => Navigator.pop(ctx, 'eat')),
            ListRow(icon: Symbols.swap_horiz_rounded, color: AppColors.primary, title: 'Swap meal', chevron: false, onTap: () => Navigator.pop(ctx, 'swap')),
            ListRow(icon: Symbols.delete_rounded, title: 'Remove', destructive: true, chevron: false, onTap: () => Navigator.pop(ctx, 'delete')),
          ]),
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
      if (mounted) toast(context, added == 0 ? 'Every slot is already planned.' : 'Planned $added ${added == 1 ? 'meal' : 'meals'}.');
    } catch (_) {
      if (mounted) toast(context, 'Could not fill slots right now.', error: true);
    } finally {
      if (mounted) setState(() => _filling = false);
    }
  }

  Future<void> _pickWeek() async {
    final d = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime.now().subtract(const Duration(days: 60)), lastDate: DateTime.now().add(const Duration(days: 60)));
    if (d != null) {
      setState(() {
        _day = dayStart(d);
        _week = weekStart(d);
        _loading = true;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = [for (int i = 0; i < 7; i++) _week.add(Duration(days: i))];
    final weekNo = weekOfYear(_week);
    final special = _items.where((i) => i['category'] == 'Dining Hall').toList();
    final pick = special.isEmpty ? null : special[(_week.day + weekNo) % special.length];
    final pickDay = _week.add(Duration(days: (weekNo % 5) + 1));
    final today = dayStart(DateTime.now());

    return VPage(
      header: TitleHeader('Meal planner', onLeading: () => goBack(context, '/diet')),
      onRefresh: _load,
      bottom: PrimaryButton('Fill open slots', leadingIcon: Symbols.auto_awesome_rounded, loading: _filling, onTap: () => _smartFill()),
      children: [
        Row(children: [
          Expanded(child: Text(DateFormat('EEEE, d MMMM').format(_day), style: T.headlineSm)),
          TextLinkButton('${DateFormat('d MMM').format(days.first)} – ${DateFormat('d MMM').format(days.last)}', leading: Symbols.calendar_month_rounded, onTap: _pickWeek),
        ]),
        Row(children: [
          for (final d in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: d == _day ? AppColors.primary : AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(Rad.base),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Rad.base),
                    onTap: () => setState(() => _day = d),
                    child: SizedBox(
                      height: 68,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(DateFormat('E').format(d).substring(0, 1), style: T.labelSm.c(d == _day ? AppColors.onPrimary : AppColors.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text('${d.day}', style: T.labelLg.semi.tnum.c(d == _day ? AppColors.onPrimary : (d == today ? AppColors.primary : AppColors.onSurface))),
                        const SizedBox(height: 4),
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _meals.any((m) => m['meal_date'] == isoDate(d)) ? (d == _day ? AppColors.onPrimary : AppColors.nutrition) : Colors.transparent,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
        if (_loading)
          const Loading()
        else
          ListGroup(children: [
            for (final s in _slots) ..._slotRows(s),
          ]),
        if (pick != null)
          VCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Symbols.storefront_rounded, color: AppColors.nutrition, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('This week at the canteen', style: T.headlineSm),
                  const SizedBox(height: 4),
                  Text('${pick['source']} serves ${pick['name']}. Worth planning for ${DateFormat('EEEE').format(pickDay)}.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  TextLinkButton('Plan the rest of the week', onTap: () => _smartFill(wholeWeek: true)),
                ]),
              ),
            ]),
          ),
      ],
    );
  }

  List<Widget> _slotRows((String, String, String, IconData) s) {
    final list = _mealsFor(_day, s.$1);
    if (list.isEmpty) {
      return [
        ListRow(
          icon: s.$4,
          color: AppColors.outline,
          title: s.$2,
          subtitle: 'Nothing planned',
          trailing: Icon(Symbols.add_circle_rounded, color: AppColors.primary),
          onTap: () => _plan(s.$1),
        ),
      ];
    }
    return [
      for (final m in list)
        ListRow(
          icon: s.$4,
          color: AppColors.nutrition,
          title: m['name'],
          subtitle: '${s.$2}${m['planned_time'] != null ? ' · ${_fmtTime(m['planned_time'])}' : ''} · ${m['kcal']} kcal',
          trailing: m['status'] == 'logged'
              ? TagPill('Eaten', bg: AppColors.tertiaryContainer, fg: AppColors.onTertiaryContainer)
              : Icon(Symbols.more_horiz_rounded, color: AppColors.onSurfaceVariant),
          onTap: () => _more(m),
        ),
    ];
  }
}
