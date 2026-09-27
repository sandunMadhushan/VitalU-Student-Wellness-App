import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_symbols_icons/symbols.dart';

import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../tools/tool_widgets.dart';

class DiversityScreen extends StatefulWidget {
  const DiversityScreen({super.key});
  @override
  State<DiversityScreen> createState() => _DiversityScreenState();
}

class _DiversityScreenState extends State<DiversityScreen> {
  bool _loading = true;
  List<Rec> _today = [];
  List<Rec> _week = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      _week = await Repo.diversityBetween(weekStart(now), now);
      _today = _week.where((r) => r['log_date'] == isoDate(now)).toList();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logGroup([FoodGroup? preset]) async {
    FoodGroup? g = preset;
    final food = TextEditingController(text: preset?.suggestion.split('/').first.trim());
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Log a Food Group', style: T.headlineMd),
            const SizedBox(height: Sp.md),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final x in foodGroups) VChip(x.label, icon: x.icon, selected: g?.key == x.key, selectedColor: Color(x.color), onTap: () => set(() => g = x)),
            ]),
            const SizedBox(height: Sp.md),
            VTextField(controller: food, hint: 'What did you eat? e.g. Gotukola sambol', icon: Symbols.restaurant),
            const SizedBox(height: Sp.md),
            PrimaryButton('Add to Today', color: AppColors.inverseSurface, fg: AppColors.inverseOnSurface, onTap: () async {
              if (g == null) return toast(ctx, 'Choose a food group', error: true);
              await Repo.addDiversity(g!.key, food.text.trim().isEmpty ? g!.label : food.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final todayGroups = _today.map((r) => r['food_group'] as String).toSet();
    final missing = foodGroups.where((g) => !todayGroups.contains(g.key)).toList();
    final weekPoints = _week.map((r) => '${r['food_group']}|${(r['food_name'] as String?)?.toLowerCase().trim()}').toSet().length;
    final now = DateTime.now();
    final weekNo = weekOfYear(now);
    // Keep first entry per group for "Today's Spectrum"
    final firstPerGroup = <String, Rec>{};
    for (final r in _today) {
      firstPerGroup.putIfAbsent(r['food_group'], () => r);
    }

    return VPage(
      header: const MainHeader('Vitalu   Diet & Nutrition'),
      nav: NavTab.diet,
      onRefresh: _load,
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, shadow: Shadows.tiny, onTap: () => goBack(context, '/diet')),
          const Spacer(),
          Flexible(
            flex: 6,
            child: Pill(
              color: AppColors.surfaceContainerHigh,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🌸', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Flexible(child: Text('Food Groups & Gut Diversity • Week $weekNo', style: T.labelSm.c(AppColors.primary), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          ),
          const Spacer(),
          CircleButton(Symbols.info, size: 40, iconSize: 20, bg: AppColors.surfaceContainerLow, shadow: Shadows.tiny, onTap: () => showInfoSheet(context, title: 'Dietary diversity', paragraphs: const [
                'Eating from many food groups each day is linked to better micronutrient intake. VitalU tracks 8 groups: whole grains, fruits, leafy greens, healthy fats & seeds, probiotics (curd, yoghurt), nuts & beans, herbs & spices, and eggs/fish/meat.',
                'Aim to include at least 5 groups daily. Weekly points count the different foods you enjoy — variety feeds a healthier gut.',
              ])),
        ]),
        Column(children: [
          Text('Dietary Diversity', style: T.headlineSm),
          const SizedBox(height: 4),
          Text('Nourish your microbiome with a vibrant spectrum of whole foods. Every colourful plant counts towards sustained study focus and vitality.',
              textAlign: TextAlign.center, style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
        ]),
        VCard(
          shadow: Shadows.card,
          child: Column(children: [
            SizedBox(
              width: 256,
              height: 256,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(size: const Size(256, 256), painter: _Flower(todayGroups)),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceContainerLowest, width: 2),
                    boxShadow: Shadows.soft,
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('🌱', style: TextStyle(fontSize: 24)),
                    Text('${todayGroups.length}/8', style: T.headlineSm.c(AppColors.primary).lh(1)),
                    Text('BLOOMED', style: T.labelSm.s(10).c(AppColors.onSurfaceVariant).tracking(1)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 4),
            Text('${todayGroups.length} of 8 food groups today', style: T.headlineSm),
            const SizedBox(height: 4),
            Text(
              todayGroups.length >= 8
                  ? 'All 8 petals bloomed — a beautifully diverse day!'
                  : todayGroups.length >= 5
                      ? 'Wonderful colour variety! Adding ${missing.first.suggestion.split('/').first.trim().toLowerCase()} later will light up another petal.'
                      : 'Every group you add lights a petal. Try ${missing.first.suggestion.toLowerCase()} next.',
              textAlign: TextAlign.center,
              style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.35),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full)),
              child: Row(children: [
                const Icon(Symbols.psychiatry, size: 18, color: AppColors.tertiary),
                const SizedBox(width: 8),
                Expanded(child: Text('Weekly Diversity', style: T.labelMd)),
                Text('$weekPoints / 30', style: T.labelMd.c(AppColors.tertiary).bold),
                const SizedBox(width: 4),
                Text('points', style: T.labelMd.c(AppColors.onSurfaceVariant).w(FontWeight.w400)),
              ]),
            ),
            const SizedBox(height: 8),
            Bar(value: weekPoints / 30, height: 6, color: AppColors.tertiaryFixedDim),
          ]),
        ),
        if (missing.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Missing Today', style: T.headlineSm),
                  Text('Tap to log or discover campus ideas:', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
              TagPill('${missing.length} Left', bg: AppColors.primaryFixed, fg: AppColors.primary),
            ]),
            const SizedBox(height: Sp.sm),
          ]),
        if (missing.isNotEmpty)
          FullBleed(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Sp.margin, vertical: 4),
              child: Row(children: [
                for (final g in missing) ...[
                  Pressable(
                    onTap: () => _logGroup(g),
                    child: Container(
                      width: 240,
                      padding: const EdgeInsets.all(Sp.sm),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(Rad.xl), boxShadow: Shadows.soft),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          IconCircle(g.icon, size: 40, iconSize: 20, bg: Color(g.color).withValues(alpha: 0.15), fg: Color(g.color)),
                          const Spacer(),
                          Flexible(child: TagPill(g.label, upper: true, bg: Color(g.color).withValues(alpha: 0.12), fg: Color(g.color))),
                        ]),
                        const SizedBox(height: 12),
                        Text('+ ${g.suggestion}', style: T.labelLg),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Symbols.storefront, size: 14, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(g.where, style: T.bodySm.s(11).c(AppColors.onSurfaceVariant)),
                        ]),
                      ]),
                    ),
                  ),
                  const SizedBox(width: Sp.sm),
                ],
              ]),
            ),
          ),
        VCard(
          shadow: Shadows.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text("Today's Spectrum", style: T.headlineSm)),
              const Icon(Symbols.check_circle, size: 16, color: AppColors.tertiary),
              const SizedBox(width: 4),
              Text('${todayGroups.length} Colors Active', style: T.labelSm.c(AppColors.tertiary)),
            ]),
            const SizedBox(height: 12),
            if (_loading) const Loading(),
            if (!_loading && firstPerGroup.isEmpty) Text('Nothing logged yet — meals you log add food groups automatically.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            for (final r in firstPerGroup.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.xl)),
                  child: Row(children: [
                    IconCircle(groupByKey(r['food_group'])?.icon ?? Symbols.eco, size: 32, iconSize: 18,
                        bg: Color(groupByKey(r['food_group'])?.color ?? 0xFF006A45).withValues(alpha: 0.15), fg: Color(groupByKey(r['food_group'])?.color ?? 0xFF006A45)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(groupByKey(r['food_group'])?.label ?? r['food_group'], style: T.labelMd),
                        Text(r['food_name'] ?? '', style: T.bodySm.s(12).c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                    Text(DateFormat('h:mm a').format(DateTime.parse(r['logged_at']).toLocal()), style: T.labelSm.c(AppColors.onSurfaceVariant)),
                  ]),
                ),
              ),
          ]),
        ),
        VCard(
          color: AppColors.surfaceContainerHigh,
          shadow: Shadows.tiny,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(Symbols.psychology, size: 36, iconSize: 20, shadow: Shadows.tiny),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Gut Tip for Exam Season', style: T.labelMd),
                const SizedBox(height: 4),
                Text('Eating a wide variety of plants each week feeds beneficial gut microbes, which support digestion, immunity and steady energy for long study days.',
                    style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
              ]),
            ),
          ]),
        ),
        PrimaryButton('Log an Additional Food Group', leadingIcon: Symbols.add, color: AppColors.inverseSurface, fg: AppColors.inverseOnSurface, height: 52, onTap: () => _logGroup()),
        Center(
          child: TextLinkButton('Explore 30-Plant Weekly Challenge', icon: Symbols.arrow_forward, color: AppColors.primary, onTap: () => showInfoSheet(context, title: '30-Plant Weekly Challenge', icon: Symbols.eco, paragraphs: [
                'Try to eat 30 different plant foods in a week — grains, fruits, vegetables, pulses, nuts, seeds, herbs and spices all count.',
                'You have $weekPoints so far this week. Easy wins: add curry leaves, a new fruit from the campus stall, or swap white rice for red rice.',
              ])),
        ),
        const PrivacyNote('Your dietary logs are private to your account.', icon: Symbols.lock),
      ],
    );
  }
}

