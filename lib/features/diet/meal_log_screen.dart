import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/catalog.dart';
import '../../data/food_db.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'diet_science.dart' show mealItems;

String defaultMealType() {
  final h = DateTime.now().hour;
  if (h < 11) return 'breakfast';
  if (h < 15) return 'lunch';
  if (h < 18) return 'snack';
  return 'dinner';
}

const mealTabs = <(String, String, IconData)>[
  ('breakfast', 'Breakfast', Symbols.wb_twilight_rounded),
  ('lunch', 'Lunch', Symbols.wb_sunny_rounded),
  ('dinner', 'Dinner', Symbols.dark_mode_rounded),
  ('snack', 'Snack', Symbols.cookie_rounded),
];

/// Small coloured dots for a food's MDD-W groups.
Widget groupDots(List<String> groups, {double size = 8}) => Row(mainAxisSize: MainAxisSize.min, children: [
      for (final g in groups.take(4))
        if (groupByKey(g) != null)
          Container(
            width: size,
            height: size,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(color: Color(groupByKey(g)!.color), shape: BoxShape.circle),
          ),
    ]);

/// Log a meal from the shared food database: pick foods, set real portions,
/// and log them together. A photo can also be analysed, and anything missing
/// can be added as a custom food.
class MealLogScreen extends StatefulWidget {
  const MealLogScreen({super.key, this.initialType});
  final String? initialType;
  @override
  State<MealLogScreen> createState() => _MealLogScreenState();
}

class _MealLogScreenState extends State<MealLogScreen> {
  late String _type = widget.initialType ?? defaultMealType();
  String _cat = 'All';
  String _q = '';
  bool _saving = false;
  final List<LoggedItem> _tray = [];
  List<String> _recent = [];
  Uint8List? _photo;
  LoggedItem? _detected;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  /// Foods logged most often over the last two weeks, for one-tap re-logging.
  Future<void> _loadRecent() async {
    try {
      final now = DateTime.now();
      final meals = await Repo.mealsBetween(now.subtract(const Duration(days: 14)), now);
      final count = <String, int>{};
      for (final m in meals) {
        for (final i in mealItems(m)) {
          if (foodByName(i.name) != null) count[i.name] = (count[i.name] ?? 0) + 1;
        }
      }
      final names = count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
      if (mounted) setState(() => _recent = names.take(8).toList());
    } catch (_) {}
  }

  int get _total => _tray.fold(0, (a, i) => a + i.kcal);

