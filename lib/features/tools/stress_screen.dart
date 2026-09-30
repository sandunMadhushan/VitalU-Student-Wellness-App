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
  (3, 'Almost always', 'Most of the time'),
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
    final inQuestion = _result == null && _i >= 0;
    return VPage(
      header: const ConfidentialHeader(label: 'Stress check'),
      spacing: inQuestion ? Sp.lg : Sp.md,
      bottom: inQuestion ? _questionActions() : null,
      children: _result != null ? _resultView() : (_i < 0 ? _intro() : _question()),
    );
  }

  List<Widget> _intro() => [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconCircle(Symbols.psychology_rounded, size: 56, iconSize: 28, fg: AppColors.mind),
          const SizedBox(height: Sp.md),
          Text('How has the past week felt?', style: T.headlineLg),
          const SizedBox(height: 6),
          Text('21 short statements from the DASS-21 scale. Choose how much each one applied to you. This is a self-reflection, not a diagnosis.',
              style: T.bodyLg.c(AppColors.onSurfaceVariant)),
        ]),
        ListGroup(children: [
          ListRow(icon: Symbols.schedule_rounded, color: AppColors.mind, title: 'About 3 minutes', chevron: false),
          ListRow(icon: Symbols.lock_rounded, color: AppColors.mind, title: 'Private to you', subtitle: 'Never shared with lecturers, your faculty or family', chevron: false),
        ]),
        PrimaryButton('Start', onTap: () => setState(() => _i = 0)),
        Center(child: TextLinkButton('Do a breathing exercise first', leading: Symbols.air_rounded, onTap: () => showBreathing(context))),
      ];

  List<Widget> _question() {
    final (_, text) = _items[_i];
    return [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Question ${_i + 1} of ${_items.length}', style: T.labelMd.c(AppColors.onSurfaceVariant)),
          const Spacer(),
          Text('Over the past week', style: T.labelMd.c(AppColors.onSurfaceVariant)),
        ]),
        const SizedBox(height: 8),
        Bar(value: (_i + 1) / _items.length, height: 4, color: AppColors.mind),
      ]),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Text(text, key: ValueKey(_i), style: T.headlineMd),
      ),
      ListGroup(dividerIndent: 16, children: [
        for (final o in _options)
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _answers[_i] = o.$1);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.$2, style: T.bodyLg),
                    Text(o.$3, style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  ]),
                ),
                Icon(
                  _answers[_i] == o.$1 ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded,
                  color: _answers[_i] == o.$1 ? AppColors.mind : AppColors.outline,
                  fill: _answers[_i] == o.$1 ? 1 : 0,
                ),
              ]),
            ),
          ),
      ]),
    ];
  }

  Widget _questionActions() => Column(mainAxisSize: MainAxisSize.min, children: [
        PrimaryButton(
          _i == _items.length - 1 ? 'See results' : 'Next',
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
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextLinkButton('Back', color: AppColors.onSurfaceVariant, onTap: _i > 0 ? () => setState(() => _i--) : () => setState(() => _i = -1)),
          TextLinkButton('Breathing exercise', leading: Symbols.air_rounded, onTap: () => showBreathing(context)),
        ]),
      ]);

  List<Widget> _resultView() {
    final r = _result!;
    Color c(String l) => switch (l) {
          'Normal' => AppColors.tertiary,
          'Mild' => AppColors.water,
          'Moderate' => AppColors.warning,
          _ => AppColors.error,
        };
    Widget scale(String name, int score, String level, int max) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: T.bodyLg)),
              Text(level, style: T.labelLg.semi.c(c(level))),
            ]),
            const SizedBox(height: 8),
            Bar(value: score / max, color: c(level)),
            const SizedBox(height: 4),
            Text('$score of $max', style: T.bodySm.tnum.c(AppColors.onSurfaceVariant)),
          ]),
        );
    final flag = r['flag'] == true;
    final elevated = [r['depression_level'], r['anxiety_level'], r['stress_level']].any((l) => l != 'Normal' && l != 'Mild');
    return [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your results', style: T.headlineLg),
        const SizedBox(height: 4),
        Text('A reflection of the past week, not a diagnosis.', style: T.bodyLg.c(AppColors.onSurfaceVariant)),
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
      VCard(
        child: Column(children: [
          scale('Stress', r['stress'], r['stress_level'], 42),
          const Divider(height: 24),
          scale('Anxiety', r['anxiety'], r['anxiety_level'], 42),
          const Divider(height: 24),
          scale('Low mood', r['depression'], r['depression_level'], 42),
        ]),
      ),
      Text(
        elevated
            ? 'Some areas are in the moderate range or above. A counsellor or campus doctor can offer confidential support, and reaching out early makes a real difference.'
            : 'Your results are in the normal to mild range. Keep protecting your sleep, short breaks and time with friends, especially around exams.',
        style: T.bodyLg.c(AppColors.onSurfaceVariant),
      ),
      if (elevated) PrimaryButton('Talk to a professional', onTap: () => context.push('/professionals')),
      SoftButton('Breathing exercise', icon: Symbols.air_rounded, onTap: () => showBreathing(context)),
      Center(child: TextLinkButton('Done', color: AppColors.onSurfaceVariant, onTap: () => goBack(context, '/tools'))),
    ];
  }
}
