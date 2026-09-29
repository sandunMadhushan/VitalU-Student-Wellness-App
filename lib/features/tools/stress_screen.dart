import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../home/breathing.dart';

/// DASS-21 (Lovibond & Lovibond, 1995). D = depression, A = anxiety, S = stress.
const _items = <(String, String)>[
  ('S', 'I found it hard to wind down'),
  ('A', 'I was aware of dryness of my mouth'),
  ('D', "I couldn't seem to experience any positive feeling at all"),
  ('A', 'I experienced breathing difficulty (e.g. rapid breathing or breathlessness without physical effort)'),
  ('D', 'I found it difficult to work up the initiative to do things'),
  ('S', 'I tended to over-react to situations'),
  ('A', 'I experienced trembling (e.g. in the hands)'),
  ('S', 'I felt that I was using a lot of nervous energy'),
  ('A', 'I was worried about situations in which I might panic and make a fool of myself'),
  ('D', 'I felt that I had nothing to look forward to'),
  ('S', 'I found myself getting agitated'),
  ('S', 'I found it difficult to relax'),
  ('D', 'I felt down-hearted and blue'),
  ('S', 'I was intolerant of anything that kept me from getting on with what I was doing'),
  ('A', 'I felt I was close to panic'),
  ('D', 'I was unable to become enthusiastic about anything'),
  ('D', "I felt I wasn't worth much as a person"),
  ('S', 'I felt that I was rather touchy'),
  ('A', 'I was aware of the action of my heart without physical effort (e.g. a racing or skipped beat)'),
  ('A', 'I felt scared without any good reason'),
  ('D', 'I felt that life was meaningless'),
];

const _options = [
  (0, 'Never', 'Did not apply to me at all'),
  (1, 'Sometimes', 'Applied to me some of the time'),
  (2, 'Often', 'A good part of the week'),
  (3, 'Almost Always', 'Most of the time'),
];

String _level(String scale, int s) {
  const cut = {
    'D': [9, 13, 20, 27],
    'A': [7, 9, 14, 19],
    'S': [14, 18, 25, 33],
  };
  final c = cut[scale]!;
  if (s <= c[0]) return 'Normal';
  if (s <= c[1]) return 'Mild';
  if (s <= c[2]) return 'Moderate';
  if (s <= c[3]) return 'Severe';
  return 'Extremely Severe';
}

class StressScreen extends StatefulWidget {
  const StressScreen({super.key});
  @override
  State<StressScreen> createState() => _StressScreenState();
}

class _StressScreenState extends State<StressScreen> {
  final _answers = <int, int>{};
  int _i = -1; // -1 = intro
  Map<String, dynamic>? _result;
  bool _saving = false;

