import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Card with a big value, −/+ steppers, a unit toggle and a slider.
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
    this.accent = AppColors.tertiary,
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
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return VCard(
      shadow: const [BoxShadow(color: Color(0x0A2D2B38), blurRadius: 28, offset: Offset(0, 12), spreadRadius: -8)],
      child: Column(children: [
        Row(children: [
          IconCircle(icon, size: 36, iconSize: 20, bg: AppColors.surfaceContainer, fg: accent),
          const SizedBox(width: Sp.xs + 2),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.headlineSm),
              if (subtitle != null) Text(subtitle!, style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          _UnitToggle(units: units, unit: unit, onUnit: onUnit, accent: accent),
        ]),
        const SizedBox(height: Sp.md),
        Row(children: [
          CircleButton(Symbols.remove, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, iconSize: 20, onTap: () => onChanged((value - step).clamp(min, max))),
          Expanded(
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(display, style: T.headlineXlMobile),
                const SizedBox(width: 4),
                Text(unitLabel, style: T.labelMd.c(AppColors.onSurfaceVariant)),
              ]),
              if (caption != null) Text(caption!, style: T.labelSm.c(AppColors.outline)),
            ]),
          ),
          CircleButton(Symbols.add, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, iconSize: 20, onTap: () => onChanged((value + step).clamp(min, max))),
        ]),
        const SizedBox(height: Sp.xs),
        VSlider(value: value, min: min, max: max, color: accent, onChanged: onChanged),
        if (scaleLabels != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final l in scaleLabels!) Text(l, style: T.labelSm.s(10).c(AppColors.outline))]),
          ),
      ]),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.units, required this.unit, required this.onUnit, required this.accent});
  final List<String> units;
  final String unit;
  final ValueChanged<String> onUnit;
  final Color accent;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(Rad.full)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final u in units)
            GestureDetector(
              onTap: () => onUnit(u),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: u == unit ? accent : Colors.transparent, borderRadius: BorderRadius.circular(Rad.full), boxShadow: u == unit ? Shadows.tiny : null),
                child: Text(u, style: T.labelSm.c(u == unit ? Colors.white : AppColors.onSurfaceVariant)),
              ),
            ),
        ]),
      );
}

class GaugeSegment {
  const GaugeSegment(this.color, this.flex, {this.from, this.to});
  final Color color;
  final double flex;
  final double? from;
  final double? to;
}

/// Segmented pastel spectrum with a "You: x" marker.
class SpectrumGauge extends StatelessWidget {
  const SpectrumGauge({super.key, required this.segments, required this.position, required this.markerLabel, this.labels = const [], this.height = 12});
  final List<GaugeSegment> segments;

  /// 0..1 across the full bar.
  final double position;
  final String markerLabel;
  final List<Widget> labels;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const SizedBox(height: 30),
      LayoutBuilder(builder: (context, c) {
        final x = (position.clamp(0.02, 0.98)) * c.maxWidth;
        return Stack(clipBehavior: Clip.none, children: [
          Container(
            height: height,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(height)),
            child: Row(children: [
              for (int i = 0; i < segments.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  flex: (segments[i].flex * 100).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: segments[i].color,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(i == 0 ? height : 0),
                        right: Radius.circular(i == segments.length - 1 ? height : 0),
                      ),
                    ),
                  ),
                ),
              ]
            ]),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            left: x - 40,
            top: -30,
            width: 80,
            child: Column(children: [
              Pill(
                color: AppColors.inverseSurface,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                shadow: Shadows.tiny,
                child: Text(markerLabel, style: T.labelSm.s(10).c(AppColors.inverseOnSurface)),
              ),
              CustomPaint(size: const Size(8, 5), painter: _Tri()),
            ]),
          ),
        ]);
      }),
      if (labels.isNotEmpty) ...[
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: labels),
      ],
    ]);
  }
}

class _Tri extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    canvas.drawPath(p, Paint()..color = AppColors.inverseSurface);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

Widget gaugeLabel(String t, {Color? color, bool bold = false}) => Text(t, style: T.labelSm.s(10).c(color ?? AppColors.onSurfaceVariant).w(bold ? FontWeight.w600 : FontWeight.w500));

/// "🔒 Confidential • Self-Check Tool" + help icon row.
class ToolSubBar extends StatelessWidget {
  const ToolSubBar({super.key, this.label = 'Confidential • Self-Check Tool', this.onHelp, this.icon = Symbols.shield_with_heart});
  final String label;
  final VoidCallback? onHelp;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(children: [
        TagPill(label, icon: icon, fill: 1, fg: AppColors.tertiary),
        const Spacer(),
        if (onHelp != null) CircleButton(Symbols.help, size: 32, iconSize: 18, bg: AppColors.surfaceContainerLowest, shadow: Shadows.tiny, onTap: onHelp),
      ]);
}

Future<void> showInfoSheet(BuildContext context, {required String title, required List<String> paragraphs, IconData icon = Symbols.info}) {
  return showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconCircle(icon, bg: AppColors.primaryFixed),
        const SizedBox(height: Sp.sm),
        Text(title, style: T.headlineMd),
        const SizedBox(height: Sp.sm),
        for (final p in paragraphs) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(p, style: T.bodyMd.c(AppColors.onSurfaceVariant))),
        const SizedBox(height: Sp.sm),
        PrimaryButton('Got it', onTap: () => Navigator.pop(ctx)),
      ]));
}