class _Flower extends CustomPainter {
  _Flower(this.active);
  final Set<String> active;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (int i = 0; i < foodGroups.length; i++) {
      final g = foodGroups[i];
      final ang = -math.pi / 2 + i * 2 * math.pi / foodGroups.length;
      final on = active.contains(g.key);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(ang + math.pi / 2);
      final petal = RRect.fromRectAndRadius(const Rect.fromLTWH(-26, -122, 52, 80), const Radius.circular(26));
      canvas.drawRRect(
          petal,
          Paint()
            ..color = on ? Color(g.color).withValues(alpha: 0.75) : AppColors.surfaceContainerHigh
            ..maskFilter = on ? null : null);
      if (on) {
        canvas.drawRRect(petal.deflate(8), Paint()..color = Colors.white.withValues(alpha: 0.25));
      }
      canvas.restore();
      // icon dot
      final p = c + Offset(math.cos(ang), math.sin(ang)) * 94;
      canvas.drawCircle(p, 13, Paint()..color = Colors.white.withValues(alpha: on ? 0.95 : 0.7));
      final tp = TextPainter(
        text: TextSpan(text: String.fromCharCode(g.icon.codePoint), style: TextStyle(fontFamily: g.icon.fontFamily, package: g.icon.fontPackage, fontSize: 16, color: on ? Color(g.color) : AppColors.outline)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _Flower old) => old.active.length != active.length;
}
