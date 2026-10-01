import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Measurement card: title with a unit switch, a large value with −/+ and a slider.
class StepperMeasureCard extends StatelessWidget {
  const StepperMeasureCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.display,
    required this.unitLabel,
    required this.units,
    required this.unit,
    required this.onUnit,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.caption,
    this.scaleLabels,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String display;
  final String unitLabel;
  final List<String> units;
  final String unit;
  final ValueChanged<String> onUnit;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String? caption;
  final List<String>? scaleLabels;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.body;
    Widget stepBtn(IconData i, double delta) => IconButton.outlined(
          onPressed: () => onChanged((value + delta).clamp(min, max)),
          icon: Icon(i, size: 20),
          style: IconButton.styleFrom(side: BorderSide(color: AppColors.outlineVariant), foregroundColor: AppColors.onSurface),
        );
    return VCard(
      child: Column(children: [
        Row(children: [
          Expanded(child: CategoryLabel(title, icon: icon, color: c)),
          Segmented(options: units, value: unit, onChanged: onUnit),
        ]),
        if (subtitle != null) Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: T.bodySm.c(AppColors.onSurfaceVariant)))),
        const SizedBox(height: Sp.md),
        Row(children: [
          stepBtn(Symbols.remove_rounded, -step),
          Expanded(
            child: Column(children: [
              MetricValue(display, unit: unitLabel.isEmpty ? null : unitLabel, size: 36),
              if (caption != null) Text(caption!, style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          stepBtn(Symbols.add_rounded, step),
        ]),
        const SizedBox(height: Sp.xs),
        VSlider(value: value, min: min, max: max, color: c, onChanged: onChanged),
        if (scaleLabels != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final l in scaleLabels!) Text(l, style: T.labelSm.c(AppColors.onSurfaceVariant))]),
          ),
      ]),
    );
  }
}

class GaugeSegment {
  const GaugeSegment(this.color, this.flex, {this.from, this.to});
  final Color color;
  final double flex;
  final double? from;
  final double? to;
}

/// Segmented range bar with a marker for the student's value.
class SpectrumGauge extends StatelessWidget {
  const SpectrumGauge({super.key, required this.segments, required this.position, required this.markerLabel, this.labels = const [], this.height = 10});
  final List<GaugeSegment> segments;

  /// 0..1 across the full bar.
  final double position;
  final String markerLabel;
  final List<Widget> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      LayoutBuilder(builder: (context, c) {
        final x = position.clamp(0.0, 1.0) * c.maxWidth;
        return Stack(clipBehavior: Clip.none, children: [
          Padding(
            padding: const EdgeInsets.only(top: 26),
            child: Row(children: [
              for (int i = 0; i < segments.length; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                Expanded(
                  flex: (segments[i].flex * 100).round(),
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: segments[i].color,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(i == 0 ? height : 2),
                        right: Radius.circular(i == segments.length - 1 ? height : 2),
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: (x - 40).clamp(-8.0, c.maxWidth - 72),
            top: 0,
            width: 80,
            child: Column(children: [
              Text(markerLabel, style: T.labelSm.semi.tnum),
              const SizedBox(height: 2),
              Container(width: 2, height: 8 + height, color: AppColors.onSurface),
            ]),
          ),
        ]);
      }),
      if (labels.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: labels),
      ],
    ]);
  }
}

Widget gaugeLabel(String t, {Color? color, bool bold = false}) => Text(t, style: T.labelSm.c(color ?? AppColors.onSurfaceVariant).w(bold ? FontWeight.w600 : FontWeight.w500));

/// Privacy line plus a "How it works" link for self-check tools.
class ToolSubBar extends StatelessWidget {
  const ToolSubBar({super.key, this.label = 'Private self-check', this.onHelp, this.icon = Symbols.lock_rounded});
  final String label;
  final VoidCallback? onHelp;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: T.bodySm.c(AppColors.onSurfaceVariant))),
        if (onHelp != null) TextLinkButton('How it works', leading: Symbols.info_rounded, onTap: onHelp),
      ]);
}

/// An empty bottle outline that animates its fill level, for hydration
/// progress. [value] is 0..1+ (values over 1 show the bottle full, with the
/// overflow reflected only in the label the caller shows alongside it).
class AnimatedWaterBottle extends StatelessWidget {
  const AnimatedWaterBottle({super.key, required this.value, this.width = 64, this.height = 132, this.color});
  final double value;
  final double width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.water;
    return SizedBox(
      width: width,
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => CustomPaint(painter: _BottlePainter(v, c, AppColors.surfaceContainerHigh)),
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  _BottlePainter(this.fill, this.color, this.track);
  final double fill;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final neckW = w * 0.34, neckH = h * 0.12, bodyTop = neckH + h * 0.05, r = w * 0.16;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(0, bodyTop, w, h - bodyTop), Radius.circular(r));
    final neck = RRect.fromRectAndRadius(Rect.fromLTWH((w - neckW) / 2, 0, neckW, neckH + 4), Radius.circular(w * 0.06));

    canvas.drawRRect(neck, Paint()..color = track);
    canvas.drawRRect(body, Paint()..color = track);

    canvas.save();
    canvas.clipRRect(body);
    final fillTop = (h - bodyTop) * (1 - fill) + bodyTop;
    canvas.drawRect(Rect.fromLTWH(0, fillTop, w, h - fillTop), Paint()..color = color);
    if (fill > 0.02) {
      final wave = Path()
        ..moveTo(0, fillTop + 2)
        ..quadraticBezierTo(w * 0.25, fillTop - 3, w * 0.5, fillTop + 2)
        ..quadraticBezierTo(w * 0.75, fillTop + 7, w, fillTop + 2)
        ..lineTo(w, fillTop)
        ..lineTo(0, fillTop)
        ..close();
      canvas.drawPath(wave, Paint()..color = color.withValues(alpha: 0.7));
    }
    canvas.restore();

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppColors.outlineVariant;
    canvas.drawRRect(body, outline);
    canvas.drawRRect(neck, outline);
    canvas.drawLine(Offset((w - neckW) / 2, neckH - 2), Offset((w + neckW) / 2, neckH - 2), Paint()..color = AppColors.outlineVariant..strokeWidth = 2.5);
  }

  @override
  bool shouldRepaint(covariant _BottlePainter old) => old.fill != fill || old.color != color;
}

Future<void> showInfoSheet(BuildContext context, {required String title, required List<String> paragraphs, IconData icon = Symbols.info_rounded}) {
  return showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: T.headlineMd),
        const SizedBox(height: Sp.md),
        for (final p in paragraphs) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(p, style: T.bodyLg.c(AppColors.onSurfaceVariant))),
        const SizedBox(height: Sp.sm),
        PrimaryButton('Done', onTap: () => Navigator.pop(ctx)),
      ]));
}
