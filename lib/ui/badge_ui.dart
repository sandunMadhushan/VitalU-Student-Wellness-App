import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_state.dart';
import '../core/badges.dart';
import '../core/sfx.dart';
import '../data/catalog.dart';
import 'text.dart';
import 'tokens.dart';
import 'widgets.dart';

/// Streak badges are complete medal illustrations of their own
/// (`assets/badges/<code>.webp`); [_bySex] ones are drawn for the student's
/// sex (`assets/badges/<code>_<female|male>.webp`).
const _illustrated = {'aqua_achiever', 'rainbow_plate', 'active_aura', 'smart_eater'};
const _bySex = {'active_aura'};

String _illustratedAsset(String code) =>
    _bySex.contains(code) ? 'assets/badges/${code}_${AppState.instance.profile?.sex == 'male' ? 'male' : 'female'}.webp' : 'assets/badges/$code.webp';

/// The badge's signature colour: streak badges use their tracker's colour,
/// the rest follow their milestone category.
Color badgeColor(String code, [String? category]) => switch (code) {
      'aqua_achiever' || 'hydration_habit' => AppColors.water,
      'rainbow_plate' || 'plate_harmony' || 'nourish_bowl' || 'smart_eater' => AppColors.nutrition,
      'active_aura' => AppColors.nutrition,
      'gentle_steps' || 'campus_stroll' => AppColors.activity,
      'restful_sleep' => AppColors.sleep,
      'mindful_breath' || 'exam_refuge' => AppColors.mind,
      'heart_minded' => AppColors.heart,
      'cycle_harmony' => AppColors.cycle,
      _ => switch (category) {
          'nourish' => AppColors.nutrition,
          'rest' => AppColors.sleep,
          _ => AppColors.primary,
        },
    };

/// A medal: ribbon tails, a gradient rim and the badge's mascot or icon in
/// the middle. Locked badges are shown desaturated.
class BadgeArt extends StatelessWidget {
  const BadgeArt({super.key, required this.code, this.icon, this.category, this.size = 64, this.locked = false, this.ribbon = true});
  final String code;
  final String? icon;
  final String? category;
  final double size;
  final bool locked;
  final bool ribbon;

  @override
  Widget build(BuildContext context) {
    final c = badgeColor(code, category);
    final light = Color.lerp(c, Colors.white, 0.45)!;
    Widget medal = _illustrated.contains(code)
        ? SizedBox(
            width: size,
            height: size * (ribbon ? 1.18 : 1),
            child: Image.asset(_illustratedAsset(code), fit: BoxFit.contain, alignment: Alignment.topCenter),
          )
        : SizedBox(
      width: size,
      height: size * (ribbon ? 1.18 : 1),
      child: Stack(alignment: Alignment.topCenter, clipBehavior: Clip.none, children: [
        if (ribbon) Positioned(top: size * 0.55, child: CustomPaint(size: Size(size * 0.62, size * 0.62), painter: _RibbonPainter(c))),
        Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size * 0.075),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [light, c]),
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: size * 0.18, offset: Offset(0, size * 0.06), spreadRadius: -size * 0.04)],
          ),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.alphaBlend(c.withValues(alpha: 0.12), Colors.white),
              border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: size * 0.025),
            ),
            padding: EdgeInsets.all(size * 0.18),
            child: FittedBox(child: Icon(iconByName(icon), color: c, fill: 1)),
          ),
        ),
      ]),
    );
    if (locked) {
      medal = Opacity(
        opacity: 0.55,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix([0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0, 0, 0, 1, 0]),
          child: medal,
        ),
      );
    }
    return medal;
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    Path tail(double x0, double tilt) => Path()
      ..moveTo(x0, 0)
      ..lineTo(x0 + w * 0.42, 0)
      ..lineTo(x0 + w * 0.42 + tilt, h)
      ..lineTo(x0 + w * 0.21 + tilt, h * 0.8)
      ..lineTo(x0 + tilt, h)
      ..close();
    final dark = Color.lerp(color, Colors.black, 0.18)!;
    canvas.drawPath(tail(w * 0.04, -w * 0.12), Paint()..color = dark);
    canvas.drawPath(tail(w * 0.54, w * 0.12), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RibbonPainter old) => old.color != color;
}

