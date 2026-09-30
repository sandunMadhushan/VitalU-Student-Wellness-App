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
      if (mounted) toast(context, 'Could not save right now. Your result is shown below.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  (Color, IconData, String, String) _style(double bmi) {
    if (bmi < 18.5) {
      return (AppColors.water, Symbols.trending_down_rounded, 'Underweight',
          'Your BMI is below the typical range. Regular, nourishing meals and snacks between lectures can help. A campus nutritionist can build a plan with you.');
    }
    if (bmi < 25) {
      return (AppColors.tertiary, Symbols.check_circle_rounded, 'Normal weight',
          'Your BMI is in the healthy range. Energy, sleep and hydration matter just as much, especially around exams.');
    }
    if (bmi < 30) {
      return (AppColors.warning, Symbols.trending_up_rounded, 'Overweight',
          'Your BMI is a little above the typical range. Walking between classes, half a plate of vegetables and fewer sugary drinks make a real difference over a semester.');
    }
    return (AppColors.error, Symbols.priority_high_rounded, 'Obesity',
        'Your BMI is in the higher range. This is not a diagnosis, but a campus doctor or dietitian can help you plan steady, sustainable changes.');
  }

  void _whtr() {
    final waist = AppState.instance.profile?.waistCm;
    final ratio = waist == null ? null : waist / _heightCm;
    showInfoSheet(context, title: 'Waist-to-height ratio', paragraphs: [
      if (ratio == null)
        'Add your waist measurement in your profile or the waist-to-hip tool to see this.'
      else
        'Your waist-to-height ratio is ${ratio.toStringAsFixed(2)}, ${ratio < 0.5 ? 'within the healthy range (below 0.5).' : 'at or above 0.5, which suggests more fat around the middle. Regular activity and balanced meals help.'}',
      'Rule of thumb: keep your waist to less than half your height. It reflects central body fat, which is closely linked to heart and metabolic health.',
    ]);
  }

  @override
  Widget build(BuildContext context) {
    double pos(double b) {
      const total = 4.8;
      if (b < 18.5) return ((b - 12).clamp(0, 6.5) / 6.5) * (1 / total);
      if (b < 25) return (1 + (b - 18.5) / 6.5 * 1.6) / total;
      if (b < 30) return (2.6 + (b - 25) / 5 * 1.2) / total;
      return (3.8 + ((b - 30).clamp(0, 10) / 10)) / total;
    }

    return VPage(
      header: TitleHeader('BMI', onLeading: () => goBack(context, '/tools')),
      children: [
        ToolSubBar(onHelp: () => showInfoSheet(context, title: 'About BMI', paragraphs: const [
              'Body mass index is weight (kg) divided by height (m) squared. WHO adult categories: under 18.5 underweight, 18.5 to 24.9 normal, 25 to 29.9 overweight, 30 and above obesity.',
              'For South Asian adults, health risks can start at lower values (around 23), so a waist measurement is a helpful companion.',
              'BMI does not account for muscle, bone structure or where fat is stored. It is a screening indicator, not a diagnosis.',
            ])),
        if (_bmi != null) _result(_bmi!, pos),
        StepperMeasureCard(
          icon: Symbols.height_rounded,
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
          icon: Symbols.monitor_weight_rounded,
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
        PrimaryButton(_bmi == null ? 'Calculate' : 'Update result', loading: _saving, onTap: _calculate),
        ListGroup(children: [
          ListRow(icon: Symbols.accessibility_new_rounded, color: AppColors.body, title: 'Waist-to-height ratio', subtitle: 'A companion measure for central body fat', onTap: _whtr),
        ]),
        const PrivacyNote('BMI is a population guideline and does not reflect muscle or bone structure. Only you can see this.'),
      ],
    );
  }

  Widget _result(double bmi, double Function(double) pos) {
    final st = _style(bmi);
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CategoryLabel('Your BMI', icon: Symbols.monitor_weight_rounded, color: AppColors.body, trailing: _updated ? 'Just updated' : 'Last saved'),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(bmi.toStringAsFixed(1), style: T.metric(44)),
          const SizedBox(width: Sp.md),
          Icon(st.$2, color: st.$1, size: 24, fill: 1),
          const SizedBox(width: 6),
          Flexible(child: Text(st.$3, style: T.headlineSm.c(st.$1))),
        ]),
        const SizedBox(height: Sp.md),
        SpectrumGauge(
          segments: [
            GaugeSegment(AppColors.water, 1),
            GaugeSegment(AppColors.tertiary, 1.6),
            GaugeSegment(AppColors.warning, 1.2),
            GaugeSegment(AppColors.error, 1),
          ],
          position: pos(bmi),
          markerLabel: bmi.toStringAsFixed(1),
          labels: [gaugeLabel('Under'), gaugeLabel('18.5'), gaugeLabel('Normal'), gaugeLabel('25'), gaugeLabel('30+')],
        ),
        const SizedBox(height: Sp.md),
        Text(st.$4, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
      ]),
    );
  }
}
