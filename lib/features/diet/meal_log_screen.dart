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
  ('breakfast', 'Breakfast', Symbols.wb_twilight_rounded),
  ('lunch', 'Lunch', Symbols.wb_sunny_rounded),
  ('dinner', 'Dinner', Symbols.dark_mode_rounded),
  ('snack', 'Snack', Symbols.cookie_rounded),
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
            const SizedBox(height: Sp.md),
            VTextField(controller: name, hint: 'e.g. Rice & curry with dhal', icon: Symbols.restaurant_rounded),
            const SizedBox(height: Sp.sm),
            VTextField(controller: kcal, hint: 'Approx. calories (optional)', icon: Symbols.bolt_rounded, keyboard: TextInputType.number),
            const SizedBox(height: Sp.md),
            Text('Food groups in this meal', style: T.labelLg),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final g in foodGroups) VChip(g.label, icon: g.icon, selected: groups.contains(g.key), selectedColor: AppColors.nutrition, onTap: () => set(() => groups.contains(g.key) ? groups.remove(g.key) : groups.add(g.key))),
            ]),
            const SizedBox(height: Sp.md),
            PrimaryButton('Add', onTap: () {
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
        toast(context, '${_tray.length} food${_tray.length == 1 ? '' : 's'} logged for ${_tabs.firstWhere((t) => t.$1 == _type).$2.toLowerCase()}');
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
    final filtered = _items.where((i) {
      if (_cat != 'All' && i['category'] != _cat) return false;
      if (_q.isNotEmpty && !(i['name'] as String).toLowerCase().contains(_q.toLowerCase())) return false;
      if (_q.isEmpty && _cat == 'All' && !(List<String>.from(i['meal_types'] ?? const [])).contains(_type)) return false;
      return true;
    }).toList();

    return VPage(
      header: TitleHeader('Log a meal', onLeading: () => goBack(context, '/diet')),
      bottom: _tray.isEmpty ? null : _trayBar(),
      children: [
        SizedBox(
          width: double.infinity,
          child: Segmented(small: false, options: [for (final t in _tabs) t.$2], value: _tabs.firstWhere((t) => t.$1 == _type).$2, onChanged: (v) => setState(() => _type = _tabs.firstWhere((t) => t.$2 == v).$1)),
        ),
        Row(children: [
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              style: T.bodyLg,
              decoration: InputDecoration(
                prefixIcon: Icon(Symbols.search_rounded, color: AppColors.onSurfaceVariant, size: 20),
                hintText: 'Search foods',
              ),
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
        FullBleed(
          child: ChipRow(children: [
            for (final c in const ['All', 'Dining Hall', 'Dorm Quick-Fix', 'Grab & Go'])
              VChip(c == 'Dining Hall' ? 'Canteen' : (c == 'Dorm Quick-Fix' ? 'Hostel' : c), selected: _cat == c, onTap: () => setState(() => _cat = c)),
          ]),
        ),
        if (_loading)
          const Loading()
        else if (filtered.isEmpty)
          Text('No matches. Add it as a custom food.', style: T.bodyMd.c(AppColors.onSurfaceVariant))
        else
          ListGroup(children: [for (final i in filtered) _foodRow(i)]),
        SoftButton('Custom food', icon: Symbols.add_rounded, onTap: _custom),
        const PrivacyNote('Photos are analysed to estimate food groups and energy. Adjust if something looks off.'),
      ],
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
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d['name'], style: T.headlineSm),
                  const SizedBox(height: 2),
                  Text('About ${d['kcal']} kcal', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final g in List<String>.from(d['food_groups'] ?? const []).take(4)) TagPill(groupByKey(g)?.label ?? g, bg: AppColors.tint(AppColors.nutrition), fg: AppColors.nutrition),
                  ]),
                ]),
              ),
              _addButton(d),
            ]),
          ),
      ]),
    );
  }

  Widget _addButton(Rec item) {
    final on = _inTray(item);
    return IconButton(
      tooltip: on ? 'Remove from tray' : 'Add to tray',
      onPressed: () => _toggle(item),
      icon: Icon(on ? Symbols.check_circle_rounded : Symbols.add_circle_rounded, size: 28, fill: on ? 1 : 0, color: on ? AppColors.primary : AppColors.onSurfaceVariant),
    );
  }

  Widget _foodRow(Rec i) => ListRow(
        icon: iconByName(i['icon']),
        color: AppColors.nutrition,
        title: i['name'],
        subtitle: '${i['kcal']} kcal${i['source'] != null ? ' · ${i['source']}' : ''}',
        trailing: _addButton(i),
        onTap: () => _toggle(i),
      );

  Widget _trayBar() {
    final kcal = _tray.fold<int>(0, (a, t) => a + ((t['kcal'] as num?)?.toInt() ?? 0));
    final label = _tabs.firstWhere((t) => t.$1 == _type).$2;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('${_tray.length} ${_tray.length == 1 ? 'food' : 'foods'} selected', style: T.labelLg.semi),
          Text('About $kcal kcal', style: T.bodySm.c(AppColors.onSurfaceVariant)),
        ]),
      ),
      PrimaryButton('Log ${label.toLowerCase()}', expand: false, loading: _saving, onTap: _logTray),
    ]);
  }
}
