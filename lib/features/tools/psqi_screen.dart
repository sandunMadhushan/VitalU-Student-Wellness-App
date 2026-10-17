import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'tool_widgets.dart';

/// Sleep Quality Score Quiz from The Nurse's Diary, adapted from the
/// Pittsburgh Sleep Quality Index (PSQI): six questions worth up to 20 points
/// each, a score out of 120 where higher is better.
class Psqi {
  Psqi._();

  static const max = 120;

  static const questions = <(String, List<(String, int)>)>[
    (
      'After getting into bed at night, how long does it usually take you to fall asleep (Sleep Latency)?',
      [('Less than 15 minutes', 20), ('Between 16 and 30 minutes', 15), ('Between 31 and 60 minutes', 10), ('More than 1 hour', 0)],
    ),
    (
      'How many hours of actual sleep do you typically get each night?',
      [('More than 7 hours', 20), ('Between 6 and 7 hours', 15), ('Between 5 and 6 hours', 10), ('Less than 5 hours', 0)],
    ),
    (
      'How often do you wake up during the night (Broken / Fragmented Sleep)?',
      [('Never', 20), ('Once or twice a week', 15), ('Three to four times a week', 10), ('Multiple times almost every night', 0)],
    ),
    (
      'How refreshed and energized do you feel when waking up in the morning?',
      [('Very fresh, energetic, and rejuvenated', 20), ('Moderate / Normal freshness', 15), ('Tired and sluggish to get out of bed', 10), ('Extremely exhausted, heavy-headed, or headache', 0)],
    ),
    (
      'Do you experience daytime sleepiness or fatigue (at work or while driving)?',
      [('Not at all / Never', 20), ('Rarely / Occasionally', 15), ('A few days every week', 10), ('Severe daytime drowsiness almost every day', 0)],
    ),
    (
      'How long do you use smartphones or digital screens (TV/Laptop) before sleeping?',
      [('Completely stop screens at least 1 hour before bed', 20), ('Stop screens about 30 minutes before bed', 15), ('Use phone/screens right until turning lights off', 10), ('Continue using phone in dark bed for hours', 0)],
    ),
  ];

  /// Total points for the chosen option of each question.
  static int total(List<int> picks) => [for (int i = 0; i < picks.length; i++) questions[i].$2[picks[i]].$2].fold(0, (a, b) => a + b);

  /// 95 to 120 excellent, 75 to 94 good, 50 to 74 poor, below 50 severe.
  static ({String title, String short, String desc, IconData icon, Color color, int level}) tier(int score) {
    if (score >= 95) {
      return (
        title: 'Outstanding Sleep Quality!',
        short: 'Excellent',
        desc: 'Congratulations! You enjoy healthy, restorative, and restful sleep. Your body and mind are receiving optimal biological recovery. Keep up these wonderful sleep hygiene habits!',
        icon: Symbols.star_rounded,
        color: AppColors.tertiary,
        level: 0,
      );
    }
    if (score >= 75) {
      return (
        title: 'Good Sleep Quality!',
        short: 'Good',
        desc: 'Your sleep quality is at a good level, with room for fine-tuning. By reducing pre-bed screen exposure or keeping a strict bedtime routine, you can reach 100% sleep restoration.',
        icon: Symbols.thumb_up_rounded,
        color: AppColors.water,
        level: 0,
      );
    }
    if (score >= 50) {
      return (
        title: 'Poor Sleep Quality',
        short: 'Poor',
        desc: 'Attention! Your sleep quality is below recommended healthy levels. If this continues long-term, it can negatively impact your physical health, immunity, and mental well-being.',
        icon: Symbols.warning_rounded,
        color: AppColors.warning,
        level: 1,
      );
    }
    return (
      title: 'Severely Deprived Sleep',
      short: 'Severely deprived',
      desc: 'Your sleep quality is severely impaired. You are likely suffering from chronic daytime exhaustion, brain fog, and elevated stress. We strongly recommend consulting a healthcare physician or sleep specialist.',
      icon: Symbols.report_rounded,
      color: AppColors.error,
      level: 2,
    );
  }

  /// Short label and colour, for summary cards.
  static (String, Color) band(int score) {
    final t = tier(score);
    return ('${t.short} sleep quality', t.color);
  }

