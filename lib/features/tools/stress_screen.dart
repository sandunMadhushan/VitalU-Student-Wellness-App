import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/sfx.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../home/breathing.dart';

/// DASS-21 (Lovibond & Lovibond, 1995). D = depression, A = anxiety,
/// S = stress. The item order and scoring are the standard ones; the
/// wording is simplified so it reads easily, keeping each item's meaning.
const _items = <(String, String)>[
  ('S', 'I found it hard to calm down and relax.'),
  ('A', 'My mouth felt dry.'),
  ('D', "I couldn't feel any positive or happy feelings at all."),
  ('A', "I had trouble breathing (for example, breathing very fast or feeling out of breath) even though I wasn't exercising."),
  ('D', 'I found it hard to get myself started on things.'),
  ('S', 'I over-reacted to things that happened.'),
  ('A', 'I felt shaky or trembly (for example, in my hands).'),
  ('S', 'I felt nervous and on edge a lot of the time.'),
  ('A', 'I worried about situations where I might panic and embarrass myself.'),
  ('D', 'I felt I had nothing to look forward to.'),
  ('S', 'I felt restless and worked up.'),
  ('S', 'I found it difficult to relax.'),
  ('D', 'I felt sad and down.'),
  ('S', 'I got annoyed when anything stopped me from getting on with what I was doing.'),
  ('A', 'I felt close to panic.'),
  ('D', "I couldn't get excited about anything."),
  ('D', "I felt I wasn't worth much as a person."),
  ('S', 'I felt quite touchy or easily upset.'),
  ('A', "I could feel my heart racing or skipping a beat, even though I wasn't exercising."),
  ('A', 'I felt scared for no good reason.'),
  ('D', 'I felt that life was meaningless.'),
];

/// The standard DASS-21 response scale.
const _options = [
  (0, 'Never', 'Did not apply to me at all'),
  (1, 'Sometimes', 'Applied to me to some degree'),
  (2, 'Often', 'Applied to me to a considerable degree'),
  (3, 'Almost always', 'Applied to me very much'),
];

/// Severity cut-offs on the 0..42 scale (raw sum × 2), per subscale.
const _cuts = {
  'D': [9, 13, 20, 27],
  'A': [7, 9, 14, 19],
  'S': [14, 18, 25, 33],
};

const _levels = ['Normal', 'Mild', 'Moderate', 'Severe', 'Extremely Severe'];

int _levelIndex(String scale, int s) {
  final c = _cuts[scale]!;
  for (int i = 0; i < c.length; i++) {
    if (s <= c[i]) return i;
  }
  return 4;
}

String _level(String scale, int s) => _levels[_levelIndex(scale, s)];

/// Severity colours, the same green-to-deep-red scale the reference uses.
Color _sevColor(int level) => switch (level) {
      0 => const Color(0xFF10B981),
      1 => const Color(0xFFEAB308),
      2 => const Color(0xFFF97316),
      3 => const Color(0xFFEF4444),
      _ => const Color(0xFF991B1B),
    };

class StressScreen extends StatefulWidget {
  const StressScreen({super.key});
  @override
  State<StressScreen> createState() => _StressScreenState();
}

class _StressScreenState extends State<StressScreen> {
  final _answers = <int, int>{};
  int _i = -1; // -1 = intro
  Map<String, dynamic>? _result;
  bool _advancing = false;

