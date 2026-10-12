import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_state.dart';
import '../../core/push.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
      next = p == null ? '/home' : p.landingRoute;
    } else {
      next = seenOnboarding ? '/auth/create' : '/onboarding';
    }
    final elapsed = DateTime.now().difference(started);
    const minShow = Duration(milliseconds: 900);
    if (elapsed < minShow) await Future.delayed(minShow - elapsed);
    if (!mounted) return;
    context.go(next);
    // Opened by tapping a phone notification: land on its screen.
    final launch = AppState.instance.signedIn ? Push.takeLaunchRoute() : null;
    if (launch != null && next == '/home') context.push(launch);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      body: SafeArea(
        child: Column(children: [
          const Spacer(),
          const AppIconTile(size: 96),
          const SizedBox(height: Sp.md),
          Text('VitalU', style: T.headlineXl),
          const SizedBox(height: 4),
          Text('Student health, in one place', style: T.bodyLg.c(AppColors.onSurfaceVariant)),
          const Spacer(),
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(height: 48),
        ]),
      ),
    );
  }
}
