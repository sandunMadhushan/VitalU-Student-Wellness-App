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

  /// MDD-W groups that count toward this part today.
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
    {'dark_leafy', 'vita_veg_fruit', 'other_veg'},
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
    {'grains'},
    () => AppColors.warning,
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
    {'pulses', 'meat_fish', 'eggs', 'nuts_seeds'},
    () => AppColors.heart,
  ),
  _Section(
    'extras',
    'Fats & fruit',
    'Oils, fruit and dairy',
    'On the side',
    'One thumb',
    'hand_thumb',
    'A portion of oil, butter or coconut is about the size of your thumb. Fruit is about one fist, two times a day.',
    'A little fat helps you absorb vitamins, so cook with a thumb-sized amount of oil and go easy on deep-fried foods. Add a fruit and a cup of curd or milk across the day.',
    ['Banana, papaya or guava', 'Mango or pineapple', 'Curd or yoghurt', 'A glass of milk', 'A spoon of scraped coconut'],
    {'dairy', 'other_fruit'},
    () => AppColors.mind,
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
            SizedBox(height: 220, child: Center(child: AnimatedPlate(selected: _sel.key))),
            const SizedBox(height: Sp.md),
            SizedBox(
              width: double.infinity,
              child: Segmented(small: false, options: [for (final s in _sections) s.tab], value: _sel.tab, onChanged: (v) => setState(() => _sel = _sections.firstWhere((s) => s.tab == v))),
            ),
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
                const SizedBox(height: Sp.md),
                Row(children: [
                  Icon(hit.isEmpty ? Symbols.radio_button_unchecked_rounded : Symbols.check_circle_rounded, size: 18, color: hit.isEmpty ? AppColors.outline : c, fill: 1),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(hit.isEmpty ? 'Not in your meal logs yet today' : 'Already on your plate today', style: T.labelMd.c(hit.isEmpty ? AppColors.onSurfaceVariant : c)),
                  ),
                ]),
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
                'Based on the food-based dietary guidelines for Sri Lanka and the healthy-plate model used internationally: half the plate vegetables, a quarter starchy foods (preferably whole grain), a quarter protein, with fruit, a little dairy and water.',
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

/// The plate diagram. Sections sweep in when the screen opens, and the
/// selected part lifts out of the plate.
class AnimatedPlate extends StatefulWidget {
  const AnimatedPlate({super.key, required this.selected});
  final String selected;
  @override
  State<AnimatedPlate> createState() => _AnimatedPlateState();
}

class _AnimatedPlateState extends State<AnimatedPlate> with TickerProviderStateMixin {
  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 380))..forward();

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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge([_intro, _pop]),
        builder: (_, _) => SizedBox(
          width: 280,
          height: 210,
          child: CustomPaint(
            painter: _PlatePainter(
              widget.selected,
              Curves.easeOutCubic.transform(_intro.value),
              Curves.elasticOut.transform(_pop.value),
              AppColors.surfaceContainerHigh,
              AppColors.outlineVariant,
            ),
          ),
        ),
      );
}

class _PlatePainter extends CustomPainter {
  _PlatePainter(this.selected, this.sweep, this.pop, this.rim, this.line);
  final String selected;
  final double sweep;
  final double pop;
  final Color rim;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2 - 6;
    final c = Offset(r + 6, size.height / 2);
    canvas.drawCircle(c + const Offset(0, 4), r, Paint()..color = Colors.black.withValues(alpha: 0.06));
    canvas.drawCircle(c, r, Paint()..color = rim);
    final ri = r - 12;
    const gap = 0.035;

    void part(String key, double start, double extent, Color color, String label) {
      final on = key == selected;
      final mid = start + extent / 2;
      final lift = on ? 8 * pop : 0.0;
      final o = c + Offset(math.cos(mid) * lift, math.sin(mid) * lift);
      final rect = Rect.fromCircle(center: o, radius: ri);
      final paint = Paint()..color = on || selected == 'extras' ? color : color.withValues(alpha: 0.32);
      canvas.drawArc(rect, start + gap, (extent - 2 * gap) * sweep, true, paint);
      if (sweep > 0.8) {
        final tp = TextPainter(
          text: TextSpan(text: label, style: TextStyle(fontFamily: T.family, fontSize: on ? 15 : 13, fontWeight: FontWeight.w700, color: Colors.white)),
          textDirection: TextDirection.ltr,
        )..layout();
        final at = o + Offset(math.cos(mid) * ri * 0.5, math.sin(mid) * ri * 0.5);
        tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
      }
    }

    part('veg', math.pi / 2, math.pi, AppColors.nutrition, '½ veg');
    part('grains', -math.pi / 2, math.pi / 2, AppColors.warning, '¼ grains');
    part('protein', 0, math.pi / 2, AppColors.heart, '¼ protein');

    // Fruit and a cup of curd on the side.
    final on = selected == 'extras';
    final s = on ? 1 + 0.12 * pop : 1.0;
    final side = Offset(c.dx + r + 44, c.dy - 34);
    canvas.drawCircle(side, 26 * s, Paint()..color = rim);
    canvas.drawCircle(side, 19 * s, Paint()..color = on ? AppColors.mind : AppColors.mind.withValues(alpha: 0.32));
    final cup = Offset(c.dx + r + 44, c.dy + 40);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: cup, width: 40 * s, height: 34 * s), const Radius.circular(10)), Paint()..color = rim);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: cup + const Offset(0, -4), width: 30 * s, height: 16 * s), const Radius.circular(8)),
      Paint()..color = on ? Colors.white : Colors.white.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(covariant _PlatePainter old) => old.selected != selected || old.sweep != sweep || old.pop != pop || old.rim != rim;
}
