import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// A water bottle that fills to [value] (0..1+; anything over 1 shows it
/// full). The surface keeps a gentle moving wave, and every time the level
/// rises the bottle hops, squashes and fizzes with bubbles, so logging a
/// glass feels like it landed somewhere.
class AnimatedWaterBottle extends StatefulWidget {
  const AnimatedWaterBottle({super.key, required this.value, this.width = 64, this.height = 132, this.color});
  final double value;
  final double width;
  final double height;
  final Color? color;

  @override
  State<AnimatedWaterBottle> createState() => _AnimatedWaterBottleState();
}

class _AnimatedWaterBottleState extends State<AnimatedWaterBottle> with TickerProviderStateMixin {
  late final _wave = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
  late final _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final _fill = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  double _from = 0;
  late double _to = widget.value.clamp(0, 1).toDouble();

  @override
  void initState() {
    super.initState();
    _fill.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant AnimatedWaterBottle old) {
    super.didUpdateWidget(old);
    final next = widget.value.clamp(0, 1).toDouble();
    if (next != _to) {
      _from = _level;
      _to = next;
      _fill.forward(from: 0);
      if (widget.value > old.value) _hop.forward(from: 0);
    }
  }

  double get _level => _from + (_to - _from) * Curves.easeOutCubic.transform(_fill.value);

  @override
  void dispose() {
    _wave.dispose();
    _hop.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color ?? AppColors.water;
    return SizedBox(
      width: widget.width,
      height: widget.height + 14,
      child: AnimatedBuilder(
        animation: Listenable.merge([_wave, _hop, _fill]),
        builder: (_, _) {
          final h = _hop.value;
          // Hop up, land with a squash, settle.
          final lift = h < 0.45 ? math.sin(h / 0.45 * math.pi) * 12 : 0.0;
          final squash = h >= 0.45 && h < 0.75 ? math.sin((h - 0.45) / 0.3 * math.pi) * 0.07 : 0.0;
          // The surface sloshes harder right after a pour, then calms down.
          final slosh = 1 + 3.5 * (1 - h) * (_hop.isAnimating ? 1 : 0);
          return Transform.translate(
            offset: Offset(0, 14 - lift),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(1 + squash, 1 - squash, 1),
              child: CustomPaint(
                size: Size(widget.width, widget.height),
                painter: _BottlePainter(_level, c, AppColors.surfaceContainerHigh, AppColors.outlineVariant, _wave.value, slosh, _hop.isAnimating ? h : null),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BottlePainter extends CustomPainter {
  _BottlePainter(this.fill, this.color, this.track, this.outline, this.phase, this.amp, this.burst);
  final double fill;
  final Color color;
  final Color track;
  final Color outline;
  final double phase;
  final double amp;

  /// 0..1 progress of the bubble burst after a pour, or null when idle.
  final double? burst;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final neckW = w * 0.34, neckH = h * 0.12, bodyTop = neckH + h * 0.05, r = w * 0.18;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(0, bodyTop, w, h - bodyTop), Radius.circular(r));
    final neck = RRect.fromRectAndRadius(Rect.fromLTWH((w - neckW) / 2, 0, neckW, neckH + 4), Radius.circular(w * 0.06));
    final cap = RRect.fromRectAndRadius(Rect.fromLTWH((w - neckW * 1.15) / 2, -h * 0.05, neckW * 1.15, h * 0.07), Radius.circular(w * 0.05));

    canvas.drawRRect(neck, Paint()..color = track);
    canvas.drawRRect(body, Paint()..color = track);

    canvas.save();
    canvas.clipRRect(body);
    final fillTop = (h - bodyTop) * (1 - fill) + bodyTop;
    if (fill > 0.005) {
      Path wave(double shift, double a) {
        final p = Path()..moveTo(0, h);
        for (double x = 0; x <= w; x += 2) {
          p.lineTo(x, fillTop + math.sin((x / w * 2 * math.pi) + shift) * a);
        }
        return p
          ..lineTo(w, h)
          ..close();
      }

      final t = phase * 2 * math.pi;
      canvas.drawPath(wave(t + math.pi, 2.2 * amp), Paint()..color = color.withValues(alpha: 0.45));
      canvas.drawPath(
        wave(t, 1.8 * amp),
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.lerp(color, Colors.white, 0.25)!, color])
              .createShader(Rect.fromLTWH(0, fillTop, w, h - fillTop)),
      );
      // Rising bubbles after a pour.
      final b = burst;
      if (b != null) {
        final bubble = Paint()..color = Colors.white.withValues(alpha: 0.55 * (1 - b));
        for (int i = 0; i < 7; i++) {
          final x = w * (0.18 + 0.64 * ((i * 37) % 100) / 100);
          final y = h - (h - fillTop) * ((b * 1.3 + i * 0.13) % 1.0);
          canvas.drawCircle(Offset(x + math.sin(b * 8 + i) * 3, y), 1.6 + (i % 3), bubble);
        }
      }
      // Soft glass highlight.
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, bodyTop + h * 0.08, w * 0.09, h * 0.5), Radius.circular(w)),
        Paint()..color = Colors.white.withValues(alpha: 0.22),
      );
    }
    canvas.restore();

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = outline;
    canvas.drawRRect(body, stroke);
    canvas.drawRRect(neck, stroke);
    canvas.drawRRect(cap, Paint()..color = color.withValues(alpha: 0.85));
    canvas.drawLine(Offset((w - neckW) / 2, neckH - 2), Offset((w + neckW) / 2, neckH - 2), Paint()
      ..color = outline
      ..strokeWidth = 2.5);
    // Measuring ticks at 25 / 50 / 75 %.
    for (final q in const [0.25, 0.5, 0.75]) {
      final y = bodyTop + (h - bodyTop) * (1 - q);
      canvas.drawLine(Offset(w - w * 0.2, y), Offset(w - w * 0.08, y), Paint()
        ..color = outline
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _BottlePainter old) => true;
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

/// The validated tool a screen is based on, with its citation and a link.
class ToolReference extends StatelessWidget {
  const ToolReference({super.key, required this.tool, required this.citation, this.url, this.note});
  final String tool;
  final String citation;
  final String? url;
  final String? note;

  @override
  Widget build(BuildContext context) => VCard(
        color: AppColors.surfaceContainerLow,
        flat: true,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Symbols.menu_book_rounded, size: 20, color: AppColors.primary, fill: 1),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Based on $tool', style: T.labelLg.semi),
              const SizedBox(height: 2),
              Text(citation, style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.4)),
              if (note != null) ...[
                const SizedBox(height: 4),
                Text(note!, style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.4)),
              ],
              if (url != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: TextLinkButton('View reference', icon: Symbols.open_in_new_rounded, onTap: () => launchUrl(Uri.parse(url!), mode: LaunchMode.externalApplication)),
                ),
            ]),
          ),
        ]),
      );
}