  Future<void> _finish() async {
    int sum(String k) => [for (int i = 0; i < _items.length; i++) if (_items[i].$1 == k) _answers[i] ?? 0].fold(0, (a, b) => a + b) * 2;
    final d = sum('D'), a = sum('A'), s = sum('S');
    final res = {
      'depression': d,
      'anxiety': a,
      'stress': s,
      'depression_level': _level('D', d),
      'anxiety_level': _level('A', a),
      'stress_level': _level('S', s),
      'flag': (_answers[20] ?? 0) >= 2 || (_answers[16] ?? 0) >= 2 || d > 20,
    };
    setState(() => _saving = true);
    try {
      await Repo.saveToolResult('stress', score: s, category: res['stress_level'] as String, data: res);
    } catch (_) {}
    setState(() {
      _saving = false;
      _result = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: const ConfidentialHeader(),
      children: _result != null ? _resultView() : (_i < 0 ? _intro() : _question()),
    );
  }

  List<Widget> _intro() => [
        const SizedBox(height: 4),
        VCard(
          clip: true,
          shadow: Shadows.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(aspectRatio: 4 / 3, child: AssetImg('meditating_student', radius: Rad.r2xl)),
            const SizedBox(height: Sp.md),
            Text('Stress & Anxiety Self-Check', style: T.headlineMd, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('21 short statements about the past week, using the DASS-21 scale. It takes about 3 minutes. This is a self-reflection, not a diagnosis.',
                style: T.bodyMd.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
          ]),
        ),
        PrimaryButton('Begin Check-in', icon: Symbols.arrow_forward, color: AppColors.inverseSurface, fg: AppColors.inverseOnSurface, height: 52, onTap: () => setState(() => _i = 0)),
        Center(child: TextLinkButton('Need breathing room first? 1-minute box breathing', leading: Symbols.air, color: AppColors.primary, onTap: () => showBreathing(context))),
        const PrivacyNote('Your answers are private to you. Never shared with lecturers, your faculty or family.'),
      ];

  List<Widget> _question() {
    final (_, text) = _items[_i];
    final remainingMin = ((_items.length - _i) * 9 / 60).ceil();
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(children: [
          TagPill('Step ${_i + 1} of ${_items.length}', icon: Symbols.self_improvement, fg: AppColors.primary),
          const Spacer(),
          Text('~$remainingMin min${remainingMin == 1 ? '' : 's'} remaining', style: T.labelSm.c(AppColors.outline).medium),
        ]),
      ),
      Container(
        height: 10,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(10)),
        child: Bar(value: (_i + 1) / _items.length, height: 6, track: Colors.transparent, gradient: LinearGradient(colors: [AppColors.primaryFixedDim, AppColors.primary, AppColors.tertiaryFixed])),
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: VCard(
          key: ValueKey(_i),
          clip: true,
          shadow: const [BoxShadow(color: Color(0x122D2B38), blurRadius: 36, offset: Offset(0, 16), spreadRadius: -10)],
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(top: -48, right: -48, child: Glow(color: AppColors.primaryFixed.withValues(alpha: 0.4), size: 176)),
            Positioned(bottom: -40, left: -40, child: Glow(color: AppColors.tertiaryFixed.withValues(alpha: 0.3), size: 160)),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Rad.r2xl),
                  child: Stack(fit: StackFit.expand, children: [
                    const AssetImg('meditating_student'),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(0, 40, 0, 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [
                            AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
                            AppColors.surfaceContainerLowest.withValues(alpha: 0.4),
                            Colors.transparent,
                          ]),
                        ),
                        alignment: Alignment.center,
                        child: TagPill('Over the past week • DASS-21', icon: Symbols.spa, iconColor: AppColors.tertiary, bg: AppColors.surfaceContainerLowest.withValues(alpha: 0.95), fg: AppColors.onSurface),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: Sp.md),
              Text(text, style: T.headlineSm.bold.tracking(-0.2), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Take a slow breath. There are no right or wrong answers here.', style: T.bodySm.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
              const SizedBox(height: Sp.md),
              for (final o in _options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Pressable(
                    scale: 0.99,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _answers[_i] = o.$1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _answers[_i] == o.$1 ? AppColors.primaryFixed.withValues(alpha: 0.6) : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(Rad.r2xl),
                        boxShadow: _answers[_i] == o.$1 ? Shadows.tinted(AppColors.primary, opacity: 0.12, blur: 16, y: 4, spread: 0) : null,
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(o.$2, style: T.labelLg.c(_answers[_i] == o.$1 ? AppColors.onPrimaryFixed : AppColors.onSurface).w(_answers[_i] == o.$1 ? FontWeight.w700 : FontWeight.w600)),
                            Text(o.$3, style: T.bodySm.c(AppColors.onSurfaceVariant)),
                          ]),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(color: _answers[_i] == o.$1 ? AppColors.primary : AppColors.surfaceContainerHigh, shape: BoxShape.circle),
                          child: Icon(Symbols.check, size: 18, color: _answers[_i] == o.$1 ? AppColors.onPrimary : Colors.transparent),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
      ),
      PrimaryButton(
        _i == _items.length - 1 ? 'See My Reflection' : 'Next Question',
        icon: Symbols.arrow_forward,
        color: AppColors.inverseSurface,
        fg: AppColors.inverseOnSurface,
        height: 52,
        loading: _saving,
        onTap: _answers[_i] == null
            ? null
            : () {
                if (_i == _items.length - 1) {
                  _finish();
                } else {
                  setState(() => _i++);
                }
              },
      ),
      if (_i > 0) Center(child: TextLinkButton('Previous', leading: Symbols.arrow_back, onTap: () => setState(() => _i--))),
      Center(child: TextLinkButton('Need breathing room right now? 1-minute box breathing', leading: Symbols.air, color: AppColors.primary, onTap: () => showBreathing(context))),
      const PrivacyNote('Your answers are 100% confidential. Never shared with lecturers, deans, or parents.'),
    ];
  }

  List<Widget> _resultView() {
    final r = _result!;
    Color c(String l) => switch (l) {
          'Normal' => AppColors.tertiary,
          'Mild' => AppColors.primary,
          'Moderate' => AppColors.secondary,
          _ => AppColors.error,
        };
    Widget scale(String name, IconData icon, int score, String level, int max) => VCard(
          shadow: Shadows.soft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconCircle(icon, size: 36, iconSize: 20, bg: AppColors.surfaceContainer, fg: c(level)),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: T.labelLg)),
              TagPill(level, bg: c(level).withValues(alpha: 0.12), fg: c(level)),
            ]),
            const SizedBox(height: 10),
            Bar(value: score / max, color: c(level)),
            const SizedBox(height: 4),
            Text('Score $score / $max', style: T.labelSm.c(AppColors.onSurfaceVariant)),
          ]),
        );
    final flag = r['flag'] == true;
    final elevated = [r['depression_level'], r['anxiety_level'], r['stress_level']].any((l) => l != 'Normal' && l != 'Mild');
    return [
      const SizedBox(height: 4),
      Column(children: [
        IconCircle(Symbols.spa, size: 56, iconSize: 28, bg: AppColors.tertiaryFixed, fg: AppColors.tertiary),
        const SizedBox(height: Sp.sm),
        Text('Thank you for checking in', style: T.headlineMd, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text('Here is a gentle reflection of the past week. These results are not a diagnosis.', style: T.bodySm.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
      ]),
      if (flag)
        VCard(
          color: AppColors.errorContainer,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Symbols.favorite, color: AppColors.onErrorContainer, fill: 1),
              const SizedBox(width: 8),
              Expanded(child: Text('You deserve support right now', style: T.labelLg.c(AppColors.onErrorContainer))),
            ]),
            const SizedBox(height: 6),
            Text('Some of your answers suggest things have felt very heavy lately. You are not alone — talking to someone can really help. Trained listeners are available any time.',
                style: T.bodySm.c(AppColors.onErrorContainer)),
            const SizedBox(height: 10),
            PrimaryButton('Get Support Now', leadingIcon: Symbols.call, color: AppColors.error, height: 48, onTap: () => context.push('/help')),
          ]),
        ),
      scale('Stress', Symbols.bolt, r['stress'], r['stress_level'], 42),
      scale('Anxiety', Symbols.air, r['anxiety'], r['anxiety_level'], 42),
      scale('Low mood', Symbols.cloud, r['depression'], r['depression_level'], 42),
      VCard(
        color: AppColors.surfaceContainerLow,
        child: Text(
          elevated
              ? 'Some areas are in the moderate range or above. A counsellor or campus doctor can offer confidential support — reaching out early makes a real difference.'
              : 'Your results are in the normal-to-mild range. Keep protecting your sleep, short breaks and time with friends — especially around exams.',
          style: T.bodyMd.c(AppColors.onSurfaceVariant),
        ),
      ),
      if (elevated) PrimaryButton('Talk to a Professional', icon: Symbols.arrow_forward, onTap: () => context.push('/professionals')),
      SoftButton('Try 1-minute box breathing', icon: Symbols.air, iconColor: AppColors.primary, onTap: () => showBreathing(context, cta: 'Done')),
      Center(child: TextLinkButton('Back to Health Tools', onTap: () => goBack(context, '/tools'))),
    ];
  }
}
