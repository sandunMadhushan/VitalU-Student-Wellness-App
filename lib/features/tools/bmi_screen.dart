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

  // Signals used to personalise the tips, loaded from the student's own logs.
  bool _signalsLoaded = false;
  int _breakfastDays = 7;
  int _diversity7d = 8;
  int _avgSteps = 8000;

  @override
  void initState() {
    super.initState();
    _loadSignals();
  }

  Future<void> _loadSignals() async {
    try {
      final now = DateTime.now();
      final from = now.subtract(const Duration(days: 6));
      final results = await Future.wait([
        Repo.mealsBetween(from, now),
        Repo.diversityBetween(from, now),
        Repo.stepsByDay(from, now),
      ]);
      final meals = results[0] as List<Rec>;
      final diversity = results[1] as List<Rec>;
      final steps = results[2] as Map<String, int>;
      _breakfastDays = meals.where((m) => m['meal_type'] == 'breakfast' && m['status'] == 'logged').map((m) => m['logged_at'].toString().substring(0, 10)).toSet().length;
      _diversity7d = diversity.map((r) => r['food_group']).toSet().length;
      if (steps.isNotEmpty) _avgSteps = (steps.values.reduce((a, b) => a + b) / steps.length).round();
    } catch (_) {}
    if (mounted) setState(() => _signalsLoaded = true);
  }

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

  (Color, IconData, String) _style(double bmi) {
    if (bmi < 18.5) return (AppColors.water, Symbols.trending_down_rounded, 'Underweight');
    if (bmi < 25) return (AppColors.tertiary, Symbols.check_circle_rounded, 'Normal weight');
    if (bmi < 30) return (AppColors.warning, Symbols.trending_up_rounded, 'Overweight');
    return (AppColors.error, Symbols.priority_high_rounded, 'Obesity');
  }

  /// Short, direct "try this" tips, personalised from the student's own
  /// recent logs where a signal is available, falling back to a general tip.
  List<String> _tips(double bmi) {
    final tips = <String>[];
    if (bmi < 18.5) {
      tips.add('Add nutrient-dense foods such as eggs, dhal, milk, nuts or other protein-rich foods to your meals.');
      if (_breakfastDays < 4) tips.add('Plan a simple breakfast instead of regularly skipping it — it adds up over a week.');
      tips.add('Three solid meals plus two snacks a day is easier on the stomach than fewer, bigger ones.');
    } else if (bmi < 25) {
      tips.add('Your weight is in the healthy range. Keep your current routine of regular meals, movement and sleep.');
      if (_avgSteps < 6000) tips.add('A short daily walk helps maintain this, even on heavy study days.');
    } else {
      if (_breakfastDays < 4) tips.add('Plan a simple breakfast instead of regularly skipping it — it tends to reduce heavier snacking later.');
      if (_diversity7d < 5) tips.add('Add another food group to your meals today — more variety, not less food, is the easiest first step.');
      if (_avgSteps < 6000) tips.add('Add a short walk or another form of movement to your day — even 15–20 minutes helps.');
      tips.add('Reduce sugar-sweetened drinks and choose water more often.');
      if (bmi >= 30) tips.add('A campus dietitian can help build a plan that fits lecture hours and canteen options.');
    }
    return tips;
  }

  void _target(double bmi) {
    final (minKg, maxKg) = Calc.normalWeightRangeFor(_heightCm);
    final diff = bmi < 18.5 ? minKg - _weightKg : (bmi >= 25 ? _weightKg - maxKg : 0.0);
    showInfoSheet(context, title: 'Your target weight range', paragraphs: [
      'For your height, a BMI in the normal range (18.5–24.9) is about ${minKg.toStringAsFixed(0)}–${maxKg.toStringAsFixed(0)} kg.',
      if (bmi < 18.5) 'Gaining roughly ${diff.toStringAsFixed(1)} kg would bring you into that range — a gradual, steady goal is healthiest.',
      if (bmi >= 25) 'Losing roughly ${diff.toStringAsFixed(1)} kg would bring you into that range. Aim for slow, sustainable change rather than a crash diet.',
      if (bmi >= 18.5 && bmi < 25) 'You are already within this range — the goal now is to maintain it.',
      'This is a population guideline, not a personal prescription. Muscle mass, bone structure and overall health matter too.',
    ]);
  }

  void _whtr() {
    final waist = AppState.instance.profile?.waistCm;
    final ratio = waist == null ? null : waist / _heightCm;
    showInfoSheet(context, title: 'Waist-to-height ratio', paragraphs: [
      if (ratio == null)
        'Add your waist measurement in your profile or the WHR calculator to see this.'
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
      header: TitleHeader('BMI calculator', onLeading: () => goBack(context, '/tools')),
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
        if (_bmi != null)
          ListGroup(children: [
            ListRow(icon: Symbols.target_rounded, color: AppColors.body, title: 'My target weight range', subtitle: 'What would bring you into the normal range', onTap: () => _target(_bmi!)),
            ListRow(icon: Symbols.accessibility_new_rounded, color: AppColors.body, title: 'Waist-to-height ratio', subtitle: 'A companion measure for central body fat', onTap: _whtr),
          ]),
        const PrivacyNote('A screening tool, not a diagnosis of any disease. Only you can see this.'),
      ],
    );
  }

  Widget _result(double bmi, double Function(double) pos) {
    final st = _style(bmi);
    final tips = _tips(bmi);
    return Column(children: [
      VCard(
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
        ]),
      ),
      VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Symbols.lightbulb_rounded, size: 20, color: AppColors.warning, fill: 1),
            const SizedBox(width: 8),
            Expanded(child: Text('Try this', style: T.headlineSm)),
          ]),
          const SizedBox(height: 10),
          for (final t in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 7), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: st.$1, shape: BoxShape.circle))),
                const SizedBox(width: 10),
                Expanded(child: Text(t, style: T.bodyMd.c(AppColors.onSurfaceVariant))),
              ]),
            ),
          if (!_signalsLoaded) Text('Personalising from your recent logs…', style: T.bodySm.c(AppColors.outline)),
        ]),
      ),
      if (bmi >= 30)
        ListGroup(children: [
          ListRow(icon: Symbols.stethoscope_rounded, color: AppColors.primary, title: 'Talk to a professional', subtitle: 'A campus doctor or dietitian can help you plan', onTap: () => context.push('/professionals')),
        ]),
    ]);
  }
}