  @override
  void dispose() {
    CalmMusic.stop();
    super.dispose();
  }

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
    setState(() => _result = res);
    try {
      await Repo.saveToolResult('stress', score: s, category: res['stress_level'] as String, data: res);
    } catch (_) {}
  }

  /// Records the answer and moves on by itself after a short beat, so the
  /// choice is visible before the next question slides in.
  void _pick(int value) {
    if (_advancing) return;
    HapticFeedback.selectionClick();
    setState(() {
      _answers[_i] = value;
      _advancing = true;
    });
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      _advancing = false;
      if (_i == _items.length - 1) {
        _finish();
      } else {
        setState(() => _i++);
      }
    });
  }

  void _previous() {
    if (_advancing) return;
    HapticFeedback.selectionClick();
    setState(() => _i = _i > 0 ? _i - 1 : -1);
  }

  void _restart() => setState(() {
        _answers.clear();
        _result = null;
        _i = 0;
      });

  @override
  Widget build(BuildContext context) {
    final inQuestion = _result == null && _i >= 0;
    return VPage(
      header: const ConfidentialHeader(label: 'Anxiety tracker'),
      spacing: inQuestion ? Sp.lg : Sp.md,
      bottom: inQuestion ? _questionActions() : null,
      children: _result != null ? _resultView() : (_i < 0 ? _intro() : _question()),
    );
  }

  // ---------------------------------------------------------------------------
  // Intro

  List<Widget> _intro() => [
        Container(
          height: 170,
          decoration: BoxDecoration(color: AppColors.tint(AppColors.mind), borderRadius: BorderRadius.circular(Rad.xl)),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: SvgPicture.asset('assets/illustrations/meditation.svg', fit: BoxFit.contain, alignment: Alignment.bottomCenter),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How has the past week felt?', style: T.headlineLg),
          const SizedBox(height: 6),
          Text('21 short statements from the DASS-21 scale. Pick how much each one applied to you over the past week. There are no right or wrong answers, and this is a self-reflection, not a diagnosis.',
              style: T.bodyLg.c(AppColors.onSurfaceVariant)),
        ]),
        ListGroup(children: [
          ListRow(icon: Symbols.schedule_rounded, color: AppColors.mind, title: 'About 3 minutes', subtitle: 'Each answer moves you to the next question', chevron: false),
          ListRow(icon: Symbols.lock_rounded, color: AppColors.mind, title: '100% private', subtitle: 'Only you can see your answers and results', chevron: false),
        ]),
        const CalmMusicCard(compact: true),
        PrimaryButton('Start', color: AppColors.mind, onTap: () => setState(() => _i = 0)),
        Center(child: TextLinkButton('Do a breathing exercise first', leading: Symbols.air_rounded, onTap: () => showBreathing(context))),
      ];

  // ---------------------------------------------------------------------------
  // Questions

  List<Widget> _question() {
    final (_, text) = _items[_i];
    final pct = ((_i + 1) / _items.length * 100).round();
    return [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Question ${_i + 1} of ${_items.length}', style: T.labelMd.c(AppColors.onSurfaceVariant)),
          const Spacer(),
          Text('$pct%', style: T.labelMd.c(AppColors.mind)),
        ]),
        const SizedBox(height: 8),
        Bar(value: (_i + 1) / _items.length, height: 6, color: AppColors.mind),
      ]),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: child),
        ),
        child: Column(
          key: ValueKey(_i),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('During the past week:', style: T.labelLg.c(AppColors.mind)),
            const SizedBox(height: 6),
            Text(text, style: T.headlineMd),
            const SizedBox(height: Sp.lg),
            for (final o in _options) _option(o),
          ],
        ),
      ),
    ];
  }

  Widget _option((int, String, String) o) {
    final on = _answers[_i] == o.$1;
    final c = AppColors.mind;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: on ? AppColors.tint(c) : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(Rad.lg),
          border: Border.all(color: on ? c : AppColors.outlineVariant, width: on ? 2 : 1),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(Rad.lg),
            onTap: () => _pick(o.$1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 14),
              child: Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: on ? c : AppColors.surfaceContainer),
                  child: Text('${o.$1}', style: T.labelLg.c(on ? Colors.white : AppColors.onSurfaceVariant)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.$2, style: T.bodyLg.w(FontWeight.w700)),
                    Text(o.$3, style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  ]),
                ),
                if (on) Icon(Symbols.check_circle_rounded, color: c, fill: 1),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _questionActions() => Column(mainAxisSize: MainAxisSize.min, children: [
        SoftButton(_i == 0 ? 'Back to the start' : 'Go to previous question', icon: Symbols.arrow_back_rounded, onTap: _previous),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text('Tap an answer to move on', style: T.bodySm.c(AppColors.onSurfaceVariant))),
          TextLinkButton('Breathing exercise', leading: Symbols.air_rounded, onTap: () => showBreathing(context)),
        ]),
      ]);

  // ---------------------------------------------------------------------------
  // Results

  List<Widget> _resultView() {
    final r = _result!;
    final dl = _levelIndex('D', r['depression']), al = _levelIndex('A', r['anxiety']), sl = _levelIndex('S', r['stress']);
    final maxLevel = [dl, al, sl].reduce(math.max);
    final flag = r['flag'] == true;

    return [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your Assessment Results', style: T.headlineLg),
        const SizedBox(height: 4),
        Text('Calculated using the standard DASS-21 scale (0 to 42 maximum range per area).', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
      ]),
      if (flag)
        VCard(
          color: AppColors.errorContainer,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Please talk to someone', style: T.headlineSm.c(AppColors.onErrorContainer)),
            const SizedBox(height: 6),
            Text('Some of your answers suggest things have felt very heavy lately. You are not alone, and trained listeners are available any time.',
                style: T.bodyMd.c(AppColors.onErrorContainer)),
            const SizedBox(height: Sp.md),
            PrimaryButton('Get support now', leadingIcon: Symbols.call_rounded, color: AppColors.error, fg: AppColors.onError, onTap: () => context.push('/help')),
          ]),
        ),
      _summaryBanner(dl, al, sl, maxLevel),
      VCard(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _gauge('Depression', r['depression'], dl),
          _gauge('Anxiety', r['anxiety'], al),
          _gauge('Stress', r['stress'], sl),
        ]),
      ),
      _rangesGuide(dl, al, sl),
      _actionPlan(maxLevel),
      _helplines(),
      const SectionHeader('Five ways to unwind', subtitle: 'Small, creative resets you can try today'),
      for (final idea in _ideas) _IdeaCard(idea: idea),
      const CalmMusicCard(),
      if (maxLevel >= 2) PrimaryButton('Talk to a professional', color: AppColors.mind, onTap: () => context.push('/professionals')),
      SoftButton('Retake assessment', icon: Symbols.refresh_rounded, onTap: _restart),
      const PrivacyNote('The DASS-21 is a screening tool. It does not diagnose depression, anxiety or any other condition. Only a qualified professional can do that.'),
      Center(child: TextLinkButton('Done', color: AppColors.onSurfaceVariant, onTap: () => goBack(context, '/tools'))),
    ];
  }

  /// Overall summary, worded as in the reference tool.
  Widget _summaryBanner(int dl, int al, int sl, int maxLevel) {
    final names = [if (dl == maxLevel) 'Depression', if (al == maxLevel) 'Anxiety', if (sl == maxLevel) 'Stress'];
    final matched = names.length <= 1 ? names.join() : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    final (title, text, icon) = switch (maxLevel) {
      0 => ('Healthy Emotional Well-Being', 'Your emotional health is in a good, normal state. No significant clinical concerns were detected.', Symbols.sentiment_satisfied_rounded),
      1 => ('Mild Symptoms Detected', 'Over the past week, you experienced mild symptoms primarily related to $matched.', Symbols.sentiment_neutral_rounded),
      2 => ('Moderate Symptoms Identified', 'Over the past week, you showed moderate symptoms predominantly concerning $matched.', Symbols.balance_rounded),
      3 => ('Severe Symptoms Identified',
          'Over the past week, you experienced severe symptoms of $matched. Consulting a qualified health professional or counselor is strongly recommended.', Symbols.health_and_safety_rounded),
      _ => ('Extremely Severe Distress',
          'Over the past week, you experienced extremely severe levels of $matched. We strongly advise reaching out to a professional mental health provider or hotline immediately.',
          Symbols.emergency_rounded),
    };
    final c = _sevColor(maxLevel);
    return Container(
      padding: const EdgeInsets.all(Sp.md),
      decoration: BoxDecoration(
        color: c.withValues(alpha: AppColors.isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(Rad.lg),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: c, fill: 1, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.headlineSm),
            const SizedBox(height: 4),
            Text(text, style: T.bodyMd.c(AppColors.onSurface)),
          ]),
        ),
      ]),
    );
  }

  Widget _gauge(String name, int score, int level) {
    final c = _sevColor(level);
    return Column(children: [
      SizedBox(
        width: 92,
        height: 92,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: score.toDouble()),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => Ring(
            value: v / 42,
            size: 92,
            stroke: 9,
            color: c,
            track: AppColors.surfaceContainerHigh,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${v.round()}', style: T.metric(24)),
              Text('/ 42', style: T.labelSm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(name, style: T.labelLg),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(Rad.full), border: Border.all(color: c.withValues(alpha: 0.5))),
        child: Text(_levels[level], style: T.labelSm.c(level >= 4 && AppColors.isDark ? const Color(0xFFFF8A8A) : c).w(FontWeight.w800)),
      ),
    ]);
  }

  /// The severity table, with the student's own band in each column marked.
  Widget _rangesGuide(int dl, int al, int sl) {
    const ranges = [
      ['0–9', '0–7', '0–14'],
      ['10–13', '8–9', '15–18'],
      ['14–20', '10–14', '19–25'],
      ['21–27', '15–19', '26–33'],
      ['28+', '20+', '34+'],
    ];
    Widget cell(String t, bool mine, Color c) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(2),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: mine ? BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8), border: Border.all(color: c)) : null,
            child: Text(t, textAlign: TextAlign.center, style: T.labelMd.tnum.c(mine ? AppColors.onSurface : AppColors.onSurfaceVariant).w(mine ? FontWeight.w800 : FontWeight.w600)),
          ),
        );
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Severity Ranges Guide (DASS-21)', style: T.headlineSm),
        const SizedBox(height: Sp.sm),
        Row(children: [
          const Expanded(flex: 5, child: SizedBox()),
          for (final h in const ['Depression', 'Anxiety', 'Stress']) Expanded(flex: 4, child: Text(h, textAlign: TextAlign.center, style: T.labelSm.c(AppColors.onSurfaceVariant))),
        ]),
        for (int lv = 0; lv < 5; lv++)
          Row(children: [
            Expanded(
              flex: 5,
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: _sevColor(lv), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(child: Text(_levels[lv], style: T.labelMd, maxLines: 2)),
              ]),
            ),
            Expanded(flex: 12, child: Row(children: [cell(ranges[lv][0], dl == lv, _sevColor(lv)), cell(ranges[lv][1], al == lv, _sevColor(lv)), cell(ranges[lv][2], sl == lv, _sevColor(lv))])),
          ]),
      ]),
    );
  }

  /// Action plan by the highest level reached, as in the reference.
  Widget _actionPlan(int maxLevel) {
    final (title, text, icon, chips) = maxLevel <= 1
        ? (
            'Self-Care & Wellness Maintenance',
            'Your emotional balance is within a healthy range. Continue engaging in regular physical activity, mindful relaxation, and adequate sleep to maintain your resilience.',
            Symbols.eco_rounded,
            <(String, IconData, VoidCallback?)>[('Quality Sleep (7-8 hrs)', Symbols.bedtime_rounded, null), ('Daily Mindfulness', Symbols.self_improvement_rounded, () => showBreathing(context))],
          )
        : maxLevel == 2
            ? (
                'Active Stress Management & Guided Support',
                'Moderate symptoms indicate it is time to slow down and practice stress-reduction techniques like deep breathing, journaling, and opening up to trusted friends or family.',
                Symbols.balance_rounded,
                <(String, IconData, VoidCallback?)>[('Breathing Exercises', Symbols.air_rounded, () => showBreathing(context)), ('Talk with Loved Ones', Symbols.diversity_1_rounded, null)],
              )
            : (
                'Professional Consultation Strongly Recommended',
                'Your elevated scores suggest clinical-grade emotional distress. We strongly recommend speaking with a certified psychologist, psychiatrist, or medical doctor for comprehensive care.',
                Symbols.stethoscope_rounded,
                <(String, IconData, VoidCallback?)>[('Call 1926 Helpline', Symbols.call_rounded, () => _call('1926')), ('Consult a Specialist', Symbols.medical_services_rounded, () => context.push('/professionals'))],
              );
    final c = _sevColor(maxLevel <= 1 ? 0 : (maxLevel == 2 ? 2 : 3));
    return VCard(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconCircle(icon, size: 48, iconSize: 26, fg: c, radius: 16, fill: 1),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.headlineSm),
            const SizedBox(height: 6),
            Text(text, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final ch in chips) VChip(ch.$1, icon: ch.$2, dense: true, onTap: ch.$3),
            ]),
          ]),
        ),
      ]),
    );
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) toast(context, 'Could not start a call. Dial $number from your phone.', error: true);
    }
  }

  Widget _helplines() {
    const lines = [
      ('1926', 'NIMH Helpline', 'Call 24/7'),
      ('1333', 'CCCline', 'Crisis support, toll-free'),
      ('011 269 2909', 'Sumithrayo', 'Emotional support'),
    ];
    return ListGroup(header: 'Need urgent support? (Sri Lanka). Confidential, free mental health helplines.', children: [
      for (final l in lines) ListRow(icon: Symbols.call_rounded, color: AppColors.error, title: l.$1, subtitle: '${l.$2} · ${l.$3}', onTap: () => _call(l.$1)),
    ]);
  }
}