  /// The score of a saved result, or null for results saved on the old
  /// 0 to 21 scale, which cannot be compared.
  static int? scoreOf(Rec? result) {
    if (result == null) return null;
    final data = result['data'];
    if (data is! Map || data['scale'] != max) return null;
    return (result['score'] as num?)?.round();
  }

  static const tips = [
    'Maintain a consistent sleep and wake-up schedule every day.',
    'Limit caffeine intake (coffee/tea/energy drinks) after 4:00 PM.',
    'Avoid smartphone and digital screen exposure at least 45 minutes before sleep.',
    'Keep the bedroom completely dark, quiet, and cool.',
    'Avoid long daytime naps (keep to under 20 minutes before 3:00 PM).',
  ];

  static const risks = [
    'Cardiovascular disease and hypertension (high blood pressure).',
    'Elevated risk of Type 2 Diabetes.',
    'Weight gain and obesity due to disrupted hunger hormones.',
    'Compromised immune function and frequent infections.',
    'Chronic mental stress, brain fog, and impaired cognitive recall.',
  ];

  static const disclaimer = 'This assessment is adapted from the Pittsburgh Sleep Quality Index (PSQI) for educational and self-awareness purposes only. It does not constitute a clinical medical diagnosis.';
}

const _reference = ToolReference(
  tool: 'The Nurse\'s Diary Sleep Quality Score Quiz',
  citation: 'The Nurse\'s Diary. Sleep Quality Score Quiz, adapted from the Pittsburgh Sleep Quality Index (PSQI).',
  url: 'https://thenursediary.com/tools/sleep.html',
  note: 'Six questions worth up to 20 points each. 95 to 120 is excellent, 75 to 94 good, 50 to 74 poor and below 50 severely disrupted sleep.',
);

class PsqiScreen extends StatefulWidget {
  const PsqiScreen({super.key});
  @override
  State<PsqiScreen> createState() => _PsqiScreenState();
}

class _PsqiScreenState extends State<PsqiScreen> {
  /// -1 is the start screen.
  int _i = -1;
  final _answers = List<int?>.filled(Psqi.questions.length, null);
  int? _score;
  bool _advancing = false;