/// Three stars, lit up to [filled], optionally animating in one by one.
class StreakStars extends StatelessWidget {
  const StreakStars({super.key, required this.filled, this.count = 3, this.size = 26, this.labels = true, this.animate = false});
  final int filled;
  final int count;
  final double size;
  final bool labels;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final gold = const Color(0xFFF5B321);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (int i = 0; i < count; i++) ...[
        if (i > 0) SizedBox(width: count > 3 ? size * 0.12 : size * 0.4),
        Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: animate ? 0 : 1, end: 1),
            duration: Duration(milliseconds: 420 + 260 * i),
            curve: Interval((i * 0.9 / count).clamp(0.0, 0.9), 1, curve: Curves.elasticOut),
            builder: (_, v, _) {
              final on = i < filled;
              return Transform.scale(
                scale: on ? (0.4 + 0.6 * v) : 1,
                child: Icon(Symbols.star_rounded, size: size, color: on ? gold : AppColors.outlineVariant, fill: on ? 1 : 0, weight: 600),
              );
            },
          ),
          if (labels) Text(count > 3 ? '${i + 1}' : 'Day ${i + 1}', style: T.labelSm.c(i < filled ? AppColors.onSurface : AppColors.onSurfaceVariant)),
        ]),
      ],
    ]);
  }
}

/// Card showing progress toward a streak badge: the badge itself with a
/// progress ring, three stars and how many days remain.
class StreakBadgeCard extends StatefulWidget {
  const StreakBadgeCard({super.key, required this.kind, this.version = 0});
  final StreakKind kind;

  /// Bump to reload (e.g. after the student logs something).
  final int version;

  @override
  State<StreakBadgeCard> createState() => _StreakBadgeCardState();
}

class _StreakBadgeCardState extends State<StreakBadgeCard> {
  StreakInfo? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StreakBadgeCard old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version) _load();
  }

  Future<void> _load() async {
    StreakInfo info;
    try {
      info = await Streaks.of(widget.kind);
    } catch (_) {
      info = const StreakInfo(streak: 0, todayDone: false, earned: false);
    }
    if (mounted) setState(() => _info = info);
  }

  @override
  Widget build(BuildContext context) {
    final b = StreakBadge.of(widget.kind);
    final c = badgeColor(b.code);
    final info = _info;
    final stars = info?.stars ?? 0;
    final earned = info?.earned ?? false;
    final String headline, line;
    if (info == null) {
      headline = b.title;
      line = 'Checking your streak…';
    } else if (earned) {
      headline = 'You earned ${b.title}!';
      line = info.streak > 0 ? 'Current streak: ${info.streak} ${info.streak == 1 ? 'day' : 'days'}. Keep it going.' : 'Start a new streak today. ${b.goal.toLowerCase()}.';
    } else if (stars == 0) {
      headline = 'Earn ${b.title}';
      line = '${b.goal} ${b.length} days in a row to unlock this badge.';
    } else {
      final left = info.remaining;
      headline = "You're on your way!";
      line = '$stars of ${b.length} days done. $left more ${left == 1 ? 'day' : 'days'} to earn ${b.title}.';
    }
    final dark = AppColors.isDark;
    return Material(
      color: Color.alphaBlend(c.withValues(alpha: dark ? 0.18 : 0.09), AppColors.surfaceContainerLowest),
      borderRadius: BorderRadius.circular(Rad.xl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/milestones'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          child: Row(children: [
            SizedBox(
              width: 92,
              height: 92,
              child: Stack(alignment: Alignment.center, children: [
                Ring(value: earned ? 1 : stars / b.length, size: 92, stroke: 5, color: c),
                BadgeArt(code: b.code, size: 72, ribbon: false),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(earned ? 'Badge earned' : '${b.length}-day badge streak', style: T.labelSm.c(c).w(FontWeight.w700).tracking(0.2)),
                const SizedBox(height: 2),
                Text(headline, style: T.headlineSm),
                const SizedBox(height: 2),
                Text(line, style: T.bodySm.c(AppColors.onSurfaceVariant)),
                const SizedBox(height: 8),
                StreakStars(filled: earned ? b.length : stars, count: b.length, size: b.length > 3 ? 17 : 22),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pop-ups
// ---------------------------------------------------------------------------

/// Full celebration for a newly earned badge: confetti, a springy pop-in
/// with a slowly turning burst behind it, and the fanfare.
Future<void> showBadgePopup(BuildContext context, {required String code, required String title, String? description, String? icon, String? category}) {
  HapticFeedback.heavyImpact();
  Sfx.fanfare();
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.55),
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    pageBuilder: (ctx, _, _) => _BadgePopup(code: code, title: title, description: description, icon: icon, category: category),
  );
}

class _BadgePopup extends StatefulWidget {
  const _BadgePopup({required this.code, required this.title, this.description, this.icon, this.category});
  final String code;
  final String title;
  final String? description;
  final String? icon;
  final String? category;
  @override
  State<_BadgePopup> createState() => _BadgePopupState();
}

class _BadgePopupState extends State<_BadgePopup> with TickerProviderStateMixin {
  late final _confetti = ConfettiController(duration: const Duration(milliseconds: 1400))..play();
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    _confetti.dispose();
    _pop.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = badgeColor(widget.code, widget.category);
    final scale = CurvedAnimation(parent: _pop, curve: Curves.elasticOut);
    return Stack(alignment: Alignment.topCenter, children: [
      Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            margin: const EdgeInsets.all(Sp.lg),
            padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.md),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(28)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Badge unlocked!', style: T.labelMd.c(c).w(FontWeight.w800).tracking(0.4)),
              const SizedBox(height: Sp.sm),
              SizedBox(
                width: 200,
                height: 190,
                child: Stack(alignment: Alignment.center, children: [
                  RotationTransition(turns: _spin, child: CustomPaint(size: const Size(200, 200), painter: _BurstPainter(c))),
                  ScaleTransition(
                    scale: scale,
                    child: RotationTransition(
                      turns: Tween(begin: -0.08, end: 0.0).animate(scale),
                      child: BadgeArt(code: widget.code, icon: widget.icon, category: widget.category, size: 128),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: Sp.sm),
              Text(widget.title, style: T.headlineLg, textAlign: TextAlign.center),
              if (widget.description != null) ...[
                const SizedBox(height: 6),
                Text(widget.description!, style: T.bodyMd.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
              ],
              const SizedBox(height: Sp.lg),
              PrimaryButton('Awesome!', color: c, onTap: () => Navigator.pop(context)),
              TextLinkButton('See all my badges', color: AppColors.onSurfaceVariant, onTap: () {
                Navigator.pop(context);
                GoRouter.of(context).push('/milestones');
              }),
            ]),
          ),
        ),
      ),
      ConfettiWidget(
        confettiController: _confetti,
        blastDirectionality: BlastDirectionality.explosive,
        emissionFrequency: 0.06,
        numberOfParticles: 22,
        maxBlastForce: 26,
        minBlastForce: 10,
        gravity: 0.25,
        colors: [c, const Color(0xFFF5B321), AppColors.cycle, AppColors.nutrition, AppColors.water, AppColors.mind],
      ),
    ]);
  }
}

/// Soft light rays behind a celebrated badge.
class _BurstPainter extends CustomPainter {
  _BurstPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r * 0.62, Paint()..shader = RadialGradient(colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r * 0.62)));
    final p = Paint()..color = color.withValues(alpha: 0.10);
    const n = 12;
    for (int i = 0; i < n; i++) {
      final a = 2 * math.pi * i / n;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * math.cos(a - 0.11), c.dy + r * math.sin(a - 0.11))
        ..lineTo(c.dx + r * math.cos(a + 0.11), c.dy + r * math.sin(a + 0.11))
        ..close();
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.color != color;
}

