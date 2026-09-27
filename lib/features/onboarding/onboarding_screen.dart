import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ui/text.dart';
import '../../ui/widgets.dart';

class _Slide {
  const _Slide(this.image, this.title, this.text);
  final String image;
  final String title;
  final String text;
}

const _slides = [
  _Slide('onboarding_student', 'Understand Your Health, Simply', 'Track what matters, at your own pace — no long forms, no pressure.'),
  _Slide('nourishment_bowl', 'Eat Well on a Student Budget', 'Log meals, build a healthy plate and plan nourishing food that fits your week.'),
  _Slide('campus_safety', 'Private by Design, Support When Needed', 'Your daily tracking stays yours. Help and professionals are one gentle tap away.'),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const charcoal = Color(0xFF192E25);
  static const muted = Color(0xFF4A6359);
  static const darkMint = Color(0xFF1E5641);
  static const pillTrack = Color(0xFFC5E2D7);

  final _page = PageController();
  int _index = 0;

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);
    if (mounted) context.go('/auth/create');
  }

  void _next() {
    if (_index == _slides.length - 1) {
      _finish();
    } else {
      _page.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0FAF5), Color(0xFFE3F4EC), Color(0xFFD6EFE5)],
            stops: [0, 0.45, 1],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
              child: Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: darkMint.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: const Icon(Symbols.favorite, size: 14, color: darkMint, weight: 700),
                ),
                const SizedBox(width: 6),
                Text('VITALU', style: T.custom(12, weight: FontWeight.w700, color: darkMint.withValues(alpha: 0.8), spacing: 1.2)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                  ),
                  child: Text('Step ${_index + 1} of ${_slides.length}', style: T.custom(12, weight: FontWeight.w600, color: muted.withValues(alpha: 0.7), spacing: 0.3)),
                ),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => Center(
                  child: Stack(alignment: Alignment.center, children: [
                    Container(
                      width: 290,
                      height: 290,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [Color(0xD9FFFFFF), Color(0x73D6F3E9), Color(0x00FFFFFF)], stops: [0, 0.55, 0.75]),
                      ),
                    ),
                    Container(
                      width: 306,
                      height: 306,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(36),
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white.withValues(alpha: 0.8), Colors.white.withValues(alpha: 0.4)]),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                        boxShadow: const [BoxShadow(color: Color(0x14184C38), blurRadius: 40, offset: Offset(0, 20), spreadRadius: -15)],
                      ),
                      child: AssetImg(_slides[i].image, radius: 28),
                    ),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 16),
              child: Column(children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(key: ValueKey(_index), children: [
                    Text(_slides[_index].title, textAlign: TextAlign.center, style: T.custom(26, weight: FontWeight.w800, color: charcoal, height: 1.25, spacing: -0.5)),
                    const SizedBox(height: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(_slides[_index].text, textAlign: TextAlign.center, style: T.custom(14.5, weight: FontWeight.w500, color: muted, height: 1.6)),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (int i = 0; i < _slides.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: i == _index ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(color: i == _index ? darkMint : pillTrack, borderRadius: BorderRadius.circular(8)),
                    ),
                  ]
                ]),
                const SizedBox(height: 32),
                Row(children: [
                  Pressable(
                    onTap: _finish,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Skip', style: T.custom(14, weight: FontWeight.w600, color: muted)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Pressable(
                      onTap: _next,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: darkMint,
                          borderRadius: BorderRadius.circular(99),
                          boxShadow: const [BoxShadow(color: Color(0x471E5641), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -4)],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(_index == _slides.length - 1 ? 'Get Started' : 'Next', style: T.custom(15.5, weight: FontWeight.w600, color: Colors.white, spacing: 0.4)),
                          const SizedBox(width: 8),
                          Icon(Symbols.arrow_forward, size: 18, color: Colors.white.withValues(alpha: 0.9), weight: 600),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