  Future<void> _pickPortion(Food food) async {
    PortionUnit unit = food.units.first;
    double qty = unit.min;
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          final kcal = (unit.kcalPerUnit * qty).round();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(food.name, style: T.headlineMd),
            const SizedBox(height: 6),
            if (food.groups.isNotEmpty)
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final g in food.groups)
                  if (groupByKey(g) != null) TagPill(groupByKey(g)!.label, bg: Color(groupByKey(g)!.color).withValues(alpha: 0.14), fg: Color(groupByKey(g)!.color)),
              ]),
            const SizedBox(height: Sp.md),
            Text('How much did you have?', style: T.labelLg),
            const SizedBox(height: 8),
            if (food.units.length > 1) ...[
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final u in food.units)
                  VChip(pluralUnit(u.label), selected: u.label == unit.label, selectedColor: AppColors.nutrition, onTap: () => set(() {
                        unit = u;
                        qty = u.min;
                      })),
              ]),
              const SizedBox(height: Sp.md),
            ],
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.outlined(icon: const Icon(Symbols.remove_rounded), onPressed: qty <= unit.min ? null : () => set(() => qty = (qty - unit.step).clamp(unit.min, unit.max))),
              SizedBox(width: 130, child: Center(child: Text(portionLabel(qty, unit.label), style: T.labelLg.semi, textAlign: TextAlign.center))),
              IconButton.outlined(icon: const Icon(Symbols.add_rounded), onPressed: qty >= unit.max ? null : () => set(() => qty = (qty + unit.step).clamp(unit.min, unit.max))),
            ]),
            const SizedBox(height: Sp.md),
            Center(child: MetricValue('$kcal', unit: 'kcal', size: 30)),
            const SizedBox(height: Sp.md),
            PrimaryButton('Add to meal', color: AppColors.nutrition, onTap: () {
              HapticFeedback.selectionClick();
              Navigator.pop(ctx);
              setState(() => _tray.add(LoggedItem.of(food, unit, qty)));
            }),
          ]);
        }));
  }

  Future<void> _snap() async {
    final src = await showVSheet<ImageSource>(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Snap your plate', style: T.headlineMd),
          const SizedBox(height: 4),
          Text('VitalU estimates the dish, food groups and energy from your photo. Adjust it if something looks off.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          SoftButton('Take photo', icon: Symbols.photo_camera_rounded, onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          const SizedBox(height: Sp.sm),
          SoftButton('Choose from gallery', icon: Symbols.image_rounded, onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]));
    if (src == null) return;
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1024, imageQuality: 80);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _photo = bytes;
      _analyzing = true;
      _detected = null;
    });
    try {
      final res = await db.functions.invoke('analyze-meal', body: {'image_base64': base64Encode(bytes), 'mime_type': 'image/jpeg'});
      final data = res.data;
      if (data is Map && data['name'] != null) {
        final groups = {for (final g in List<String>.from(data['food_groups'] ?? const [])) ?legacyGroupKey(g)}.toList();
        setState(() => _detected = LoggedItem('${data['name']}', 1, 'serving', (data['kcal'] as num?)?.round() ?? 0, groups: groups));
      } else {
        throw Exception(data is Map ? data['error'] : 'No result');
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not recognise this plate. Add it as a custom food instead.', error: true);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _custom() async {
    final name = TextEditingController();
    final kcal = TextEditingController();
    final groups = <String>{};
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Custom food', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('For something that is not in the list.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            VTextField(controller: name, hint: 'For example, rice and curry with jackfruit', icon: Symbols.restaurant_rounded),
            const SizedBox(height: Sp.sm),
            VTextField(controller: kcal, hint: 'About how many kcal? (optional)', icon: Symbols.bolt_rounded, keyboard: TextInputType.number),
            const SizedBox(height: Sp.md),
            Text('Food groups in it', style: T.labelLg),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in foodGroups)
                VChip(g.label, selected: groups.contains(g.key), dense: true, selectedColor: Color(g.color), onTap: () => set(() => groups.contains(g.key) ? groups.remove(g.key) : groups.add(g.key))),
            ]),
            const SizedBox(height: Sp.md),
            PrimaryButton('Add to meal', color: AppColors.nutrition, onTap: () {
              if (name.text.trim().isEmpty) return toast(ctx, 'Give your food a name', error: true);
              setState(() => _tray.add(LoggedItem(name.text.trim(), 1, 'serving', int.tryParse(kcal.text) ?? 0, groups: groups.toList())));
              Navigator.pop(ctx);
            }),
          ]);
        }));
  }

  Future<void> _log() async {
    if (_tray.isEmpty) return;
    setState(() => _saving = true);
    try {
      await Repo.logMeal(_type, List.of(_tray), source: _photo != null && _tray.contains(_detected) ? 'Snapped plate' : 'Meal log');
      if (mounted) {
        toast(context, 'Logged ${_tray.length} food${_tray.length == 1 ? '' : 's'} · $_total kcal');
        setState(() {
          _tray.clear();
          _photo = null;
          _detected = null;
        });
        _loadRecent();
      }
    } catch (_) {
      if (mounted) toast(context, 'Could not log your meal. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = mealTabs.firstWhere((t) => t.$1 == _type).$2;
    return VPage(
      header: TitleHeader('Log a meal', onLeading: () => goBack(context, '/diet')),
      bottom: _tray.isEmpty
          ? null
          : Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('$_total kcal', style: T.labelLg.semi),
                  Text('${_tray.length} food${_tray.length == 1 ? '' : 's'} · ${{for (final i in _tray) ...i.groups}.length} food groups', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
              PrimaryButton('Log ${label.toLowerCase()}', expand: false, color: AppColors.nutrition, loading: _saving, onTap: _log),
            ]),
      children: [
        SizedBox(
          width: double.infinity,
          child: Segmented(small: false, options: [for (final t in mealTabs) t.$2], value: label, onChanged: (v) => setState(() => _type = mealTabs.firstWhere((t) => t.$2 == v).$1)),
        ),
        if (_tray.isNotEmpty) ...[
          SectionHeader('Your $label'.toLowerCase().replaceFirst('your', 'Your'), trailing: Text('$_total kcal', style: T.labelLg.semi.c(AppColors.nutrition))),
          ListGroup(children: [for (int i = 0; i < _tray.length; i++) _trayRow(i)]),
        ],
        Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: T.bodyLg,
              decoration: InputDecoration(prefixIcon: Icon(Symbols.search_rounded, color: AppColors.onSurfaceVariant, size: 20), hintText: 'Search foods'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Snap your plate',
            onPressed: _snap,
            style: IconButton.styleFrom(minimumSize: const Size(52, 52), backgroundColor: AppColors.tint(AppColors.nutrition), foregroundColor: AppColors.nutrition, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.base))),
            icon: const Icon(Symbols.photo_camera_rounded),
          ),
        ]),
        if (_photo != null || _analyzing) _snapCard(),
        if (_q.isEmpty && _recent.isNotEmpty) ...[
          const SectionHeader('Your usual foods'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final n in _recent) VChip(n, icon: Symbols.history_rounded, dense: true, onTap: () => _pickPortion(foodByName(n)!)),
          ]),
        ],
        FullBleed(
          child: ChipRow(children: [
            for (final c in ['All', for (final cat in foodDatabase) cat.name]) VChip(c, selected: _cat == c, selectedColor: AppColors.nutrition, onTap: () => setState(() => _cat = c)),
          ]),
        ),
        ..._foodList(),
        SoftButton('Add a custom food', icon: Symbols.add_rounded, onTap: _custom),
        const PrivacyNote('Calorie values are estimates based on common recipes and portions.'),
      ],
    );
  }

  List<Widget> _foodList() {
    if (_q.isEmpty && _cat == 'All') {
      return [
        for (final cat in foodDatabase) ...[
          SectionHeader(cat.name),
          ListGroup(children: [for (final f in cat.foods) _foodRow(f)]),
        ],
      ];
    }
    final results = [
      for (final cat in foodDatabase)
        if (_cat == 'All' || _cat == cat.name)
          for (final f in cat.foods)
            if (_q.isEmpty || f.name.toLowerCase().contains(_q.toLowerCase())) f,
    ];
    if (results.isEmpty) return [Text('No matches. Try another word, or add it as a custom food.', style: T.bodyMd.c(AppColors.onSurfaceVariant))];
    return [ListGroup(children: [for (final f in results) _foodRow(f)])];
  }

  Widget _foodRow(Food f) => InkWell(
        onTap: () => _pickPortion(f),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Sp.md, 12, 8, 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f.name, style: T.bodyLg.w(FontWeight.w600)),
                const SizedBox(height: 3),
                Row(children: [
                  groupDots(f.groups),
                  if (f.groups.isNotEmpty) const SizedBox(width: 4),
                  Text('${f.units.first.kcalPerUnit.round()} kcal per ${f.units.first.label}', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ]),
            ),
            Icon(Symbols.add_circle_rounded, color: AppColors.nutrition, size: 26, fill: 1),
          ]),
        ),
      );

  Widget _trayRow(int i) {
    final item = _tray[i];
    return ListRow(
      title: item.name,
      subtitle: item.portion,
      chevron: false,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${item.kcal} kcal', style: T.labelLg.semi.tnum),
        IconButton(tooltip: 'Remove', icon: const Icon(Symbols.close_rounded, size: 18), onPressed: () => setState(() => _tray.removeAt(i))),
      ]),
    );
  }

  Widget _snapCard() {
    final d = _detected;
    return VCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          height: 180,
          child: Stack(fit: StackFit.expand, children: [
            if (_photo != null) Image.memory(_photo!, fit: BoxFit.cover),
            if (_analyzing)
              Container(
                color: Colors.black45,
                child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text('Analysing your plate…', style: TextStyle(color: Colors.white)),
                ])),
              ),
          ]),
        ),
        if (d != null)
          Padding(
            padding: const EdgeInsets.all(Sp.md),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, style: T.headlineSm),
                  Text('About ${d.kcal} kcal', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  groupDots(d.groups, size: 10),
                ]),
              ),
              SoftButton(_tray.contains(d) ? 'Added' : 'Add', expand: false, icon: _tray.contains(d) ? Symbols.check_rounded : Symbols.add_rounded, onTap: _tray.contains(d) ? null : () => setState(() => _tray.add(d))),
            ]),
          ),
      ]),
    );
  }
}

