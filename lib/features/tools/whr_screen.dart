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
      header: TitleHeader('WHR calculator', onLeading: () => goBack(context, '/tools')),
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
        const PrivacyNote('A screening measure, not a diagnosis of any disease. Measurements stay private to you.'),
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
      'Low Risk' => 'A lower waist-to-hip ratio means weight is carried relatively more at the hips than the waist. Unlike BMI, this looks at where fat is stored, not just how much there is.',
      'Moderate Risk' => 'A ratio of $s is slightly above the low-risk range, suggesting a modest shift toward central (abdominal) fat distribution. Regular walking, more vegetables and fibre, and fewer sugary drinks help reduce waist size over time.',
      _ => 'Higher waist-to-hip ratio. Your result indicates a greater tendency toward central fat distribution, which is associated with increased cardiometabolic risk. This is not a diagnosis; a campus doctor or dietitian can help.',
    };
    // 0 = pear-leaning (fat carried more at the hips), 1 = apple-leaning
    // (fat carried more at the waist), scaled across the chart's own range.
    final leanToApple = ((ratio - (low - 0.1)) / ((high + 0.1) - (low - 0.1))).clamp(0.0, 1.0);
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
        const SizedBox(height: Sp.lg),
        BodyShapeDiagram(leanToApple: leanToApple, color: color),
        const SizedBox(height: Sp.md),
        Text(meaning, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
      ]),
    );
  }
}

/// Two stylised body-shape silhouettes — "pear" (weight carried more at the
/// hips) and "apple" (weight carried more at the waist) — with the one
/// closer to the student's own ratio highlighted. Illustrative only.
class BodyShapeDiagram extends StatelessWidget {
  const BodyShapeDiagram({super.key, required this.leanToApple, required this.color});

  /// 0 = clearly pear-shaped, 1 = clearly apple-shaped.
  final double leanToApple;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final pearOn = leanToApple < 0.5;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _shape(0.62, 'Pear shape', 'More weight at the hips', pearOn),
      _shape(0.92, 'Apple shape', 'More weight at the waist', !pearOn),
    ]);
  }

  Widget _shape(double waistFactor, String title, String sub, bool on) => Column(children: [
        Opacity(
          opacity: on ? 1 : 0.35,
          child: SizedBox(width: 72, height: 96, child: CustomPaint(painter: _SilhouettePainter(waistFactor: waistFactor, color: on ? color : AppColors.outline))),
        ),
        const SizedBox(height: 6),
        Text(title, style: T.labelMd.w(on ? FontWeight.w700 : FontWeight.w500).c(on ? AppColors.onSurface : AppColors.onSurfaceVariant)),
        Text(sub, style: T.labelSm.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
      ]);
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter({required this.waistFactor, required this.color});
  final double waistFactor;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(w / 2, h * 0.12), w * 0.17, paint);

    final shoulder = w * 0.40, waist = w * 0.40 * waistFactor, hip = w * 0.44;
    final path = Path()
      ..moveTo(w / 2 - shoulder, h * 0.26)
      ..quadraticBezierTo(w / 2 - waist * 1.1, h * 0.52, w / 2 - waist, h * 0.58)
      ..quadraticBezierTo(w / 2 - hip * 1.05, h * 0.68, w / 2 - hip, h * 0.82)
      ..lineTo(w / 2 - hip * 0.7, h)
      ..lineTo(w / 2 + hip * 0.7, h)
      ..lineTo(w / 2 + hip, h * 0.82)
      ..quadraticBezierTo(w / 2 + hip * 1.05, h * 0.68, w / 2 + waist, h * 0.58)
      ..quadraticBezierTo(w / 2 + waist * 1.1, h * 0.52, w / 2 + shoulder, h * 0.26)
      ..quadraticBezierTo(w / 2, h * 0.18, w / 2 - shoulder, h * 0.26)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter old) => old.waistFactor != waistFactor || old.color != color;
}
