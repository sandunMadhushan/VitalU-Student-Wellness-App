import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

String defaultMealType() {
  final h = DateTime.now().hour;
  if (h < 11) return 'breakfast';
  if (h < 15) return 'lunch';
  if (h < 18) return 'snack';
  return 'dinner';
}

const _tabs = <(String, String, IconData)>[
  ('breakfast', 'Breakfast', Symbols.wb_twilight),
  ('lunch', 'Lunch', Symbols.wb_sunny),
  ('dinner', 'Dinner', Symbols.dark_mode),
  ('snack', 'Snack', Symbols.cookie),
];

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
  bool _loading = true;
  bool _saving = false;
  List<Rec> _items = [];
  final List<Rec> _tray = [];
  Rec? _detected;
  Uint8List? _photo;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _items = await Repo.foodItems();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  bool _inTray(Rec item) => _tray.any((t) => t['id'] == item['id'] && item['id'] != null || identical(t, item));

  void _toggle(Rec item) => setState(() {
        final i = _tray.indexWhere((t) => (item['id'] != null && t['id'] == item['id']) || identical(t, item));
        if (i >= 0) {
          _tray.removeAt(i);
        } else {
          _tray.add(item);
        }
      });

  Future<void> _snap() async {
    final src = await showVSheet<ImageSource>(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Snap your plate', style: T.headlineMd),
          const SizedBox(height: 4),
          Text('VitalU uses AI to estimate the dish, food groups and approximate energy. Always adjust if it looks off.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          SoftButton('Take Photo', icon: Symbols.photo_camera, iconColor: AppColors.secondary, onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          const SizedBox(height: Sp.sm),
          SoftButton('Choose from Gallery', icon: Symbols.image, iconColor: AppColors.primary, onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
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
        setState(() => _detected = {
              'id': null,
              'name': data['name'],
              'source': 'Snapped plate',
              'kcal': (data['kcal'] as num?)?.round() ?? 0,
              'carbs_g': (data['carbs_g'] as num?)?.round() ?? 0,
              'protein_g': (data['protein_g'] as num?)?.round() ?? 0,
              'fat_g': (data['fat_g'] as num?)?.round() ?? 0,
              'food_groups': List<String>.from(data['food_groups'] ?? const []),
              'tags': List<String>.from(data['tags'] ?? const []),
              'icon': 'restaurant',
            });
      } else {
        throw Exception(data is Map ? data['error'] : 'No result');
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not recognise this plate. Add it with “Custom food” instead.', error: true);
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
            const SizedBox(height: Sp.md),
            VTextField(controller: name, hint: 'e.g. Rice & curry with dhal', icon: Symbols.restaurant),
            const SizedBox(height: Sp.sm),
            VTextField(controller: kcal, hint: 'Approx. calories (optional)', icon: Symbols.bolt, keyboard: TextInputType.number),
            const SizedBox(height: Sp.md),
            Text('Food groups in this meal', style: T.labelLg),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in foodGroups) VChip(g.label, icon: g.icon, selected: groups.contains(g.key), selectedColor: AppColors.tertiary, onTap: () => set(() => groups.contains(g.key) ? groups.remove(g.key) : groups.add(g.key))),
            ]),
            const SizedBox(height: Sp.md),
            PrimaryButton('Add to Tray', color: AppColors.tertiary, onTap: () {
              if (name.text.trim().isEmpty) return toast(ctx, 'Give your food a name', error: true);
              _toggle({'id': null, 'name': name.text.trim(), 'source': 'Custom', 'kcal': int.tryParse(kcal.text) ?? 0, 'carbs_g': 0, 'protein_g': 0, 'fat_g': 0, 'food_groups': groups.toList(), 'icon': 'restaurant'});
              Navigator.pop(ctx);
            }),
          ]);
        }));
  }

  Future<void> _logTray() async {
    if (_tray.isEmpty) return;
    setState(() => _saving = true);
    try {
      for (final item in _tray) {
        await Repo.addMealFromItem(item, _type);
      }
      if (mounted) {
        toast(context, '${_tray.length} food${_tray.length == 1 ? '' : 's'} logged for ${_tabs.firstWhere((t) => t.$1 == _type).$2} 🌿');
        setState(() => _tray.clear());
      }
    } catch (_) {
      if (mounted) toast(context, 'Could not log your meal. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hero = _detected ?? _items.where((i) => i['name'] == 'Avocado Harvest Wrap & Sprout Slaw').firstOrNull;
    final filtered = _items.where((i) {
      if (_cat != 'All' && i['category'] != _cat) return false;
      if (_q.isNotEmpty && !(i['name'] as String).toLowerCase().contains(_q.toLowerCase())) return false;
      if (_q.isEmpty && _cat == 'All' && !(List<String>.from(i['meal_types'] ?? const [])).contains(_type)) return false;
      return true;
    }).toList();

    return VPage(
      header: const MainHeader('VitalU Diet & Nutrition'),
      nav: NavTab.diet,
      bottom: _tray.isEmpty ? null : _trayBar(),
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainer, fg: AppColors.onSurface, shadow: Shadows.tiny, onTap: () => goBack(context, '/diet')),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Log a Meal', style: T.headlineSm.lh(1.2)),
              Text('Mindful Campus Fueling', style: T.labelSm.c(AppColors.outline)),
            ]),
          ),
          TagPill('Private Log', icon: Symbols.lock, iconColor: AppColors.tertiary, bg: AppColors.surfaceContainerLow),
        ]),
        Text('Nourish your body between lectures. Quick-search canteen favourites, hostel snacks, or snap your plate for effortless tracking.', style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.4)),
        FullBleed(
          child: ChipRow(children: [
            for (final t in _tabs)
              VChip(t.$2, icon: t.$3, selected: _type == t.$1, color: AppColors.surfaceContainerHigh, height: 40, onTap: () => setState(() => _type = t.$1)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(Rad.full), boxShadow: Shadows.tiny),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  style: T.bodyMd,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    prefixIcon: Icon(Symbols.search, color: AppColors.outline, size: 20),
                    hintText: 'Search canteen menus, snacks...',
                    hintStyle: T.bodyMd.c(AppColors.outline),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Pressable(
              onTap: _snap,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: AppColors.secondaryFixed, borderRadius: BorderRadius.circular(Rad.full), boxShadow: Shadows.tiny),
                child: Row(children: [
                  Icon(Symbols.photo_camera, size: 20, color: AppColors.onSecondaryFixed, fill: 1),
                  const SizedBox(width: 6),
                  Text('Snap', style: T.labelMd.c(AppColors.onSecondaryFixed)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          TagPill('Tip: Snap your plate for automatic food-group notes', icon: Symbols.auto_awesome, bg: AppColors.surfaceContainerLow, fg: AppColors.primary),
        ]),
        if (hero != null || _analyzing) _heroCard(hero),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Frequently Added on Campus', style: T.headlineSm)),
            GestureDetector(onTap: () => setState(() => _cat = 'All'), child: Text('See Full Menu', style: T.labelSm.c(AppColors.primary))),
          ]),
          const SizedBox(height: Sp.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final c in const ['All', 'Dining Hall', 'Dorm Quick-Fix', 'Grab & Go']) ...[
                VChip(c == 'Dining Hall' ? 'Canteen' : (c == 'Dorm Quick-Fix' ? 'Hostel Quick-Fix' : c),
                    selected: _cat == c, selectedColor: AppColors.onSurface, selectedFg: AppColors.surface, color: AppColors.surfaceContainerHigh, height: 32, onTap: () => setState(() => _cat = c)),
                const SizedBox(width: 8),
              ],
            ]),
          ),
          const SizedBox(height: Sp.sm),
          if (_loading) const Loading(),
          for (final i in filtered) Padding(padding: const EdgeInsets.only(bottom: 10), child: _foodCard(i)),
          if (!_loading && filtered.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text('No matches — add it as a custom food.', style: T.bodySm.c(AppColors.onSurfaceVariant))),
          SoftButton('Custom food', icon: Symbols.add_circle, iconColor: AppColors.primary, onTap: _custom),
        ]),
      ],
    );
  }

  Widget _heroCard(Rec? hero) => VCard(
        padding: const EdgeInsets.all(14),
        shadow: Shadows.tiny,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 176,
              child: Stack(fit: StackFit.expand, children: [
                _photo != null ? Image.memory(_photo!, fit: BoxFit.cover) : const AssetImg('meal_wrap'),
                if (_analyzing) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
                Positioned(
                  top: 10,
                  left: 10,
                  child: TagPill(_analyzing ? 'Analysing plate…' : (_detected != null ? 'Auto-detected Plate' : "Today's Canteen Pick"),
                      icon: Symbols.check_circle, iconColor: AppColors.tertiary, bg: AppColors.surface.withValues(alpha: 0.9), fg: AppColors.onSurface),
                ),
                if (hero != null)
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Pill(color: AppColors.inverseSurface.withValues(alpha: 0.85), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: Text('${hero['kcal']} kcal • ${hero['source'] ?? ''}', style: T.labelSm.s(11).c(AppColors.inverseOnSurface))),
                  ),
              ]),
            ),
          ),
          if (hero != null) ...[
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(hero['name'], style: T.headlineSm),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final (i, g) in List<String>.from(hero['food_groups'] ?? const []).take(3).indexed)
                      TagPill(groupByKey(g)?.label ?? g, bg: [AppColors.tertiaryFixed, AppColors.secondaryFixed, AppColors.surfaceContainer][i], fg: [AppColors.onTertiaryFixed, AppColors.onSecondaryFixed, AppColors.onSurfaceVariant][i]),
                  ]),
                ]),
              ),
              CircleButton(_inTray(hero) ? Symbols.check : Symbols.add, size: 36, iconSize: 20, bg: _inTray(hero) ? AppColors.primary : AppColors.tertiary, fg: Colors.white, onTap: () => _toggle(hero)),
            ]),
          ],
        ]),
      );

  Widget _foodCard(Rec i) {
    final on = _inTray(i);
    return Pressable(
      onTap: () => _toggle(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: on ? AppColors.surfaceContainerLow : AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(Rad.r2xl), boxShadow: Shadows.tiny),
        child: Row(children: [
          IconCircle(iconByName(i['icon']), bg: on ? AppColors.primaryFixed : AppColors.surfaceContainerLow),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i['name'], style: T.headlineSm.s(15), overflow: TextOverflow.ellipsis),
              Text('${i['source'] ?? ''} • ${i['description'] ?? ''}', style: T.bodySm.c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Pill(
                  color: on ? AppColors.primaryFixed : AppColors.tertiaryFixed,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(on ? 'Added to Tray' : (i['tag'] ?? '${i['kcal']} kcal'), style: T.labelSm.s(10).c(on ? AppColors.onPrimaryFixed : AppColors.onTertiaryFixed)),
                ),
                const SizedBox(width: 6),
                Text('${i['kcal']} kcal', style: T.labelSm.s(10).c(AppColors.outline)),
              ]),
            ]),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: on ? AppColors.primary : AppColors.surfaceContainerHigh, shape: BoxShape.circle),
            child: Icon(on ? Symbols.check : Symbols.add, size: 20, color: on ? AppColors.onPrimary : AppColors.onSurfaceVariant),
          ),
        ]),
      ),
    );
  }

  Widget _trayBar() {
    final emojis = _tray.map((t) => (t['emoji'] as String?) ?? '🍽️').take(3).toList();
    final kcal = _tray.fold<int>(0, (a, t) => a + ((t['kcal'] as num?)?.toInt() ?? 0));
    final label = _tabs.firstWhere((t) => t.$1 == _type).$2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Sp.margin),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLowest.withValues(alpha: 0.97), borderRadius: BorderRadius.circular(Rad.full), boxShadow: Shadows.floating),
        child: Row(children: [
          SizedBox(
            width: 20.0 * emojis.length + 8,
            height: 28,
            child: Stack(children: [
              for (int i = 0; i < emojis.length; i++)
                Positioned(
                  left: i * 20.0,
                  child: Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: [AppColors.primaryFixed, AppColors.secondaryFixed, AppColors.tertiaryFixed][i], shape: BoxShape.circle, boxShadow: Shadows.tiny),
                    child: Text(emojis[i], style: const TextStyle(fontSize: 12)),
                  ),
                ),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${_tray.length} food${_tray.length == 1 ? '' : 's'} in tray', style: T.labelMd),
              Text('~$kcal kcal • ${AppState.instance.profile == null ? '' : 'Balanced study nourishment'}', style: T.bodySm.s(11).c(AppColors.tertiary).medium, overflow: TextOverflow.ellipsis),
            ]),
          ),
          PrimaryButton('Log $label', icon: Symbols.arrow_forward, color: AppColors.onSurface, fg: AppColors.surface, height: 44, expand: false, loading: _saving, textStyle: T.labelMd, onTap: _logTray),
        ]),
      ),
    );
  }
}