/// A smaller pop-up for a completed day on the way to a streak badge:
/// the stars light up and it says how many days are left.
Future<void> showStreakDayPopup(BuildContext context, StreakKind kind, StreakInfo info) {
  final b = StreakBadge.of(kind);
  final c = badgeColor(b.code);
  HapticFeedback.mediumImpact();
  final left = info.remaining;
  final title = info.earned ? '${info.streak}-day streak!' : 'Day ${info.stars} of ${b.length} complete!';
  final text = info.earned
      ? 'You already hold ${b.title}, and you are still going strong.'
      : '${b.dayDone}. $left more ${left == 1 ? 'day' : 'days'} in a row to earn ${b.title}.';
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.lg, Sp.lg, Sp.md),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(alignment: Alignment.center, children: [
                Ring(value: info.earned ? 1 : info.stars / b.length, size: 120, stroke: 7, color: c),
                BadgeArt(code: b.code, size: 94, ribbon: false),
              ]),
            ),
          ),
          const SizedBox(height: Sp.md),
          StreakStars(filled: info.earned ? b.length : info.stars, count: b.length, size: b.length > 3 ? 24 : 32, animate: true),
          const SizedBox(height: Sp.md),
          Text(title, style: T.headlineMd, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(text, style: T.bodyMd.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: Sp.lg),
          PrimaryButton('Keep going', color: c, onTap: () => Navigator.pop(ctx)),
        ]),
      ),
    ),
  );
}

/// Sits at the app root and celebrates every badge the server awards, one
/// at a time, on top of whatever screen is showing.
class BadgeCelebrationHost extends StatefulWidget {
  const BadgeCelebrationHost({super.key, required this.navigatorKey, required this.child});
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  @override
  State<BadgeCelebrationHost> createState() => _BadgeCelebrationHostState();
}

class _BadgeCelebrationHostState extends State<BadgeCelebrationHost> {
  StreamSubscription<List<String>>? _sub;
  final _queue = <String>[];
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _sub = BadgeCenter.earned.listen((codes) {
      _queue.addAll(codes);
      _drain();
    });
  }

  Future<void> _drain() async {
    if (_showing) return;
    _showing = true;
    while (_queue.isNotEmpty) {
      final code = _queue.removeAt(0);
      final meta = await BadgeCenter.meta(code);
      final ctx = widget.navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) break;
      await showBadgePopup(
        ctx,
        code: code,
        title: meta?['title'] ?? 'New badge',
        description: meta?['description'],
        icon: meta?['icon'],
        category: meta?['category'],
      );
    }
    _showing = false;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
