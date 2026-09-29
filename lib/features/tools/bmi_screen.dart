import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'tool_widgets.dart';

class BmiScreen extends StatefulWidget {
  const BmiScreen({super.key});
  @override
  State<BmiScreen> createState() => _BmiScreenState();
}

class _BmiScreenState extends State<BmiScreen> {
  late double _heightCm = AppState.instance.profile?.heightCm ?? 165;
  late double _weightKg = AppState.instance.profile?.weightKg ?? 60;
  String _hUnit = 'cm';
  String _wUnit = 'kg';
  late double? _bmi = Calc.bmi(AppState.instance.profile?.heightCm, AppState.instance.profile?.weightKg);
  bool _updated = false;
  bool _saving = false;

  String get _heightDisplay {
    if (_hUnit == 'cm') return _heightCm.round().toString();
    final totalIn = _heightCm / 2.54;
    return "${totalIn ~/ 12}'${(totalIn % 12).round()}";
  }

  String get _weightDisplay => _wUnit == 'kg' ? _weightKg.toStringAsFixed(_weightKg % 1 == 0 ? 0 : 1) : (_weightKg * 2.20462).round().toString();

  Future<void> _calculate() async {
    final bmi = Calc.bmi(_heightCm, _weightKg)!;
    setState(() {
      _bmi = bmi;
      _updated = true;
      _saving = true;
    });
    try {
      await Repo.saveToolResult('bmi', score: double.parse(bmi.toStringAsFixed(1)), category: Calc.bmiCategory(bmi), data: {'height_cm': _heightCm, 'weight_kg': _weightKg});
      await AppState.instance.updateProfile({'height_cm': _heightCm, 'weight_kg': _weightKg, 'measured_at': DateTime.now().toUtc().toIso8601String()});
    } catch (_) {
      if (mounted) toast(context, 'Saved on screen — could not sync right now.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  (Color, Color, String, String) _style(double bmi) {
    if (bmi < 18.5) {
      return (AppColors.primaryFixed, AppColors.onPrimaryFixed, 'Underweight • Gentle Care',
          'Your BMI sits below the typical range. Regular, nourishing meals and snacks between lectures can help — a campus nutritionist can build a plan with you.');
    }
    if (bmi < 25) {
      return (AppColors.tertiaryFixed, AppColors.onTertiaryFixed, 'Normal Weight • Optimal',
          'Your BMI is right in the healthy, balanced zone. Remember that during exams, everyday energy, quality sleep, and consistent hydration matter far more than single numbers.');
    }
    if (bmi < 30) {
      return (AppColors.secondaryFixed, AppColors.onSecondaryFixed, 'Overweight • Gentle Watch',
          'Your BMI is a little above the typical range. Small steps — walking between classes, half-plate vegetables and fewer sugary drinks — make a real difference over a semester.');
    }
    return (AppColors.errorContainer, AppColors.onErrorContainer, 'Higher Range • Check-in Suggested',
        'Your BMI is in the higher range. This is not a diagnosis, but a friendly chat with a campus doctor or dietitian can help you plan supportive, sustainable changes.');
  }

  void _whtr() {
    final waist = AppState.instance.profile?.waistCm;
    final ratio = waist == null ? null : waist / _heightCm;
    showInfoSheet(context, title: 'Waist-to-Height Ratio (WHtR)', icon: Symbols.accessibility_new, paragraphs: [
      if (ratio == null)
        'Add your waist measurement in your Health Profile (or the WHR calculator) to see your WHtR.'
      else
        'Your WHtR is ${ratio.toStringAsFixed(2)} — ${ratio < 0.5 ? 'within the healthy range (below 0.5).' : 'at or above 0.5, which suggests more central (abdominal) fat. Gentle activity and balanced meals help.'}',
      'A simple rule of thumb: keep your waist to less than half your height. WHtR reflects central body fat, which is closely linked to heart and metabolic health.',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final st = _style(_bmi ?? 21.7);
    // Gauge mapping: 4 segments with flex 1, 1.6, 1.2, 1 over BMI 12..40
    double pos(double b) {
      const total = 4.8;
      if (b < 18.5) return ((b - 12).clamp(0, 6.5) / 6.5) * (1 / total);
      if (b < 25) return (1 + (b - 18.5) / 6.5 * 1.6) / total;
      if (b < 30) return (2.6 + (b - 25) / 5 * 1.2) / total;
      return (3.8 + ((b - 30).clamp(0, 10) / 10)) / total;
    }

    return VPage(
      header: const BrandBackHeader(chip: 'BMI'),
      backgroundDecoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.surface, AppColors.surfaceContainerLow, AppColors.surfaceContainer]),
      ),
      background: Colors.transparent,
      spacing: Sp.sm,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ToolSubBar(onHelp: () => showInfoSheet(context, title: 'About BMI', paragraphs: const [
                'Body Mass Index = weight (kg) ÷ height (m)². It uses the WHO adult categories: under 18.5 underweight, 18.5–24.9 normal, 25–29.9 overweight, 30+ obesity.',
                'For South Asian adults, health risks can begin at lower BMI values (around 23), so waist measurements are a helpful companion.',
                'BMI does not reflect muscle, bone structure or where fat is stored. It is a screening indicator, not a diagnosis.',
              ])),
        ),
        VCard(
          clip: true,
          shadow: Shadows.card,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(right: -36, bottom: -36, child: Glow(color: AppColors.tertiaryFixed.withValues(alpha: 0.3), size: 96)),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconCircle(Symbols.spa, size: 40, bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixed, fill: 1),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Check Your Baseline', style: T.headlineSm),
                  const SizedBox(height: 2),
                  Text('A gentle indicator for university wellbeing. Bodies naturally evolve through exam rhythms, semester changes, and growth.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 4),
        StepperMeasureCard(
          icon: Symbols.straighten,
          title: 'Height',
          display: _heightDisplay,
          unitLabel: _hUnit == 'cm' ? 'cm' : '',
          units: const ['cm', 'ft/in'],
          unit: _hUnit,
          onUnit: (u) => setState(() => _hUnit = u),
          value: _heightCm,
          min: 120,
          max: 220,
          step: _hUnit == 'cm' ? 1 : 2.54,
          onChanged: (v) => setState(() => _heightCm = v.roundToDouble()),
        ),
        StepperMeasureCard(
          icon: Symbols.scale,
          title: 'Weight',
          display: _weightDisplay,
          unitLabel: _wUnit,
          units: const ['kg', 'lb'],
          unit: _wUnit,
          onUnit: (u) => setState(() => _wUnit = u),
          value: _weightKg,
          min: 35,
          max: 150,
          step: _wUnit == 'kg' ? 0.5 : 0.45359,
          onChanged: (v) => setState(() => _weightKg = (v * 2).round() / 2),
        ),
        const SizedBox(height: 4),
        PrimaryButton(_bmi == null ? 'Calculate BMI' : 'Recalculate BMI', leadingIcon: Symbols.auto_awesome, color: AppColors.tertiary, height: 52, loading: _saving, onTap: _calculate),
        const SizedBox(height: 4),
        if (_bmi != null)
          VCard(
            shadow: Shadows.card,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Your Result', style: T.headlineSm),
                const SizedBox(width: 6),
                if (_updated) TagPill('Updated', bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixed),
                const Spacer(),
                Text('Standard Adult BMI', style: T.labelSm.c(AppColors.onSurfaceVariant)),
              ]),
              const SizedBox(height: Sp.md),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: Sp.sm, runSpacing: 6, children: [
                Text(_bmi!.toStringAsFixed(1), style: T.headlineXl.tracking(-1.5)),
                Pill(
                  color: st.$1,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: st.$2, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(st.$3, style: T.labelMd.c(st.$2)),
                  ]),
                ),
              ]),
              const SizedBox(height: Sp.md),
              SpectrumGauge(
                segments: [
                  GaugeSegment(AppColors.primaryFixed, 1),
                  GaugeSegment(AppColors.tertiaryFixed, 1.6),
                  GaugeSegment(AppColors.secondaryFixed, 1.2),
                  GaugeSegment(AppColors.errorContainer, 1),
                ],
                position: pos(_bmi!),
                markerLabel: 'You: ${_bmi!.toStringAsFixed(1)}',
                labels: [
                  gaugeLabel('Under (<18.5)'),
                  gaugeLabel('18.5'),
                  gaugeLabel('Balanced', color: AppColors.tertiary, bold: true),
                  gaugeLabel('25.0'),
                  gaugeLabel('30.0+'),
                ],
              ),
              const SizedBox(height: Sp.md),
              Container(
                padding: const EdgeInsets.all(Sp.sm),
                decoration: BoxDecoration(color: AppColors.tertiaryFixed.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(Rad.base)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Symbols.eco, size: 20, color: AppColors.tertiary, fill: 1),
                  const SizedBox(width: Sp.xs),
                  Expanded(child: Text(st.$4, style: T.bodySm.c(AppColors.onTertiaryFixedVariant).lh(1.6))),
                ]),
              ),
            ]),
          ),
        VCard(
          color: AppColors.surfaceContainerLow,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.lock, size: 18, color: AppColors.outline),
            const SizedBox(width: Sp.xs),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Private to You', style: T.labelMd),
                const SizedBox(height: 4),
                Text('BMI is a population-level guideline. It does not reflect lean muscle, bone structure, hormonal health, or athletic conditioning. No campus staff or peers have access to this metric.',
                    style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        Pressable(
          onTap: _whtr,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Sp.sm, vertical: Sp.xs + 2),
            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(Rad.full)),
            child: Row(children: [
              IconCircle(Symbols.accessibility_new, size: 28, iconSize: 16, fg: AppColors.tertiary),
              const SizedBox(width: 8),
              Expanded(child: Text('Explore Waist-to-Height Ratio (WHtR)', style: T.labelMd)),
              Icon(Symbols.chevron_right, size: 18, color: AppColors.onSurfaceVariant),
            ]),
          ),
        ),
      ],
    );
  }
}
