import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

class _Slide {
  const _Slide(this.title, this.text, this.preview);
  final String title;
  final String text;
  final Widget Function() preview;
}

final _slides = [
  _Slide('Your health, at a glance', 'Water, sleep, activity, meals and mood on one screen. Logging takes a tap.', () => const _TodayPreview()),
  _Slide('Eat well on a student budget', 'Log canteen meals, check your food groups and plan groceries in rupees.', () => const _DietPreview()),
  _Slide('Private, with help close by', 'Your records stay in your account. Campus support and emergency lines are always one tap away.', () => const _SupportPreview()),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
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
      _page.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.margin, Sp.sm, Sp.sm, 0),
            child: Row(children: [
              const AppIconTile(size: 28),
              const SizedBox(width: 8),
              Text('VitalU', style: T.headlineSm),
              const Spacer(),
              if (!last) TextLinkButton('Skip', color: AppColors.onSurfaceVariant, onTap: _finish),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _page,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sp.lg),
                child: Column(children: [
                  const SizedBox(height: Sp.lg),
                  Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 340), child: IgnorePointer(child: _slides[i].preview())))),
                  const SizedBox(height: Sp.lg),
                  Text(_slides[i].title, textAlign: TextAlign.center, style: T.headlineLg),
                  const SizedBox(height: Sp.sm),
                  Text(_slides[i].text, textAlign: TextAlign.center, style: T.bodyLg.c(AppColors.onSurfaceVariant)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: Sp.lg),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < _slides.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == _index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(color: i == _index ? AppColors.primary : AppColors.outlineVariant, borderRadius: BorderRadius.circular(3)),
              ),
            ],
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.margin, Sp.lg, Sp.margin, Sp.md),
            child: PrimaryButton(last ? 'Get started' : 'Continue', onTap: _next),
          ),
        ]),
      ),
    );
  }
}

class _TodayPreview extends StatelessWidget {
  const _TodayPreview();
  @override
  Widget build(BuildContext context) => TileGrid(children: [
        MetricTile(label: 'Water', icon: Symbols.water_drop_rounded, color: AppColors.water, value: '6', unit: 'glasses', progress: 0.65),
        MetricTile(label: 'Activity', icon: Symbols.directions_walk_rounded, color: AppColors.activity, value: '5,420', unit: 'steps', progress: 0.68),
        MetricTile(label: 'Sleep', icon: Symbols.bedtime_rounded, color: AppColors.sleep, value: '7h 20m', progress: 0.9),
        MetricTile(label: 'Mood', icon: Symbols.sentiment_calm_rounded, color: AppColors.mind, value: 'Calm', caption: 'Relaxed'),
      ]);
}

class _DietPreview extends StatelessWidget {
  const _DietPreview();
  @override
  Widget build(BuildContext context) => ListGroup(children: [
        ListRow(icon: Symbols.bakery_dining_rounded, color: AppColors.nutrition, title: 'Breakfast', subtitle: 'String hoppers, dhal', trailing: TagPill('Logged', bg: AppColors.tertiaryContainer, fg: AppColors.onTertiaryContainer)),
        ListRow(icon: Symbols.rice_bowl_rounded, color: AppColors.nutrition, title: 'Lunch', subtitle: 'Rice, gotukola mallum', trailing: TagPill('Logged', bg: AppColors.tertiaryContainer, fg: AppColors.onTertiaryContainer)),
        ListRow(icon: Symbols.savings_rounded, color: AppColors.warning, title: 'Weekly groceries', value: 'Rs. 1,380'),
      ]);
}

class _SupportPreview extends StatelessWidget {
  const _SupportPreview();
  @override
  Widget build(BuildContext context) => ListGroup(children: [
        ListRow(icon: Symbols.lock_rounded, color: AppColors.primary, title: 'Private to your account', subtitle: 'Research use only with your consent'),
        ListRow(icon: Symbols.stethoscope_rounded, color: AppColors.water, title: 'Campus counsellors', subtitle: 'Book or chat'),
        ListRow(icon: Symbols.call_rounded, color: AppColors.error, title: '1990 Suwa Seriya', subtitle: 'Ambulance, 24 hours'),
      ]);
}
