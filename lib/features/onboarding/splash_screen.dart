import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_state.dart';
import '../../ui/text.dart';
import '../../ui/widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final started = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool('seen_onboarding') ?? false;
    String next;
    if (AppState.instance.signedIn) {
      final p = AppState.instance.profile ?? await AppState.instance.loadProfile();
      next = (p == null || p.onboardingCompleted) ? '/home' : '/register/${(p.registrationStep + 1).clamp(1, 3)}';
    } else {
      next = seenOnboarding ? '/auth/create' : '/onboarding';
    }
    final elapsed = DateTime.now().difference(started);
    const minShow = Duration(milliseconds: 1800);
    if (elapsed < minShow) await Future.delayed(minShow - elapsed);
    if (mounted) context.go(next);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(-0.15, -1),
            end: Alignment(0.15, 1),
            colors: [Color(0xFFEDE4FF), Color(0xFFF5E8FB), Color(0xFFFFE5EE)],
            stops: [0, 0.48, 1],
          ),
        ),
        child: Stack(children: [
          const Positioned(top: -64, left: -64, child: Glow(color: Color(0x99E5D7FF), size: 288)),
          Positioned(top: MediaQuery.of(context).size.height / 3, right: -80, child: const Glow(color: Color(0xB3FFDCE5), size: 320)),
          const Positioned(bottom: -80, left: 40, child: Glow(color: Color(0xCCFCE5F4), size: 320)),
          SafeArea(
            child: Column(children: [
              const Spacer(),
              Container(
                width: 144,
                height: 144,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x144E2963), blurRadius: 36, offset: Offset(0, 16), spreadRadius: -6),
                    BoxShadow(color: Color(0x084E2963), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                child: const AssetImg('app_icon', fit: BoxFit.contain),
              ),
              const SizedBox(height: 28),
              Text('VitalU', style: T.custom(36, weight: FontWeight.w800, color: const Color(0xFF232032), height: 1, spacing: -0.8)),
              const SizedBox(height: 10),
              Text('Your health, made simple', style: T.custom(15, weight: FontWeight.w500, color: const Color(0xFF736E82), spacing: 0.4)),
              const Spacer(),
              SizedBox(
                height: 24,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      _dot((_pulse.value - i * 0.14) % 1),
                    ]
                  ]),
                ),
              ),
              const SizedBox(height: 48),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _dot(double t) {
    final wave = (math.sin(t * 2 * math.pi - math.pi / 2) + 1) / 2; // 0..1
    return Transform.translate(
      offset: Offset(0, -4 * wave),
      child: Transform.scale(
        scale: 0.9 + 0.25 * wave,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF7C6F92).withValues(alpha: 0.35 + 0.5 * wave)),
        ),
      ),
    );
  }
}
