import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_state.dart';
import '../../core/push.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';

/// Heart colours from the app icon. [splashCoral] also fills the native
/// launch screens and the web loader (web/index.html), so the hand-off into
/// this animation is seamless.
const splashCoral = Color(0xFFFD513B);
const _rimTop = Color(0xFFF2442F);
const _rimBottom = Color(0xFFD62E22);
const _ink = Color(0xFF1B1B1F);

/// Opening animation. The screen starts filled by the VitalU heart, whose face
/// looks around; the view pulls back to show the whole heart, it gives two
/// beats, then the name fades in on a soft aurora while the app works out
/// where to go. If loading takes longer, the heart keeps beating.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2900));
  late final AnimationController _idle =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  final _started = DateTime.now();
  String? _next;
  bool _begun = false;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      if (_next == null) _idle.repeat();
      _go();
    });
    _route();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_begun) return;
    _begun = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _idle.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    if (AppState.instance.signedIn) {
      final p = AppState.instance.profile ?? await AppState.instance.loadProfile();
      _next = p == null ? '/home' : p.landingRoute;
    } else {
      _next = seenOnboarding ? '/auth/create' : '/onboarding';
    }
    _go();
  }

  Future<void> _go() async {
    final next = _next;
    if (_gone || next == null || !_intro.isCompleted) return;
    _gone = true;
    final wait = const Duration(milliseconds: 900) - DateTime.now().difference(_started);
    if (wait > Duration.zero) await Future.delayed(wait);
    if (!mounted) return;
    context.go(next);
    // Opened by tapping a phone notification: land on its screen.
    final launch = AppState.instance.signedIn ? Push.takeLaunchRoute() : null;
    if (launch != null && next == '/home') context.push(launch);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_intro, _idle]),
      builder: (context, _) {
        final t = _intro.value;
        final covered = t < 0.42; // status bar still sits on the coral heart
        final style = covered || AppColors.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;
        final words = _iv(t, .70, .92, Curves.easeOutCubic);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: style.copyWith(statusBarColor: Colors.transparent),
          child: Scaffold(
            backgroundColor: AppColors.surface,
            body: LayoutBuilder(builder: (context, box) {
              final size = box.biggest;
              final m = _Mascot(size, t, _idle.isAnimating ? _idle.value : 0);
              return Stack(children: [
                Positioned.fill(child: CustomPaint(painter: _SplashPainter(m, AppColors.isDark))),
                Positioned(
                  left: 24,
                  right: 24,
                  top: m.restCenter.dy + m.u * 1.15 + 30,
                  child: Opacity(
                    opacity: words,
                    child: Transform.translate(
                      offset: Offset(0, (1 - words) * 18),
                      child: Column(children: [
                        Text('VitalU', style: T.headlineXl, textAlign: TextAlign.center),
                        const SizedBox(height: 6),
                        Text('Student health, in one place',
                            style: T.bodyLg.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                ),
              ]);
            }),
          ),
        );
      },
    );
  }
}

/// Progress of [t] through the interval [a, b], eased.
double _iv(double t, double a, double b, [Curve curve = Curves.linear]) =>
    curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

/// Where the heart and its face are at a given moment of the animation.
/// Heart coordinates: about -1..1 across, face centre at [_face].
class _Mascot {
  _Mascot(this.size, double t, double idle) {
    u = math.min(size.width, 400) * 0.19;
    zoom = _iv(t, .30, .52, Curves.easeInOutCubic);
    lift = _iv(t, .66, .88, Curves.easeInOutCubic);
    restCenter = Offset(size.width / 2, lerpDouble(size.height * .45, size.height * .38, lift)!);

    // The view starts zoomed far into the heart so it fills the screen.
    final halfDiag = size.shortestSide == 0 ? 1.0 : size.longestSide * 0.75;
    final big = halfDiag / (u * 0.26);
    scale = math.exp(lerpDouble(math.log(big), 0, zoom)!);
    faceScale = lerpDouble(2.3, 1, zoom)!;
    final faceRest = restCenter + Offset(0, _face.dy * u);
    facePos = Offset.lerp(size.center(Offset.zero), faceRest, zoom)!;

    // Two beats once the heart is in view, then a slow beat while waiting.
    final b = _iv(t, .52, .70);
    final squash = 0.075 * math.sin(b * math.pi * 4) * (1 - b * .6) + 0.045 * math.sin(idle * math.pi * 2);
    sx = 1 + squash;
    sy = 1 - squash * .8;
    leaf = -0.5 + 0.35 * math.sin(b * math.pi * 3) * (1 - b) + 0.08 * math.sin(idle * math.pi * 2);

    // Eyes: look left, look right, back, with blinks along the way.
    final look = _iv(t, .05, .10, Curves.easeOut) * -1 +
        _iv(t, .15, .21, Curves.easeInOut) * 2 -
        _iv(t, .27, .31, Curves.easeInOut);
    lookAt = Offset(look, _iv(t, .74, .86, Curves.easeInOut) * .55);
    double blink(double at) => 1 - math.sin(_iv(t, at, at + .045) * math.pi);
    open = math.min(blink(.235), math.min(blink(.60), blink(.90)));
    shadow = _iv(t, .42, .56);
  }

  static const _face = Offset(0, 0.1);

  final Size size;
  late final double u, zoom, lift, scale, faceScale, sx, sy, leaf, open, shadow;
  late final Offset restCenter, facePos, lookAt;
}

class _SplashPainter extends CustomPainter {
  _SplashPainter(this.m, this.dark);
  final _Mascot m;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    // Keep all drawing inside the screen: early on the heart is many times
    // larger than the screen, and unclipped it is very slow to rasterise.
    canvas.clipRect(Offset.zero & size);
    if (m.zoom < .02) {
      // The screen is still entirely inside the heart.
      canvas.drawColor(splashCoral, BlendMode.src);
      _faceDraw(canvas);
      return;
    }
    _aurora(canvas, size);

    canvas.save();
    canvas.translate(m.facePos.dx, m.facePos.dy);
    canvas.scale(m.scale * m.u);
    canvas.translate(-_Mascot._face.dx, -_Mascot._face.dy);

    // Soft shadow on the ground.
    if (m.shadow > 0) {
      final c = Colors.black.withValues(alpha: (dark ? .4 : .14) * m.shadow);
      final r = Rect.fromCircle(center: Offset.zero, radius: .75);
      canvas.save();
      canvas.translate(0, 1.16);
      canvas.scale(m.sx, .14);
      canvas.drawOval(r, Paint()..shader = RadialGradient(colors: [c, c.withValues(alpha: 0)]).createShader(r));
      canvas.restore();
    }

    // Squash and stretch about the heart's base.
    canvas.translate(0, .95);
    canvas.scale(m.sx, m.sy);
    canvas.translate(0, -.95);

    _leaf(canvas);
    final heart = _heart();
    canvas.drawPath(
      heart,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_rimTop, _rimBottom],
        ).createShader(const Rect.fromLTRB(-1, -1, 1, 1)),
    );
    canvas.save();
    canvas.translate(0, .19);
    canvas.scale(.8);
    canvas.translate(0, -.19);
    canvas.drawPath(heart, Paint()..color = splashCoral);
    canvas.restore();
    // Gloss on the left lobe.
    canvas.save();
    canvas.translate(-.52, -.42);
    canvas.rotate(-.7);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: .3, height: .13),
        Paint()..color = Colors.white.withValues(alpha: .38));
    canvas.restore();
    canvas.restore();

    _faceDraw(canvas);
  }

  /// A chubby heart, about 2 units wide.
  Path _heart() => Path()
    ..moveTo(0, -.42)
    ..cubicTo(-.06, -.86, -.62, -1.0, -.9, -.62)
    ..cubicTo(-1.16, -.27, -.98, .2, -.6, .52)
    ..cubicTo(-.38, .72, -.16, .86, 0, .95)
    ..cubicTo(.16, .86, .38, .72, .6, .52)
    ..cubicTo(.98, .2, 1.16, -.27, .9, -.62)
    ..cubicTo(.62, -1.0, .06, -.86, 0, -.42)
    ..close();

  /// The mint leaf from the icon, sprouting from the notch.
  void _leaf(Canvas canvas) {
    canvas.save();
    canvas.translate(.02, -.5);
    canvas.rotate(m.leaf);
    final stem = Paint()
      ..color = const Color(0xFF3F8F3A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .06
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, .08), const Offset(0, -.14), stem);
    final leaf = Path()
      ..moveTo(0, -.12)
      ..quadraticBezierTo(-.3, -.32, 0, -.66)
      ..quadraticBezierTo(.3, -.32, 0, -.12)
      ..close();
    canvas.drawPath(
      leaf,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFA6DA4B), Color(0xFF5BAE3A)],
        ).createShader(const Rect.fromLTRB(-.3, -.66, .3, -.12)),
    );
    canvas.drawLine(
      const Offset(0, -.16),
      const Offset(0, -.56),
      Paint()
        ..color = const Color(0xFF3F8F3A).withValues(alpha: .55)
        ..strokeWidth = .025
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _faceDraw(Canvas canvas) {
    canvas.save();
    canvas.translate(m.facePos.dx, m.facePos.dy);
    canvas.scale(m.faceScale * m.u);
    for (final x in [-.3, .3]) {
      final c = Offset(x, 0);
      final eye = Rect.fromCenter(center: c, width: .3, height: .3 * math.max(m.open, .06));
      canvas.drawOval(eye, Paint()..color = Colors.white);
      canvas.save();
      canvas.clipPath(Path()..addOval(eye));
      final p = c + Offset(m.lookAt.dx * .05, m.lookAt.dy * .04);
      canvas.drawCircle(p, .095, Paint()..color = _ink);
      canvas.drawCircle(p + const Offset(.03, -.03), .025, Paint()..color = Colors.white);
      canvas.restore();
    }
    final smile = Path()
      ..moveTo(-.085, .07)
      ..quadraticBezierTo(0, .16, .085, .07);
    canvas.drawPath(
      smile,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = .045
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  /// Pastel glow that fades in behind the name.
  void _aurora(Canvas canvas, Size size) {
    final a = m.lift;
    if (a <= 0) return;
    final k = (dark ? .26 : .55) * a;
    void blob(Offset c, double r, Color col) => canvas.drawCircle(
          c,
          r,
          Paint()
            ..shader = RadialGradient(colors: [col.withValues(alpha: k), col.withValues(alpha: 0)])
                .createShader(Rect.fromCircle(center: c, radius: r)),
        );
    final w = size.width, h = size.height;
    blob(Offset(w * .05, h * .08), w * .9, dark ? const Color(0xFFFD513B) : const Color(0xFFFFC2A6));
    blob(Offset(w * .95, h * .12), w * .85, dark ? const Color(0xFF7C4DD6) : const Color(0xFFD9C8FF));
    blob(Offset(w * .85, h * .55), w * .8, dark ? const Color(0xFF0B7A63) : const Color(0xFFA8E8D3));
  }

  @override
  bool shouldRepaint(_SplashPainter old) => true;
}
