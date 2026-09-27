import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Smooth area sparkline.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, required this.color, this.height = 36, this.baseline, this.showDots = false, this.highlightLast = true});
  final List<double> values;
  final Color color;
  final double height;
  final double? baseline;
  final bool showDots;
  final bool highlightLast;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SparkPainter(values, color, baseline, showDots, highlightLast)),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.baseline, this.dots, this.highlightLast);
  final List<double> values;
  final Color color;
  final double? baseline;
  final bool dots;
  final bool highlightLast;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final vs = values.length == 1 ? [values.first, values.first] : values;
    final maxV = math.max(vs.reduce(math.max), baseline ?? 0);
    final minV = math.min(vs.reduce(math.min), baseline ?? double.infinity);
    final span = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
    const padTop = 6.0, padBottom = 4.0;
    Offset pt(int i, double v) => Offset(
          size.width * i / (vs.length - 1),
          padTop + (size.height - padTop - padBottom) * (1 - (v - minV) / span),
        );
    final pts = [for (int i = 0; i < vs.length; i++) pt(i, vs[i])];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final p0 = pts[i - 1], p1 = pts[i];
      final cx = (p0.dx + p1.dx) / 2;
      line.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)])
              .createShader(Offset.zero & size));
    if (baseline != null) {
      final y = pt(0, baseline!).dy;
      final dash = Paint()
        ..color = AppColors.outlineVariant
        ..strokeWidth = 1.5;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, size.width), y), dash);
        x += 8;
      }
    }
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..color = color);
    if (dots) {
      for (final p in pts) {
        canvas.drawCircle(p, 4.5, Paint()..color = color);
        canvas.drawCircle(p, 4.5, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white);
      }
    }
    if (highlightLast) {
      if (dots) canvas.drawCircle(pts.last, 8, Paint()..color = color.withValues(alpha: 0.25));
      canvas.drawCircle(pts.last, 3.5, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values || old.color != color;
}
