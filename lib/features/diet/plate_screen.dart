import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../tools/tool_widgets.dart';
import 'diet_science.dart' show diversityByDay;

/// One part of the healthy plate, with its hand-portion guide.
class _Section {
  const _Section(this.key, this.tab, this.title, this.share, this.hand, this.handImage, this.handText, this.why, this.examples, this.groups, this.color);
  final String key;
  final String tab;
  final String title;
  final String share;
  final String hand;
  final String handImage;
  final String handText;
  final String why;
  final List<String> examples;

  /// Dietary diversity groups that count toward this part today. Fats have
  /// none: oils and fats are not a dietary diversity group.
  final Set<String> groups;
  final Color Function() color;
}

final _sections = [
  _Section(
    'veg',
    'Vegetables',
    'Vegetables and greens',
    'Half the plate',
    'Two cupped hands',
    'hand_cupped',
    'Fill both cupped hands with vegetables at lunch and at dinner.',
    'Vegetables and leafy greens bring fibre, vitamins and minerals for very few calories. They keep you full and your energy steady through afternoon lectures.',
    ['Gotukola or mukunuwenna mallung', 'Bean, cabbage or carrot curry', 'Brinjal moju or wambatu curry', 'Cucumber and tomato salad', 'Pumpkin or ash plantain curry'],
    {'dark_leafy', 'other_veg'},
    () => AppColors.nutrition,
  ),
  _Section(
    'grains',
    'Grains',
    'Rice and other starches',
    'A quarter of the plate',
    'One fist',
    'hand_fist',
    'A portion of cooked rice, noodles or roti is about the size of your closed fist.',
    'Rice, roti, hoppers and bread are your main energy source. Choose whole grains like red rice, kurakkan or atta roti more often: they release energy slowly and add fibre.',
    ['Red or brown rice', 'String hoppers (about 5)', 'Kurakkan or atta roti', 'Boiled manioc or sweet potato', 'Pittu or oats'],
    {'cereals', 'starchy'},
    () => AppColors.body,
  ),
  _Section(
    'protein',
    'Protein',
    'Protein foods',
    'A quarter of the plate',
    'One palm',
    'hand_palm',
    'A portion of fish, chicken or meat is about the size and thickness of your palm. For dhal, that is about half a cup.',
    'Protein keeps you full for longer and repairs muscle. Fish, eggs, chicken, dhal, chickpeas and soya are all good choices; mix plant and animal sources across the week.',
    ['Dhal curry (parippu)', 'Fish or sprats curry', 'Boiled egg or egg curry', 'Chicken curry', 'Chickpeas, green gram or soya'],
    {'pulses', 'meat', 'fish', 'eggs'},
    () => AppColors.heart,
  ),
  _Section(
    'fruit',
    'Fruit',
    'Whole fruit',
    'Two a day, on the side',
    'One fist',
    'hand_fist',
    'One serving is a medium fruit, or a fist-sized portion of cut fruit. Aim for two servings a day.',
    'Fruit brings vitamin C, fibre and natural sweetness. Whole fresh fruit is always a good choice, so enjoy it freely between meals or after lunch. Choose whole fruit over juice.',
    ['Banana', 'Papaya', 'Guava', 'Mango', 'Pineapple', 'Orange or mandarin', 'Wood apple'],
    {'fruits'},
    () => AppColors.activity,
  ),
  _Section(
    'dairy',
    'Dairy',
    'Milk, curd and yoghurt',
    'Once or twice a day',
    'One fist',
    'hand_fist',
    'One serving is a glass of milk (200 ml) or a small cup of curd or yoghurt (about 100 g).',
    'Dairy gives calcium for strong bones and good-quality protein. Plain curd or yoghurt is a great dessert; choose low-fat milk when you can.',
    ['A glass of milk', 'Curd (meekiri)', 'Plain yoghurt', 'Milk tea with little sugar'],
    {'dairy'},
    () => AppColors.water,
  ),
  _Section(
    'fats',
    'Fats',
    'Oils, coconut, nuts and seeds',
    'A little at each meal',
    'One thumb',
    'hand_thumb',
    'A portion of oil, butter or scraped coconut is about the size of your thumb, about 1 tablespoon.',
    'A little fat helps your body absorb vitamins A, D, E and K. Cook with a thumb of oil, enjoy a few peanuts or sesame seeds, and keep deep-fried foods for now and then.',
    ['A tablespoon of coconut or gingelly oil', 'Scraped coconut in mallung', 'Peanuts or cashews', 'Sesame (thala) seeds'],
    <String>{},
    () => AppColors.warning,
  ),
];

