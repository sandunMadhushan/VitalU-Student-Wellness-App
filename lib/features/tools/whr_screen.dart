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
      if (mounted) toast(context, 'Saved to your profile');
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

    double pos(double r) {
      final minR = low - 0.15, maxR = high + 0.15;
      if (r < low) return ((r - minR) / (low - minR)).clamp(0, 1) * 0.5;
      if (r <= high) return 0.5 + (r - low) / (high - low) * 0.25;
      return 0.75 + ((r - high) / (maxR - high)).clamp(0, 1) * 0.25;
    }

    return VPage(
      header: TitleHeader('Waist-to-hip ratio', onLeading: () => goBack(context, '/tools')),
      children: [
        ToolSubBar(onHelp: () => showInfoSheet(context, title: 'About waist-to-hip ratio', paragraphs: const [
              'Waist-to-hip ratio is your waist circumference divided by your hip circumference.',
              'WHO guidance links a ratio of 0.85 or more (women) and 0.90 or more (men) with substantially increased cardiometabolic risk.',
              'Measure your waist at the narrowest point above the navel after breathing out, and your hips at the widest part, keeping the tape level with the floor.',
            ])),
        if (ratio != null && cat != null) _result(ratio, cat, low, high, pos(ratio)),
        VCard(
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Reference ranges', style: T.bodyLg),
                Text('WHO thresholds differ by sex', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
            Segmented(
              options: const ['Female', 'Male'],
              value: _ref == 'male' ? 'Male' : 'Female',
              onChanged: (v) => setState(() => _ref = v.toLowerCase()),
            ),
          ]),
        ),
        StepperMeasureCard(
          icon: Symbols.straighten_rounded,
          title: 'Waist',
          subtitle: 'Narrowest point above the navel, after breathing out',
          display: _disp(_waist, _wUnit),
          unitLabel: _wUnit,
          units: const ['cm', 'in'],
          unit: _wUnit,
          onUnit: (u) => setState(() => _wUnit = u),
          value: _waist,
          min: 50,
          max: 130,
          onChanged: (v) => setState(() => _waist = v.roundToDouble()),
        ),
        StepperMeasureCard(
          icon: Symbols.accessibility_new_rounded,
          title: 'Hip',
          subtitle: 'Widest part of the hips, tape level',
          display: _disp(_hip, _hUnit),
          unitLabel: _hUnit,
          units: const ['cm', 'in'],
          unit: _hUnit,
          onUnit: (u) => setState(() => _hUnit = u),
          value: _hip,
          min: 60,
          max: 150,
          onChanged: (v) => setState(() => _hip = v.roundToDouble()),
        ),
        PrimaryButton('Calculate', onTap: _calculate),
        if (ratio != null) SoftButton('Save to my profile', icon: Symbols.bookmark_add_rounded, onTap: _saving ? null : _save),
        ListGroup(children: [
          ListRow(icon: Symbols.monitor_weight_rounded, color: AppColors.body, title: 'Compare with BMI', onTap: () => context.pushReplacement('/tools/bmi')),
        ]),
        const PrivacyNote('Measurements stay private to you.'),
      ],
    );
  }

  Widget _result(double ratio, (String, String) cat, double low, double high, double position) {
    final (color, icon) = switch (cat.$1) {
      'Low Risk' => (AppColors.tertiary, Symbols.check_circle_rounded),
      'Moderate Risk' => (AppColors.warning, Symbols.error_rounded),
      _ => (AppColors.error, Symbols.priority_high_rounded),
    };
    final s = ratio.toStringAsFixed(2);
    final meaning = switch (cat.$1) {
      'Low Risk' => 'A ratio of $s means weight is not concentrated around your waist. Unlike BMI, this looks at where fat is stored.',
      'Moderate Risk' => 'A ratio of $s is slightly above the low-risk range. Regular walking, more vegetables and fibre, and fewer sugary drinks help reduce waist size over time.',
      _ => 'A ratio of $s suggests more weight is stored around the waist, which is linked to higher heart and metabolic risk. This is not a diagnosis; a campus doctor or dietitian can help.',
    };
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CategoryLabel('Your ratio', icon: Symbols.straighten_rounded, color: AppColors.body),
        const SizedBox(height: 8),
        Row(children: [
          Text(s, style: T.metric(44)),
          const SizedBox(width: Sp.md),
          Icon(icon, color: color, size: 24, fill: 1),
          const SizedBox(width: 6),
          Flexible(child: Text(cat.$1, style: T.headlineSm.c(color))),
        ]),
        const SizedBox(height: Sp.md),
        SpectrumGauge(
          segments: [GaugeSegment(AppColors.tertiary, 2), GaugeSegment(AppColors.warning, 1), GaugeSegment(AppColors.error, 1)],
          position: position,
          markerLabel: s,
          labels: [gaugeLabel('Low < ${low.toStringAsFixed(2)}'), gaugeLabel('Moderate'), gaugeLabel('High > ${high.toStringAsFixed(2)}')],
        ),
        const SizedBox(height: Sp.md),
        Text(meaning, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
      ]),
    );
  }
}