/// Meal diary: the last two weeks of logged meals, day by day.
class MealDiaryScreen extends StatefulWidget {
  const MealDiaryScreen({super.key});
  @override
  State<MealDiaryScreen> createState() => _MealDiaryScreenState();
}

class _MealDiaryScreenState extends State<MealDiaryScreen> {
  bool _loading = true;
  List<Rec> _meals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      _meals = (await Repo.mealsBetween(now.subtract(const Duration(days: 13)), now)).where((m) => m['status'] == 'logged').toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final byDay = <String, List<Rec>>{};
    for (final m in _meals) {
      byDay.putIfAbsent(m['meal_date'] as String, () => []).add(m);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final target = AppState.instance.profile?.calorieTarget ?? 2100;
    return VPage(
      header: TitleHeader('Meal diary', onLeading: () => goBack(context, '/diet')),
      onRefresh: _load,
      bottom: PrimaryButton('Log a meal', leadingIcon: Symbols.add_rounded, color: AppColors.nutrition, onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MealLogScreen()));
        _load();
      }),
      children: _loading
          ? [const Loading()]
          : days.isEmpty
              ? [const EmptyState(icon: Symbols.menu_book_rounded, title: 'Your diary is empty', text: 'Meals you log appear here, day by day.')]
              : [
                  Text('The last two weeks of meals you logged.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
                  for (final d in days) _day(d, byDay[d]!, target),
                ],
    );
  }

  Widget _day(String date, List<Rec> meals, int target) {
    final day = DateTime.parse(date);
    final kcal = meals.fold<int>(0, (a, m) => a + (m['kcal'] as num).toInt());
    final groups = {for (final m in meals) for (final g in List<String>.from(m['food_groups'] ?? const [])) ?legacyGroupKey(g)};
    final today = isoDate(DateTime.now()) == date;
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(today ? 'Today' : _fmtDay(day), style: T.headlineSm)),
          TagPill('${groups.length}/10 groups', bg: AppColors.tint(groups.length >= 5 ? AppColors.tertiary : AppColors.warning), fg: groups.length >= 5 ? AppColors.tertiary : AppColors.warning),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Text('${Fmt.thousands(kcal)} kcal', style: T.labelLg.tnum),
          const SizedBox(width: 10),
          Expanded(child: Bar(value: kcal / target, height: 6, color: AppColors.nutrition)),
        ]),
        const SizedBox(height: 8),
        for (final m in meals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 76,
                child: Text((m['meal_type'] as String)[0].toUpperCase() + (m['meal_type'] as String).substring(1), style: T.labelMd.c(AppColors.nutrition)),
              ),
              Expanded(child: Text('${m['name']}', style: T.bodySm)),
              const SizedBox(width: 6),
              Text('${m['kcal']} kcal', style: T.labelSm.tnum.c(AppColors.onSurfaceVariant)),
            ]),
          ),
      ]),
    );
  }

  String _fmtDay(DateTime d) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${names[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }
}
