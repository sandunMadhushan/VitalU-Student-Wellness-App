import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// An educational drawing of the lungs breathing. Sliding the years of
/// smoking darkens the tissue, adds tar spots, narrows the airways and makes
/// each breath shallower, with plain notes on what is changing. It is an
/// illustration, not a medical image.
class LungsAnimation extends StatefulWidget {
  const LungsAnimation({super.key});
  @override
  State<LungsAnimation> createState() => _LungsAnimationState();
}

class _LungsAnimationState extends State<LungsAnimation> with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat();
  double _years = 0;

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  String get _note {
    if (_years == 0) return 'Healthy lungs: pink, elastic tissue and clear airways. Tiny hairs (cilia) sweep out dust and germs.';
    if (_years < 3) return 'Within months: cilia are damaged, mucus builds up and a morning cough may start.';
    if (_years < 8) return 'After a few years: tar stains the tissue, airways narrow and breathing during sport gets harder.';
    if (_years < 15) return 'After many years: air sacs (alveoli) break down and cannot be repaired. This is how COPD develops.';
    return 'Long-term smoking: severe damage, shallow breathing and a much higher risk of lung cancer and heart disease.';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.heart;
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Symbols.pulmonology_rounded, color: c, fill: 1),
          const SizedBox(width: 8),
          Expanded(child: Text('See what smoking does', style: T.headlineSm)),
        ]),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1.25,
          child: AnimatedBuilder(
            animation: _breath,
            builder: (_, _) => CustomPaint(painter: _LungsPainter(breath: _breath.value, damage: _years / 20, dark: AppColors.isDark)),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('Years of smoking', style: T.labelLg.semi),
          const Spacer(),
          Text(_years == 0 ? 'Never' : '${_years.round()} ${_years.round() == 1 ? 'year' : 'years'}', style: T.labelLg.semi.c(_years == 0 ? AppColors.tertiary : c)),
        ]),
        VSlider(value: _years, min: 0, max: 20, divisions: 20, color: c, onChanged: (v) => setState(() => _years = v)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(_note, key: ValueKey(_note), style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.45)),
        ),
        const SizedBox(height: 8),
        Text('Educational illustration, not a medical image. Effects vary from person to person.', style: T.labelSm.c(AppColors.outline)),
      ]),
    );
  }
}

class _LungsPainter extends CustomPainter {
  _LungsPainter({required this.breath, required this.damage, required this.dark});
  final double breath;
  final double damage;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 300;
    canvas.save();
    canvas.scale(s);
    // Breathing gets shallower as damage grows.
    final depth = 0.06 * (1 - damage * 0.7);
    final inhale = (math.sin(breath * 2 * math.pi) + 1) / 2;
    final scale = 1 + depth * inhale;

    final healthy = const Color(0xFFF29AAE);
    final damaged = const Color(0xFF6B5B57);
    final tissue = Color.lerp(healthy, damaged, Curves.easeIn.transform(damage))!;
    final edge = Color.lerp(const Color(0xFFD9667F), const Color(0xFF3F3532), damage)!;

    // Windpipe.
    final airway = Paint()
      ..color = dark ? const Color(0xFFB7BCC6) : const Color(0xFFCBD2DC)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(150, 18), const Offset(150, 92), airway..strokeWidth = 16 - 4 * damage);
    for (double y = 26; y < 90; y += 10) {
      canvas.drawLine(Offset(143, y), Offset(157, y), Paint()
        ..color = dark ? const Color(0xFF8E95A1) : const Color(0xFFAEB6C2)
        ..strokeWidth = 2);
    }

    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      final pivot = Offset(150 + side * 58, 150);
      canvas.translate(pivot.dx, pivot.dy);
      canvas.scale(scale, scale);
      canvas.translate(-pivot.dx, -pivot.dy);

      final lung = Path();
      if (side < 0) {
        lung
          ..moveTo(138, 92)
          ..cubicTo(110, 80, 64, 96, 52, 150)
          ..cubicTo(42, 196, 54, 222, 84, 224)
          ..cubicTo(112, 226, 132, 214, 138, 196)
          ..close();
      } else {
        lung
          ..moveTo(162, 92)
          ..cubicTo(190, 80, 236, 96, 248, 150)
          ..cubicTo(258, 196, 246, 222, 216, 224)
          ..cubicTo(188, 226, 168, 214, 162, 196)
          ..close();
      }
      canvas.drawPath(lung.shift(const Offset(0, 5)), Paint()..color = Colors.black.withValues(alpha: 0.08));
      canvas.drawPath(
        lung,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(side * -0.3, -0.4),
            radius: 0.9,
            colors: [Color.lerp(tissue, Colors.white, 0.25)!, tissue],
          ).createShader(lung.getBounds()),
      );
      canvas.drawPath(lung, Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5);

      // Bronchial tree: narrows with damage.
      final br = Paint()
        ..color = dark ? const Color(0xFFE9E4E6) : Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final start = Offset(150 + side * 10, 96);
      void branch(Offset from, double angle, double len, double w, int depthLeft) {
        if (depthLeft == 0) return;
        final to = from + Offset(math.cos(angle), math.sin(angle)) * len;
        canvas.drawLine(from, to, br..strokeWidth = w * (1 - 0.5 * damage));
        branch(to, angle - 0.45, len * 0.68, w * 0.7, depthLeft - 1);
        branch(to, angle + 0.45, len * 0.68, w * 0.7, depthLeft - 1);
      }

      branch(start, side < 0 ? math.pi * 0.72 : math.pi * 0.28, 34, 6, 4);

      // Tar spots appear and spread with years of smoking.
      final rnd = math.Random(side < 0 ? 7 : 11);
      final spots = (damage * 70).round();
      final tar = Paint()..color = const Color(0xFF2B211E).withValues(alpha: 0.55);
      canvas.save();
      canvas.clipPath(lung);
      for (int i = 0; i < spots; i++) {
        final x = 150 + side * (25 + rnd.nextDouble() * 85);
        final y = 105 + rnd.nextDouble() * 115;
        canvas.drawCircle(Offset(x, y), 1.5 + rnd.nextDouble() * 3.5 * damage, tar);
      }
      canvas.restore();
      canvas.restore();
    }

    // Breath in: little air particles flowing down the windpipe.
    if (inhale > 0.15) {
      final air = Paint()..color = (damage > 0.3 ? const Color(0xFF9A8E86) : const Color(0xFF7FC8F8)).withValues(alpha: 0.7 * inhale);
      for (int i = 0; i < 4; i++) {
        final y = 18 + ((breath * 4 + i / 4) % 1) * 70;
        canvas.drawCircle(Offset(150, y), 3, air);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LungsPainter old) => old.breath != breath || old.damage != damage || old.dark != dark;
}
