import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'tool_widgets.dart';

class WhrScreen extends StatefulWidget {
  const WhrScreen({super.key});
  @override
  State<WhrScreen> createState() => _WhrScreenState();
}

class _WhrScreenState extends State<WhrScreen> {
  final p = AppState.instance.profile;
  late double _waist = p?.waistCm ?? 74;
  late double _hip = p?.hipCm ?? 96;
  late String _ref = p?.sex ?? 'female';
  String _wUnit = 'cm';
  String _hUnit = 'cm';
  late double? _ratio = p?.whr;
  bool _saving = false;

  String _disp(double cm, String u) => u == 'cm' ? cm.round().toString() : (cm / 2.54).toStringAsFixed(1);

  void _calculate() => setState(() => _ratio = _waist / _hip);

  Future<void> _save() async {
    _ratio ??= _waist / _hip;
    setState(() => _saving = true);
    try {
      final (risk, label) = Calc.whrCategory(_ratio!, _ref == 'male' ? 'male' : 'female');
      await Repo.saveToolResult('whr', score: double.parse(_ratio!.toStringAsFixed(2)), category: risk, data: {'waist_cm': _waist, 'hip_cm': _hip, 'reference': _ref, 'label': label});
      await AppState.instance.updateProfile({'waist_cm': _waist, 'hip_cm': _hip, 'measured_at': DateTime.now().toUtc().toIso8601String()});
      if (mounted) toast(context, 'Saved to your Health Journey 🌿');
    } catch (_) {
      if (mounted) toast(context, 'Could not save right now. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sex = _ref == 'male' ? 'male' : 'female';
    final (low, high) = Calc.whrThresholds(sex);
    final ratio = _ratio;
    final cat = ratio == null ? null : Calc.whrCategory(ratio, sex);
    final riskColor = cat == null
        ? AppColors.tertiaryFixedDim
        : cat.$1 == 'Low Risk'
            ? AppColors.tertiaryFixed
            : cat.$1 == 'Moderate Risk'
                ? AppColors.secondaryFixed
                : AppColors.errorContainer;
    final riskFg = cat == null || cat.$1 == 'Low Risk' ? AppColors.onTertiaryFixedVariant : (cat.$1 == 'Moderate Risk' ? AppColors.onSecondaryFixedVariant : AppColors.onErrorContainer);

    // gauge: low segment 50%, moderate 25%, high 25%; range low-0.15 .. high+0.15
    double pos(double r) {
      final minR = low - 0.15, maxR = high + 0.15;
      if (r < low) return ((r - minR) / (low - minR)).clamp(0, 1) * 0.5;
      if (r <= high) return 0.5 + (r - low) / (high - low) * 0.25;
      return 0.75 + ((r - high) / (maxR - high)).clamp(0, 1) * 0.25;
    }

    String meaning(double r) {
      final s = r.toStringAsFixed(2);
      if (cat!.$1 == 'Low Risk') {
        return 'Your proportion of $s reflects healthy abdominal fat distribution and cardiovascular ease. Unlike BMI, WHR looks at where energy reserves live. Hydration, core movement, and balanced meals will gently shift this number over time.';
      }
      if (cat.$1 == 'Moderate Risk') {
        return 'Your proportion of $s is slightly above the low-risk range. Regular walking, more vegetables and fibre, and fewer sugary drinks help reduce waist size gently over a semester.';
      }
      return 'Your proportion of $s suggests more weight is stored around the waist, which is linked to higher heart and metabolic risk. This is not a diagnosis — a campus doctor or dietitian can help you plan supportive steps.';
    }

    return VPage(
      header: const TitleHeader('Waist To Hip Ratio'),
      spacing: Sp.sm,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ToolSubBar(icon: Symbols.lock, onHelp: () => showInfoSheet(context, title: 'About WHR', paragraphs: const [
                'Waist-to-hip ratio = waist circumference ÷ hip circumference.',
                'WHO guidance links a ratio of 0.85 or more (women) and 0.90 or more (men) with substantially increased cardiometabolic risk.',
                'Measure your waist at the narrowest point above the navel after breathing out gently, and your hips at the widest part, keeping the tape level with the floor.',
              ])),
        ),
        VCard(
          clip: true,
          shadow: Shadows.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const IconCircle(Symbols.straighten, size: 40, bg: AppColors.primaryFixed, fg: AppColors.primary),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Body Balance & Distribution', style: T.headlineSm),
                  const SizedBox(height: 2),
                  Text('A gentle snapshot of personal balance. Your proportions naturally evolve across study seasons, sports and restful breaks.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
            ]),
            const SizedBox(height: Sp.md),
            Row(children: [
              Text('Reference Guidelines', style: T.labelMd.c(AppColors.onSurfaceVariant)),
              const Spacer(),
              Text('WHO Guide', style: T.labelSm.c(AppColors.tertiary)),
            ]),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(Rad.full)),
              child: Row(children: [
                for (final r in const [('female', 'Female'), ('diverse', 'Diverse'), ('male', 'Male')])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _ref = r.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _ref == r.$1 ? AppColors.surfaceContainerLowest : Colors.transparent,
                          borderRadius: BorderRadius.circular(Rad.full),
                          boxShadow: _ref == r.$1 ? Shadows.tiny : null,
                        ),
                        child: Text(r.$2, style: T.labelMd.c(_ref == r.$1 ? AppColors.primary : AppColors.onSurfaceVariant)),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        StepperMeasureCard(
          icon: Symbols.accessibility_new,
          title: 'Waist Circumference',
          subtitle: 'Narrowest point, above navel',
          display: _disp(_waist, _wUnit),
          unitLabel: _wUnit,
          units: const ['cm', 'in'],
          unit: _wUnit,
          onUnit: (u) => setState(() => _wUnit = u),
          value: _waist,
          min: 50,
          max: 130,
          accent: AppColors.primary,
          caption: 'Relaxed exhalation',
          scaleLabels: _wUnit == 'cm' ? const ['50 cm', '90 cm', '130 cm'] : const ['20 in', '35 in', '51 in'],
          onChanged: (v) => setState(() => _waist = v.roundToDouble()),
        ),
        StepperMeasureCard(
          icon: Symbols.airline_seat_recline_normal,
          title: 'Hip Circumference',
          subtitle: 'Widest contour of hips & glutes',
          display: _disp(_hip, _hUnit),
          unitLabel: _hUnit,
          units: const ['cm', 'in'],
          unit: _hUnit,
          onUnit: (u) => setState(() => _hUnit = u),
          value: _hip,
          min: 60,
          max: 150,
          accent: AppColors.primary,
          caption: 'Tape level to floor',
          scaleLabels: _hUnit == 'cm' ? const ['60 cm', '105 cm', '150 cm'] : const ['24 in', '41 in', '59 in'],
          onChanged: (v) => setState(() => _hip = v.roundToDouble()),
        ),
        const SizedBox(height: 4),
        PrimaryButton('Calculate Body Balance', leadingIcon: Symbols.auto_awesome, color: AppColors.tertiary, height: 52, onTap: _calculate),
        if (ratio != null && cat != null)
          VCard(
            padding: const EdgeInsets.all(Sp.md),
            shadow: Shadows.card,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('YOUR RATIO BASELINE', style: T.labelSm.c(AppColors.onSurfaceVariant).tracking(1)),
                    const SizedBox(height: 2),
                    Text(cat.$2, style: T.headlineSm),
                  ]),
                ),
                Pill(
                  color: AppColors.tertiaryFixed,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('WHO Guide', style: T.labelSm.c(AppColors.onTertiaryFixedVariant)),
                  ]),
                ),
              ]),
              const SizedBox(height: Sp.sm),
              Container(height: 1, color: AppColors.surfaceContainer),
              const SizedBox(height: Sp.md),
              Center(
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceContainerLow),
                  padding: const EdgeInsets.all(14),
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceContainerLowest, boxShadow: Shadows.soft),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('Ratio', style: T.labelSm.c(AppColors.onSurfaceVariant)),
                      Text(ratio.toStringAsFixed(2), style: T.headlineXl),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: Sp.sm),
              Center(
                child: Pill(
                  color: riskColor,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Symbols.check_circle, size: 16, color: riskFg),
                    const SizedBox(width: 6),
                    Text('${cat.$1} • ${cat.$1 == 'Low Risk' ? 'Optimal Balance' : 'Gentle Awareness'}', style: T.labelMd.c(riskFg)),
                  ]),
                ),
              ),
              const SizedBox(height: Sp.md),
              Row(children: [
                Text('Distribution Gauge', style: T.labelSm.c(AppColors.onSurfaceVariant)),
                const Spacer(),
                Text('Target < ${low.toStringAsFixed(2)}', style: T.labelSm),
              ]),
              SpectrumGauge(
                height: 10,
                segments: const [
                  GaugeSegment(AppColors.mintAccent, 2),
                  GaugeSegment(AppColors.pinkWash, 1),
                  GaugeSegment(Color(0xFFFFD6CC), 1),
                ],
                position: pos(ratio),
                markerLabel: 'You: ${ratio.toStringAsFixed(2)}',
                labels: [
                  gaugeLabel('Low Risk (<${low.toStringAsFixed(2)})', color: AppColors.tertiary, bold: true),
                  gaugeLabel('${low.toStringAsFixed(2)} - ${high.toStringAsFixed(2)}'),
                  gaugeLabel('>${high.toStringAsFixed(2)} High', color: AppColors.secondary, bold: true),
                ],
              ),
              const SizedBox(height: Sp.md),
              Container(
                padding: const EdgeInsets.all(Sp.md),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.lg)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const IconCircle(Symbols.spa, size: 32, iconSize: 18, fg: AppColors.tertiary),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('What this means for your body', style: T.labelLg),
                      const SizedBox(height: 4),
                      Text(meaning(ratio), style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
        VCard(
          color: AppColors.surfaceContainer,
          child: Row(children: [
            const IconCircle(Symbols.shield_person, size: 36, iconSize: 20),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Private to you. ', style: T.bodySm.semi),
                  const TextSpan(text: 'Measurements stay in your personal health vault. University health providers only see what you choose to share.'),
                ]),
                style: T.bodySm.c(AppColors.onSurfaceVariant),
              ),
            ),
          ]),
        ),
        SoftButton('Save to My Health Journey', icon: Symbols.bookmark_add, iconColor: AppColors.primary, color: AppColors.surfaceContainerLowest, onTap: _saving ? null : _save),
        Center(child: TextLinkButton('Compare with Body Mass Index (BMI)', icon: Symbols.arrow_forward, color: AppColors.primary, onTap: () => context.pushReplacement('/tools/bmi'))),
      ],
    );
  }
}