// -----------------------------------------------------------------------------
// Stress-relief ideas

class _Idea {
  const _Idea(this.illustration, this.minutes, this.title, this.why, this.steps, {this.action, this.actionIcon, this.kind});
  final String illustration;
  final String minutes;
  final String title;
  final String why;
  final List<String> steps;
  final String? action;
  final IconData? actionIcon;
  final String? kind;
}

const _ideas = [
  _Idea('mint_tea', '3 min', 'The mindful cup', 'Doing one simple thing slowly tells your nervous system it is safe to slow down too.', [
    'Make a cup of plain tea, coriander tea or just warm water.',
    'Hold it in both hands and notice the warmth and the smell.',
    'Take five slow sips, doing nothing else. No phone, no notes.',
  ]),
  _Idea('personal_notes', '5 min', 'Worry dump, then bin it', 'Getting worries out of your head and onto paper makes them feel smaller and more manageable.', [
    'Set a 5-minute timer and write down every worry, big or small, without editing.',
    'Circle one thing you can actually do something about today.',
    'Crumple or tear up the rest and throw it away. Done for now.',
  ]),
  _Idea('music', '1 song', 'One-song shake-out', 'Moving your body burns off stress hormones and lifts your mood fast.', [
    'Put on a song you love, the more upbeat the better.',
    'Dance, jump or shake out your arms and legs until it ends.',
    'Finish with three big stretches towards the ceiling.',
  ]),
  _Idea('sunlight', '10 min', 'Sunlight stroll, phone away', 'Daylight and a change of scene reset a busy mind better than scrolling.', [
    'Walk outside for 10 minutes: around the faculty, a garden or the lake.',
    'Keep your phone in your pocket the whole time.',
    'Spot 5 things you can see, 4 you can hear, 3 you can touch, 2 you can smell and 1 you can taste.',
  ]),
  _Idea('relaxation', '2 min', 'Hammock breathing', 'Breathing out longer than you breathe in switches on the body\'s calm-down response.', [
    'Sit or lie back and rest one hand on your belly.',
    'Breathe in through your nose for 4, then out slowly for 6.',
    'Repeat for 2 minutes, or follow the guided exercise below.',
  ], action: 'Start guided breathing', actionIcon: Symbols.air_rounded, kind: 'breathe'),
];