class PlateScreen extends StatefulWidget {
  const PlateScreen({super.key});
  @override
  State<PlateScreen> createState() => _PlateScreenState();
}

class _PlateScreenState extends State<PlateScreen> {
  _Section _sel = _sections.first;
  Set<String> _today = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      _today = diversityByDay(await Repo.diversityBetween(now, now))[isoDate(now)] ?? {};
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _sel.color();
    final hit = _sel.groups.intersection(_today);
    return VPage(
      header: TitleHeader('Healthy plate', onLeading: () => goBack(context, '/diet')),
      bottom: PrimaryButton('Log a meal', leadingIcon: Symbols.add_rounded, color: AppColors.nutrition, onTap: () async {
        await context.push('/diet/log');
        _load();
      }),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Rad.xl),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset('assets/plate/plate_hero.webp', fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54], stops: [0.45, 1])),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Build a balanced plate', style: T.headlineMd.c(Colors.white)),
                  Text('Half vegetables, a quarter grains, a quarter protein. No scale needed.', style: T.bodySm.c(Colors.white.withValues(alpha: 0.9))),
                ]),
              ),
            ]),
          ),
        ),
        VCard(
          child: Column(children: [
            Text('Tap a part of the plate', style: T.labelMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: 8),
            AnimatedPlate(selected: _sel.key, onSelect: (k) => setState(() => _sel = _sections.firstWhere((s) => s.key == k))),
            const SizedBox(height: Sp.md),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              for (final s in _sections) VChip(s.tab, dense: true, selected: s.key == _sel.key, selectedColor: s.color(), onTap: () => setState(() => _sel = s)),
            ]),
          ]),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a), child: child)),
          child: Column(key: ValueKey(_sel.key), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            VCard(
              padding: EdgeInsets.zero,
              clip: true,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Image.asset('assets/plate/${_sel.handImage}.webp', width: 120, height: 150, fit: BoxFit.cover),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CategoryLabel('Hand portion', icon: Symbols.front_hand_rounded, color: c),
                      const SizedBox(height: 4),
                      Text(_sel.hand, style: T.headlineSm),
                      const SizedBox(height: 4),
                      Text(_sel.handText, style: T.bodySm.c(AppColors.onSurfaceVariant)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: Sp.md),
            VCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CategoryLabel(_sel.title, icon: Symbols.restaurant_rounded, color: c, trailing: _sel.share),
                const SizedBox(height: 8),
                Text(_sel.why, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
                const SizedBox(height: Sp.md),
                Text('Sri Lankan examples', style: T.labelLg),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in _sel.examples) TagPill(e, bg: c.withValues(alpha: 0.12), fg: AppColors.onSurface),
                ]),
                if (_sel.groups.isNotEmpty) ...[
                const SizedBox(height: Sp.md),
                Row(children: [
                  Icon(hit.isEmpty ? Symbols.radio_button_unchecked_rounded : Symbols.check_circle_rounded, size: 18, color: hit.isEmpty ? AppColors.outline : c, fill: 1),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(hit.isEmpty ? 'Not in your meal logs yet today' : 'Already on your plate today', style: T.labelMd.c(hit.isEmpty ? AppColors.onSurfaceVariant : c)),
                  ),
                ]),
                ],
              ]),
            ),
          ]),
        ),
        const SectionHeader('Your hand, your portion'),
        Text('Your hand grows with you, so it gives a portion that suits your body size.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.92,
          children: [for (final s in _sections) _handTile(s)],
        ),
        VCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.lightbulb_rounded, size: 22, color: AppColors.warning, fill: 1),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Vegetables first', style: T.headlineSm),
                const SizedBox(height: 4),
                Text('Serve the vegetables and mallung first, then the rice. Filling half the plate with vegetables leaves room for your favourites without an energy dip.',
                    style: T.bodyMd.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        Center(
          child: TextLinkButton('About the healthy plate', leading: Symbols.info_rounded, onTap: () => showInfoSheet(context, title: 'The healthy plate', paragraphs: const [
                'Based on the food-based dietary guidelines for Sri Lanka and the healthy-plate model used internationally: half the plate vegetables, a quarter starchy foods (preferably whole grain), a quarter protein, with fruit, dairy, a little healthy fat and water on the side.',
                'Hand portions are a practical guide, not an exact measure. Students who are very active may need a little more of each part; students aiming to lose weight can keep the grain portion to one fist.',
              ])),
        ),
      ],
    );
  }

  Widget _handTile(_Section s) {
    final c = s.color();
    final on = s.key == _sel.key;
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(Rad.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _sel = s),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Rad.lg), border: Border.all(color: on ? c : AppColors.outlineVariant, width: on ? 2 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: Image.asset('assets/plate/${s.handImage}.webp', fit: BoxFit.cover)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.hand, style: T.labelLg.w(FontWeight.w700)),
                Text(s.tab, style: T.labelSm.c(c)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A realistic plate: food photos fill exact half and quarter sections of a
/// shaded ceramic plate, with fruit, curd and a little fat in side dishes.
/// Parts sweep in when the screen opens; the selected one lifts out and the
/// rest soften. Every part can be tapped.
class AnimatedPlate extends StatefulWidget {
  const AnimatedPlate({super.key, required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;
  @override
  State<AnimatedPlate> createState() => _AnimatedPlateState();
}

class _AnimatedPlateState extends State<AnimatedPlate> with TickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))..forward();

  @override
  void didUpdateWidget(covariant AnimatedPlate old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _intro.dispose();
    _pop.dispose();
    super.dispose();
  }

  static const _plate = 206.0;
  static const _food = 170.0;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _pop]),
      builder: (_, _) {
        final intro = Curves.easeOutCubic.transform(_intro.value);
        final pop = Curves.elasticOut.transform(_pop.value);
        Widget sector(String key, String img, double start, double sweep, int order) {
          final on = widget.selected == key;
          final mid = start + sweep / 2;
          final lift = on ? 9 * pop : 0.0;
          final appear = Curves.easeOutBack.transform(((intro - order * 0.18) / 0.6).clamp(0.0, 1.0));
          return Transform.translate(
            offset: Offset(math.cos(mid) * lift, math.sin(mid) * lift),
            child: Transform.scale(
              scale: 0.6 + 0.4 * appear,
              child: Opacity(
                opacity: appear.clamp(0.0, 1.0),
                child: GestureDetector(
                  onTap: () => widget.onSelect(key),
                  child: ClipPath(
                    clipper: _Sector(start, sweep),
                    child: Stack(fit: StackFit.expand, children: [
                      Image.asset('assets/plate/$img.webp', fit: BoxFit.cover),
                      AnimatedContainer(duration: const Duration(milliseconds: 220), color: Colors.white.withValues(alpha: on ? 0 : 0.42)),
                    ]),
                  ),
                ),
              ),
            ),
          );
        }

        Widget label(String key, double start, double sweep, String text, double reach) {
          final on = widget.selected == key;
          final mid = start + sweep / 2;
          final lift = on ? 9 * pop : 0.0;
          return IgnorePointer(
            child: Opacity(
              opacity: intro.clamp(0.0, 1.0),
              child: Align(
                alignment: Alignment(math.cos(mid) * reach, math.sin(mid) * reach),
                child: Transform.translate(offset: Offset(math.cos(mid) * lift, math.sin(mid) * lift), child: _Label(text, on: on)),
              ),
            ),
          );
        }

        Widget side(String key, String img, String label, double size, {bool cup = false}) {
          final on = widget.selected == key;
          final s = on ? 1 + 0.1 * pop : 1.0;
          return GestureDetector(
            onTap: () => widget.onSelect(key),
            child: Transform.scale(
              scale: s * (0.7 + 0.3 * intro),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _Dish(size: size, cup: cup, dark: dark, child: Stack(fit: StackFit.expand, children: [
                  Image.asset('assets/plate/$img.webp', fit: BoxFit.cover),
                  AnimatedContainer(duration: const Duration(milliseconds: 220), color: Colors.white.withValues(alpha: on ? 0 : 0.42)),
                ])),
                const SizedBox(height: 4),
                Text(label, style: T.labelSm.w(on ? FontWeight.w800 : FontWeight.w600).c(on ? AppColors.onSurface : AppColors.onSurfaceVariant)),
              ]),
            ),
          );
        }

        return SizedBox(
          height: 236,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(
              width: _plate,
              height: _plate,
              child: Stack(alignment: Alignment.center, children: [
                // Ceramic plate: a soft drop shadow, a glazed rim and a recessed well.
                Container(
                  width: _plate,
                  height: _plate,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.35, -0.4),
                      radius: 1.05,
                      colors: dark ? const [Color(0xFF4A4D55), Color(0xFF2C2F35)] : const [Colors.white, Color(0xFFE4E6EA)],
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.5 : 0.16), blurRadius: 22, offset: const Offset(0, 12), spreadRadius: -4),
                      BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
                Container(
                  width: _food + 10,
                  height: _food + 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: dark ? const [Color(0xFF34373D), Color(0xFF26282D)] : const [Color(0xFFF7F8FA), Color(0xFFDCDFE4)],
                      stops: const [0.82, 1],
                    ),
                  ),
                ),
                SizedBox(
                  width: _food,
                  height: _food,
                  child: Stack(fit: StackFit.expand, children: [
                    sector('veg', 'tex_veg', math.pi / 2, math.pi, 0),
                    sector('grains', 'tex_grains', -math.pi / 2, math.pi / 2, 1),
                    sector('protein', 'tex_protein', 0, math.pi / 2, 2),
                    label('veg', math.pi / 2, math.pi, '½ Veg', 0.55),
                    label('grains', -math.pi / 2, math.pi / 2, '¼ Grains', 0.62),
                    label('protein', 0, math.pi / 2, '¼ Protein', 0.62),
                  ]),
                ),
                // Glaze highlight across the rim.
                IgnorePointer(
                  child: Container(
                    width: _plate,
                    height: _plate,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.white.withValues(alpha: dark ? 0.08 : 0.35), Colors.transparent, Colors.transparent],
                        stops: const [0, 0.35, 1],
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 14),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              side('fruit', 'tex_fruit', 'Fruit', 62),
              const SizedBox(height: 6),
              side('dairy', 'tex_dairy', 'Dairy', 52, cup: true),
              const SizedBox(height: 6),
              side('fats', 'tex_fats', 'Fats', 40),
            ]),
          ]),
        );
      },
    );
  }
}