  void _pick(int option) {
    if (_advancing) return;
    HapticFeedback.selectionClick();
    setState(() {
      _answers[_i] = option;
      _advancing = true;
    });
    Future.delayed(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _advancing = false;
      if (_i == Psqi.questions.length - 1) {
        _finish();
      } else {
        setState(() => _i++);
      }
    });
  }

  Future<void> _finish() async {
    final picks = _answers.cast<int>();
    final score = Psqi.total(picks);
    setState(() => _score = score);
    try {
      await Repo.saveToolResult('psqi', score: score, category: Psqi.tier(score).short, data: {
        'scale': Psqi.max,
        for (int i = 0; i < picks.length; i++) 'q${i + 1}': Psqi.questions[i].$2[picks[i]].$2,
      });
    } catch (_) {}
  }

  void _previous() {
    if (_advancing) return;
    HapticFeedback.selectionClick();
    setState(() => _i = _i - 1);
  }

  void _restart() => setState(() {
        _answers.fillRange(0, _answers.length, null);
        _score = null;
        _i = 0;
      });

  @override
  Widget build(BuildContext context) {
    final inQuestion = _score == null && _i >= 0;
    return VPage(
      header: TitleHeader('Sleep quality check', onLeading: () => goBack(context, '/tools/sleep')),
      spacing: inQuestion ? Sp.lg : Sp.md,
      bottom: inQuestion ? SoftButton(_i == 0 ? 'Back to the start' : 'Previous', icon: Symbols.arrow_back_rounded, onTap: _previous) : null,
      children: _score != null ? _results(_score!) : (_i < 0 ? _intro() : _question()),
    );
  }

  // ---------------------------------------------------------------------------
  // Start

  List<Widget> _intro() => [
        Container(
          height: 170,
          decoration: BoxDecoration(color: AppColors.tint(AppColors.sleep), borderRadius: BorderRadius.circular(Rad.xl)),
          clipBehavior: Clip.antiAlias,
          child: Image.asset('assets/icons3d/sleep.jpg', fit: BoxFit.cover),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pittsburgh Sleep Quality Index (PSQI)', style: T.labelLg.c(AppColors.sleep)),
          const SizedBox(height: 4),
          Text('Sleep Quality Score Quiz', style: T.headlineLg),
          const SizedBox(height: 6),
          Text('Are you getting enough restorative sleep? Take this 2-minute clinical assessment to calculate your sleep score out of 120 points.', style: T.bodyLg.c(AppColors.onSurfaceVariant)),
        ]),
        ListGroup(children: [
          ListRow(icon: Symbols.timer_rounded, color: AppColors.sleep, title: 'Just 2 Minutes', subtitle: '6 clinically structured questions', chevron: false),
          ListRow(icon: Symbols.speed_rounded, color: AppColors.sleep, title: '120-Point Metric', subtitle: 'Precise restorative score calculation', chevron: false),
          ListRow(icon: Symbols.lock_rounded, color: AppColors.sleep, title: '100% Confidential', subtitle: 'Only you can see your answers and score', chevron: false),
        ]),
        PrimaryButton('Start Sleep Quiz', color: AppColors.sleep, onTap: () => setState(() => _i = 0)),
        _reference,
      ];

  // ---------------------------------------------------------------------------
  // Questions

  List<Widget> _question() {
    final (text, options) = Psqi.questions[_i];
    final n = Psqi.questions.length;
    final pct = ((_i + 1) / n * 100).round();
    return [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Symbols.auto_awesome_rounded, size: 16, color: AppColors.sleep, fill: 1),
          const SizedBox(width: 6),
          Text('Question ${_i + 1} of $n', style: T.labelMd.c(AppColors.onSurfaceVariant)),
          const Spacer(),
          Text('$pct%', style: T.labelMd.c(AppColors.sleep)),
        ]),
        const SizedBox(height: 8),
        Bar(value: (_i + 1) / n, height: 6, color: AppColors.sleep),
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
            Text(text, style: T.headlineMd),
            const SizedBox(height: Sp.lg),
            for (int o = 0; o < options.length; o++) _option(o, options[o].$1),
          ],
        ),
      ),
    ];
  }

  Widget _option(int index, String label) {
    final on = _answers[_i] == index;
    final c = AppColors.sleep;
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
            onTap: () => _pick(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 16),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? c : AppColors.outline, width: 2)),
                  alignment: Alignment.center,
                  child: AnimatedScale(
                    scale: on ? 1 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: T.bodyLg.w(on ? FontWeight.w700 : FontWeight.w500))),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Results

  List<Widget> _results(int score) {
    final t = Psqi.tier(score);
    Widget list(String heading, IconData icon, Color color, List<String> items) => VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(heading, style: T.headlineSm),
            const SizedBox(height: 10),
            for (final s in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(icon, size: 18, color: color, fill: 1),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s, style: T.bodyMd)),
                ]),
              ),
          ]),
        );

    return [
      VCard(
        child: Column(children: [
          Text('Sleep Health Assessment Report', style: T.labelLg.c(AppColors.sleep)),
          const SizedBox(height: Sp.md),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score.toDouble()),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Ring(
              value: v / Psqi.max,
              size: 160,
              stroke: 12,
              color: t.color,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${v.round()}', style: T.metric(44)),
                Text('/ ${Psqi.max} Pts', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ),
        ]),
      ),
      VCard(
        color: AppColors.tint(t.color),
        flat: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(t.icon, color: t.color, fill: 1),
            const SizedBox(width: 8),
            Expanded(child: Text(t.title, style: T.headlineSm.c(t.color))),
          ]),
          const SizedBox(height: 6),
          Text(t.desc, style: T.bodyMd),
          if (t.level == 2) ...[
            const SizedBox(height: Sp.md),
            SoftButton('Contact the University Health Centre', icon: Symbols.local_hospital_rounded, onTap: () => context.push('/help')),
          ],
        ]),
      ),
      list('Actionable Steps to Improve Your Sleep Quality:', Symbols.check_circle_rounded, AppColors.tertiary, Psqi.tips),
      list('Health Risks Associated with Chronic Sleep Deprivation:', Symbols.error_rounded, AppColors.error, Psqi.risks),
      Text(Psqi.disclaimer, style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.4)),
      SoftButton('Retake Quiz', icon: Symbols.refresh_rounded, onTap: _restart),
      Center(child: TextLinkButton('Done', color: AppColors.onSurfaceVariant, onTap: () => goBack(context, '/tools/sleep'))),
      _reference,
    ];
  }
}
