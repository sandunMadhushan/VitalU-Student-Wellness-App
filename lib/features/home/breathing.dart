import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Box breathing: inhale 4 • hold 4 • exhale 4 • hold 4.
Future<void> showBreathing(BuildContext context, {String cta = 'Done'}) {
  return showDialog(context: context, builder: (_) => _BreathingDialog(cta: cta));
}

class _BreathingDialog extends StatefulWidget {
  const _BreathingDialog({required this.cta});
  final String cta;
  @override
  State<_BreathingDialog> createState() => _BreathingDialogState();
}

class _BreathingDialogState extends State<_BreathingDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  (String, double, int) _phase(double t) {
    final s = t * 16;
    final left = 4 - (s % 4).floor();
    if (s < 4) return ('Breathe in', 0.55 + 0.45 * Curves.easeInOut.transform(s / 4), left);
    if (s < 8) return ('Hold', 1.0, left);
    if (s < 12) return ('Breathe out', 1.0 - 0.45 * Curves.easeInOut.transform((s - 8) / 4), left);
    return ('Hold', 0.55, left);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.mind;
    return Dialog(
      insetPadding: const EdgeInsets.all(Sp.lg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text('Box breathing', style: T.headlineMd)),
            CircleButton(Symbols.close_rounded, iconSize: 22, fg: AppColors.onSurfaceVariant, onTap: () => Navigator.pop(context)),
          ]),
          Align(alignment: Alignment.centerLeft, child: Text('Four seconds in, hold, out, hold. Repeat a few rounds.', style: T.bodyMd.c(AppColors.onSurfaceVariant))),
          const SizedBox(height: Sp.lg),
          AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              final (label, scale, left) = _phase(_c.value);
              return SizedBox(
                width: 220,
                height: 220,
                child: Stack(alignment: Alignment.center, children: [
                  Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.outlineVariant, width: 1.5))),
                  Transform.scale(
                    scale: scale,
                    child: Container(width: 212, height: 212, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.tint(c))),
                  ),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(label, style: T.headlineSm.c(c)),
                    const SizedBox(height: 2),
                    Text('$left', style: T.metric(40).c(AppColors.onSurface)),
                  ]),
                ]),
              );
            },
          ),
          const SizedBox(height: Sp.lg),
          PrimaryButton(widget.cta, onTap: () => Navigator.pop(context)),
        ]),
      ),
    );
  }
}