/// A pie slice of the circle, with a small gap between slices.
class _Sector extends CustomClipper<Path> {
  const _Sector(this.start, this.sweep);
  final double start;
  final double sweep;

  @override
  Path getClip(Size size) {
    const gap = 0.03;
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final g = Offset(math.cos(start + sweep / 2), math.sin(start + sweep / 2)) * 2.5;
    return Path()
      ..moveTo(c.dx + g.dx, c.dy + g.dy)
      ..arcTo(Rect.fromCircle(center: c + g, radius: r), start + gap, sweep - 2 * gap, false)
      ..close();
  }

  @override
  bool shouldReclip(covariant _Sector old) => old.start != start || old.sweep != sweep;
}

/// A small ceramic bowl (or cup, with a handle) holding a food photo.
class _Dish extends StatelessWidget {
  const _Dish({required this.size, required this.child, required this.dark, this.cup = false});
  final double size;
  final Widget child;
  final bool dark;
  final bool cup;

  @override
  Widget build(BuildContext context) {
    final rim = size * 0.12;
    final bowl = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(rim),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-0.4, -0.4), colors: dark ? const [Color(0xFF55585F), Color(0xFF2E3136)] : const [Colors.white, Color(0xFFDDE0E5)]),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.45 : 0.14), blurRadius: 10, offset: const Offset(0, 5), spreadRadius: -2)],
      ),
      child: ClipOval(child: child),
    );
    if (!cup) return bowl;
    return SizedBox(
      width: size + 12,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          right: 0,
          top: size * 0.3,
          child: Container(
            width: 16,
            height: size * 0.4,
            decoration: BoxDecoration(border: Border.all(color: dark ? const Color(0xFF55585F) : const Color(0xFFE2E4E8), width: 4), borderRadius: BorderRadius.circular(8)),
          ),
        ),
        bowl,
      ]),
    );
  }
}

/// Section name on the plate, on a frosted pill.
class _Label extends StatelessWidget {
  const _Label(this.text, {required this.on});
  final String text;
  final bool on;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: on ? 0.62 : 0.38), borderRadius: BorderRadius.circular(Rad.full)),
        child: Text(text, style: TextStyle(fontFamily: T.family, fontSize: on ? 12.5 : 11, fontWeight: FontWeight.w800, color: Colors.white)),
      );
}
