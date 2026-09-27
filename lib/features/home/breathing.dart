import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Paced (box) breathing overlay: inhale 4 • hold 4 • exhale 4 • hold 4.
Future<void> showBreathing(BuildContext context, {String cta = 'I feel ready to continue'}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Breathing',
    barrierColor: AppColors.onSurface.withValues(alpha: 0.35),
    pageBuilder: (ctx, _, __) => _BreathingDialog(cta: cta),
    transitionBuilder: (ctx, a, _, child) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child)),
  );
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

  (String, double) _phase(double t) {
    final s = t * 16;
    if (s < 4) return ('Inhale...', 0.6 + 0.4 * (s / 4));
    if (s < 8) return ('Hold gently', 1.0);
    if (s < 12) return ('Exhale slowly...', 1.0 - 0.4 * ((s - 8) / 4));
    return ('Rest', 0.6);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(Sp.margin),
          padding: const EdgeInsets.all(Sp.lg),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(36), boxShadow: Shadows.floating),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(alignment: Alignment.topRight, child: CircleButton(Symbols.close, size: 36, iconSize: 20, bg: AppColors.surfaceContainer, onTap: () => Navigator.pop(context))),
            const IconCircle(Symbols.air, bg: AppColors.skyWash, fg: AppColors.skyAccent),
            const SizedBox(height: Sp.sm),
            Text('Paced Breathing', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('Inhale calm, release campus pressure.', style: T.bodyMd.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: Sp.lg),
            AnimatedBuilder(
              animation: _c,
              builder: (_, __) {
                final (label, scale) = _phase(_c.value);
                return Column(children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(alignment: Alignment.center, children: [
                      Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [AppColors.pinkWash, AppColors.skyWash])),
                        ),
                      ),
                      Transform.scale(
                        scale: scale * 0.72,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.7), boxShadow: Shadows.soft),
                        ),
                      ),
                      Text(label, style: T.headlineSm.c(AppColors.primary)),
                    ]),
                  ),
                ]);
              },
            ),
            const SizedBox(height: Sp.lg),
            PrimaryButton(widget.cta, onTap: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }
}
