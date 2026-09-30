import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'text.dart';
import 'tokens.dart';

/// Vertical bar chart with axis labels and an optional dashed goal line.
/// The most recent bar is drawn at full strength, earlier ones softer.
class BarChart extends StatelessWidget {
  const BarChart({super.key, required this.values, required this.labels, required this.color, this.goal, this.height = 120, this.highlightLast = true});
  final List<double> values;
  final List<String> labels;
  final Color color;
  final double? goal;
  final double height;
  final bool highlightLast;

  @override
  Widget build(BuildContext context) => Column(children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _BarPainter(values, color, goal, highlightLast, AppColors.outlineVariant, AppColors.surfaceContainerHigh),
            child: values.every((v) => v <= 0) ? Center(child: Text('No entries yet', style: T.bodySm.c(AppColors.onSurfaceVariant))) : null,
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: Text(labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: T.labelSm.c(highlightLast && i == labels.length - 1 ? AppColors.onSurface : AppColors.onSurfaceVariant)),
            ),
        ]),
      ]);
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.values, this.color, this.goal, this.highlightLast, this.grid, this.empty);
  final List<double> values;
  final Color color;
  final double? goal;
  final bool highlightLast;
  final Color grid;
  final Color empty;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final top = math.max(values.fold<double>(0, math.max), goal ?? 0);
    final maxV = top <= 0 ? 1.0 : top * 1.12;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = size.height * (1 - f) - (f == 0 ? 0.5 : 0);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final slot = size.width / values.length;
    final w = math.min(28.0, slot * 0.56);
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      final cx = slot * i + slot / 2;
      final h = v <= 0 ? 3.0 : math.max(3.0, size.height * (v / maxV));
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - w / 2, size.height - h, w, h),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      final strong = !highlightLast || i == values.length - 1;
      canvas.drawRRect(rect, Paint()..color = v <= 0 ? empty : (strong ? color : color.withValues(alpha: 0.45)));
    }
    if (goal != null && goal! > 0) {
      final y = size.height * (1 - goal! / maxV);
      final dash = Paint()
        ..color = AppColors.onSurfaceVariant
        ..strokeWidth = 1.2;
      double x = 0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, size.width), y), dash);
        x += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.values != values || old.color != color || old.goal != goal;
}

/// Compact line trend for a handful of points (e.g. one per term).
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
        child: CustomPaint(painter: _SparkPainter(values, color, baseline, showDots, highlightLast, AppColors.surfaceContainerLowest, AppColors.outlineVariant)),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values, this.color, this.baseline, this.dots, this.highlightLast, this.ground, this.grid);
  final List<double> values;
  final Color color;
  final double? baseline;
  final bool dots;
  final bool highlightLast;
  final Color ground;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final vs = values.length == 1 ? [values.first, values.first] : values;
    final maxV = math.max(vs.reduce(math.max), baseline ?? -double.infinity);
    final minV = math.min(vs.reduce(math.min), baseline ?? double.infinity);
    final span = (maxV - minV).abs() < 1e-6 ? 1.0 : (maxV - minV);
    const pad = 6.0;
    Offset pt(int i, double v) => Offset(
          pad + (size.width - 2 * pad) * i / (vs.length - 1),
          pad + (size.height - 2 * pad) * (1 - (v - minV) / span),
        );
    final pts = [for (int i = 0; i < vs.length; i++) pt(i, vs[i])];
    if (baseline != null) {
      final y = pt(0, baseline!).dy;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), Paint()
        ..color = grid
        ..strokeWidth = 1);
    }
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      line.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = color);
    if (dots) {
      for (final p in pts) {
        canvas.drawCircle(p, 4, Paint()..color = ground);
        canvas.drawCircle(p, 4, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color);
      }
    }
    if (highlightLast) canvas.drawCircle(pts.last, 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values || old.color != color;
}