class _IdeaCard extends StatelessWidget {
  const _IdeaCard({required this.idea});
  final _Idea idea;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.mind;
    return VCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 130,
          color: AppColors.tint(c),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Stack(children: [
            Positioned.fill(child: SvgPicture.asset('assets/illustrations/${idea.illustration}.svg', fit: BoxFit.contain, alignment: Alignment.bottomCenter)),
            Positioned(top: 0, right: 0, child: TagPill(idea.minutes, icon: Symbols.timer_rounded, bg: AppColors.surfaceContainerLowest, fg: c)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(Sp.md),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(idea.title, style: T.headlineSm),
            const SizedBox(height: 4),
            Text(idea.why, style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: 10),
            for (int i = 0; i < idea.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.tint(c), shape: BoxShape.circle),
                    child: Text('${i + 1}', style: T.labelSm.c(c).w(FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(idea.steps[i], style: T.bodyMd)),
                ]),
              ),
            if (idea.action != null) ...[
              const SizedBox(height: 6),
              SoftButton(idea.action!, icon: idea.actionIcon, color: AppColors.tint(c), fg: c, onTap: () => showBreathing(context)),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Play/pause for the short calming music loop.
class CalmMusicCard extends StatelessWidget {
  const CalmMusicCard({super.key, this.compact = false, this.color});
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.mind;
    return ValueListenableBuilder<bool>(
      valueListenable: CalmMusic.playing,
      builder: (_, playing, _) => Material(
        color: Color.alphaBlend(c.withValues(alpha: AppColors.isDark ? 0.18 : 0.09), AppColors.surfaceContainerLowest),
        borderRadius: BorderRadius.circular(Rad.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: CalmMusic.toggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(children: [
              if (!compact) ...[
                SizedBox(width: 84, height: 72, child: SvgPicture.asset('assets/illustrations/happy_music.svg', fit: BoxFit.contain)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(compact ? 'Calm music while you answer' : 'Calm corner', style: T.headlineSm),
                  const SizedBox(height: 2),
                  Text(playing ? 'Peaceful spa bells, playing on a loop' : 'Soft, peaceful bells to help you relax', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  if (playing) ...[const SizedBox(height: 6), _Equalizer(color: c)],
                ]),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))]),
                child: Icon(playing ? Symbols.pause_rounded : Symbols.play_arrow_rounded, color: Colors.white, fill: 1, size: 30),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Little bouncing bars while music plays.
class _Equalizer extends StatefulWidget {
  const _Equalizer({required this.color});
  final Color color;
  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (int i = 0; i < 5; i++)
            Container(
              width: 4,
              height: 4 + 10 * (0.5 + 0.5 * math.sin(_c.value * 2 * math.pi * (1 + i * 0.3) + i)),
              margin: const EdgeInsets.only(right: 3),
              decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(2)),
            ),
        ]),
      );
}
