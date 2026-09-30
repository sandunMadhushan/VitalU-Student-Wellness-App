import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'assessment_data.dart';

// ---------------------------------------------------------------------------
// Health Assessments — status & history
// ---------------------------------------------------------------------------

class AssessmentsStatusScreen extends StatefulWidget {
  const AssessmentsStatusScreen({super.key});
  @override
  State<AssessmentsStatusScreen> createState() => _AssessmentsStatusScreenState();
}

class _AssessmentsStatusScreenState extends State<AssessmentsStatusScreen> {
  bool _loading = true;
  Rec? _open;
  Rec? _next;
  List<Rec> _history = [];
  bool _reminded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (o, n) = await Repo.currentAndNextWindow();
      _open = o;
      _next = n;
      _history = await Repo.assessments();
    } catch (e) {
      debugPrint('$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _remind() async {
    final w = _next;
    if (w == null) return;
    await Repo.schedule(
      title: 'Health assessment open',
      body: 'Your ${w['term']} assessment is now open. It takes about 5 minutes.',
      category: 'milestone',
      label: 'Assessment',
      icon: 'event_upcoming',
      route: '/assessments/run',
      at: DateTime.parse(w['opens_at']).toLocal(),
    );
    setState(() => _reminded = true);
    if (mounted) toast(context, "Reminder set. We'll let you know when it opens.");
  }

  @override
  Widget build(BuildContext context) {
    final completed = _history.where((h) => h['status'] == 'completed').toList();
    final inProgress = _open == null ? null : _history.where((h) => h['window_id'] == _open!['id'] && h['status'] != 'completed').firstOrNull;
    final openDone = _open != null && _history.any((h) => h['window_id'] == _open!['id'] && h['status'] == 'completed');
    final target = (_open != null && !openDone) ? _open : _next;
    final isOpen = target != null && target == _open;

    return VPage(
      header: const TitleHeader('Health assessments'),
      onRefresh: _load,
      children: _loading
          ? [const Loading()]
          : [
              Text('A short check-in about every six months covering body measurements, eating, activity, sleep and stress. It takes about 5 minutes.',
                  style: T.bodyLg.c(AppColors.onSurfaceVariant)),
              VCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(isOpen ? 'Open now' : 'Next assessment', style: T.labelMd.c(isOpen ? AppColors.tertiary : AppColors.onSurfaceVariant))),
                    if (isOpen && inProgress != null) TagPill('In progress', bg: AppColors.tint(AppColors.primary), fg: AppColors.primary),
                  ]),
                  const SizedBox(height: 6),
                  Text(target == null ? 'To be announced' : DateFormat('MMMM yyyy').format(DateTime.parse(target['opens_at']).toLocal()), style: T.headlineLg),
                  const SizedBox(height: 6),
                  Text(
                    target == null
                        ? 'Your university will announce the next window. You will get a reminder.'
                        : isOpen
                            ? 'Closes ${DateFormat('d MMMM').format(DateTime.parse(target['closes_at']).toLocal())}. No preparation needed.'
                            : 'Opens ${DateFormat('d MMMM').format(DateTime.parse(target['opens_at']).toLocal())}. No preparation needed.',
                    style: T.bodyMd.c(AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: Sp.md),
                  if (isOpen)
                    PrimaryButton(inProgress != null ? 'Continue' : 'Start assessment', onTap: () async {
                      await context.push('/assessments/run');
                      _load();
                    })
                  else
                    SoftButton(
                      _reminded ? 'Reminder set' : 'Remind me when it opens',
                      icon: _reminded ? Symbols.notifications_active_rounded : Symbols.notifications_rounded,
                      onTap: target == null || _reminded ? null : _remind,
                    ),
                ]),
              ),
              if (completed.isEmpty)
                const EmptyState(icon: Symbols.history_rounded, title: 'No completed assessments yet', text: 'Completed check-ins appear here so you can see changes over time.')
              else
                ListGroup(header: 'History', children: [
                  for (final h in completed)
                    ListRow(
                      icon: Symbols.assignment_turned_in_rounded,
                      color: AppColors.tertiary,
                      title: h['title'] ?? 'Health assessment',
                      subtitle: [DateFormat('d MMM yyyy').format(DateTime.parse(h['completed_at']).toLocal()), if (h['result_label'] != null) h['result_label']].join(' · '),
                      onTap: () => showAssessmentSummary(context, h),
                    ),
                ]),
              ListGroup(children: [
                ListRow(icon: Symbols.health_and_safety_rounded, color: AppColors.primary, title: 'Health tools', subtitle: 'Check in any time, no need to wait for a window', onTap: () => context.go('/tools')),
              ]),
            ],
    );
  }
}

Future<void> showAssessmentSummary(BuildContext context, Rec a) {
  final s = Map<String, dynamic>.from(a['scores'] ?? {});
  String stressLabel(num v) => v <= 6 ? 'Low' : (v <= 10 ? 'Moderate' : 'High');
  return showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(a['title'] ?? 'Assessment summary', style: T.headlineMd),
        const SizedBox(height: 4),
        Text(
            [
              if (a['result_label'] != null) a['result_label'],
              if (a['completed_at'] != null) DateFormat('d MMM yyyy').format(DateTime.parse(a['completed_at']).toLocal()),
            ].join(' · '),
            style: T.bodySm.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: Sp.md),
        ListGroup(children: [
          if (s['bmi'] != null) ListRow(icon: Symbols.monitor_weight_rounded, color: AppColors.body, title: 'BMI', value: '${s['bmi']}', chevron: false),
          if (s['whr'] != null) ListRow(icon: Symbols.straighten_rounded, color: AppColors.body, title: 'Waist-to-hip ratio', value: '${s['whr']}', chevron: false),
          if (s['sbp'] != null) ListRow(icon: Symbols.monitor_heart_rounded, color: AppColors.heart, title: 'Systolic pressure', value: '${(s['sbp'] as num).round()} mmHg', chevron: false),
          ListRow(icon: Symbols.restaurant_rounded, color: AppColors.nutrition, title: 'Eating habits', value: '${s['diet_score'] ?? 0} / 10', chevron: false),
          ListRow(icon: Symbols.directions_walk_rounded, color: AppColors.activity, title: 'Active days last week', value: '${s['activity_days'] ?? 0}', chevron: false),
          ListRow(icon: Symbols.bedtime_rounded, color: AppColors.sleep, title: 'Typical sleep', value: '${s['sleep_hours'] ?? '-'} h', chevron: false),
          ListRow(icon: Symbols.psychology_rounded, color: AppColors.mind, title: 'Stress (PSS-4)', value: '${s['stress'] ?? 0} / 16, ${stressLabel((s['stress'] ?? 0) as num).toLowerCase()}', chevron: false),
        ]),
        const SizedBox(height: Sp.md),
        Text('For your own reflection, not a diagnosis. If anything worries you, a university health professional can help.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
      ]));
}

// ---------------------------------------------------------------------------
// Assessment in progress
// ---------------------------------------------------------------------------

class AssessmentRunScreen extends StatefulWidget {
  const AssessmentRunScreen({super.key});
  @override
  State<AssessmentRunScreen> createState() => _AssessmentRunScreenState();
}

class _AssessmentRunScreenState extends State<AssessmentRunScreen> {
  bool _loading = true;
  String? _error;
  Rec? _assessment;
  Map<String, dynamic> _answers = {};
  int _index = 0;
  bool _saving = false;
  final _numCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (open, _) = await Repo.currentAndNextWindow();
      if (open == null) {
        _error = 'There is no assessment window open for your faculty right now.';
      } else {
        final a = await Repo.startAssessment(open);
        if (a['status'] == 'completed') {
          if (mounted) context.pushReplacement('/assessments/complete', extra: a);
          return;
        }
        _assessment = a;
        _answers = Map<String, dynamic>.from(a['answers'] ?? {});
        _index = (a['current_index'] as int? ?? 0).clamp(0, assessmentQuestions.length - 1);
        // Prefill measurements from profile.
        final p = AppState.instance.profile;
        _answers.putIfAbsent('height_cm', () => p?.heightCm);
        _answers.putIfAbsent('weight_kg', () => p?.weightKg);
        _answers.putIfAbsent('waist_cm', () => p?.waistCm);
        _answers.putIfAbsent('hip_cm', () => p?.hipCm);
        _answers.removeWhere((k, v) => v == null);
        _syncNum();
      }
    } catch (e) {
      _error = 'Could not load the assessment. Please check your connection.';
    }
    if (mounted) setState(() => _loading = false);
  }

  AQuestion get _q => assessmentQuestions[_index];

  void _syncNum() {
    final q = assessmentQuestions[_index];
    if (q.type == AType.number) {
      final v = _answers[q.id];
      _numCtrl.text = v == null ? '' : (v is num && v == v.roundToDouble() ? v.toInt().toString() : v.toString());
    }
  }

  bool get _canNext {
    if (_q.type == AType.choice) return _answers[_q.id] != null;
    final v = double.tryParse(_numCtrl.text);
    if (_numCtrl.text.isEmpty) return _q.optional;
    return v != null && v >= (_q.min ?? 0) && v <= (_q.max ?? 99999);
  }

  Future<void> _next() async {
    if (_q.type == AType.number) {
      final v = double.tryParse(_numCtrl.text);
      if (v == null) {
        _answers.remove(_q.id);
      } else {
        _answers[_q.id] = v;
      }
    }
    setState(() => _saving = true);
    try {
      if (_index == assessmentQuestions.length - 1) {
        final (scores, label) = scoreAssessment(_answers);
        await Repo.completeAssessment(_assessment!['id'], _answers, scores, label);
        // Keep the personal profile in sync with freshly measured values.
        final update = <String, dynamic>{};
        for (final k in ['height_cm', 'weight_kg', 'waist_cm', 'hip_cm']) {
          if (_answers[k] != null) update[k] = _answers[k];
        }
        if (update.isNotEmpty) {
          update['measured_at'] = DateTime.now().toUtc().toIso8601String();
          await AppState.instance.updateProfile(update);
        }
        if (mounted) context.pushReplacement('/assessments/complete', extra: {..._assessment!, 'completed_at': DateTime.now().toUtc().toIso8601String(), 'scores': scores, 'result_label': label});
        return;
      }
      _index++;
      await Repo.saveAssessmentProgress(_assessment!['id'], _answers, _index);
      _syncNum();
    } catch (e) {
      if (mounted) toast(context, 'Could not save your answer. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() {
    if (_index == 0) return goBack(context);
    setState(() {
      _index--;
      _syncNum();
    });
  }

  Future<void> _saveAndExit() async {
    if (_assessment != null) {
      try {
        await Repo.saveAssessmentProgress(_assessment!['id'], _answers, _index);
      } catch (_) {}
    }
    if (mounted) goBack(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _error != null) {
      return VPage(
        header: TitleHeader('Health assessment', close: true, onLeading: () => goBack(context)),
        children: [
          if (_loading) const Loading() else EmptyState(icon: Symbols.event_busy_rounded, title: 'Assessment not available', text: _error, action: SoftButton('Back', expand: false, onTap: () => goBack(context))),
        ],
      );
    }
    final section = assessmentSections[_q.section];
    final total = assessmentQuestions.length;
    final remaining = total - _index;
    final mins = (remaining * 15 / 60).ceil();
    final last = _index == total - 1;

    return VPage(
      header: TitleHeader(section.title, close: true, onLeading: _saveAndExit),
      bottom: Row(children: [
        if (_index > 0) ...[
          IconButton.outlined(tooltip: 'Previous question', style: IconButton.styleFrom(minimumSize: const Size(52, 52)), icon: Icon(backIcon(context)), onPressed: _saving ? null : _back),
          const SizedBox(width: Sp.sm),
        ],
        Expanded(child: PrimaryButton(last ? 'Submit' : 'Next', loading: _saving, onTap: _canNext ? _next : null)),
      ]),
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Question ${_index + 1} of $total', style: T.labelMd.c(AppColors.onSurfaceVariant))),
            Text('About $mins min left', style: T.labelMd.c(AppColors.onSurfaceVariant)),
          ]),
          const SizedBox(height: 8),
          Bar(value: (_index + 1) / total, color: AppColors.primary),
        ]),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(key: ValueKey(_index), child: _question(section)),
        ),
        const PrivacyNote('Your answers are confidential. The university only sees anonymised, grouped results, and only with your consent.'),
      ],
    );
  }

  Widget _question(ASection section) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(_q.categoryIcon, size: 18, color: AppColors.primary, fill: 1),
          const SizedBox(width: 6),
          Flexible(child: Text(_q.category, style: T.labelMd.semi.c(AppColors.primary))),
        ]),
        const SizedBox(height: 8),
        Text(_q.text, style: T.headlineMd.lh(1.25)),
        if (_q.help.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(_q.help, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ],
        const SizedBox(height: Sp.lg),
        if (_q.type == AType.choice) ListGroup(dividerIndent: 16, children: [for (final o in _q.options) _option(o)]) else _numberInput(),
      ]);

  Widget _option(AOption o) {
    final on = _answers[_q.id] == o.value;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _answers[_q.id] = o.value);
      },
      child: Container(
        color: on ? AppColors.tint(AppColors.primary) : null,
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.title, style: T.bodyLg.w(on ? FontWeight.w600 : FontWeight.w400)),
              if (o.subtitle != null) Text(o.subtitle!, style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 12),
          Icon(on ? Symbols.radio_button_checked_rounded : Symbols.radio_button_unchecked_rounded, size: 22, color: on ? AppColors.primary : AppColors.outline),
        ]),
      ),
    );
  }

  Widget _numberInput() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _numCtrl,
          autofocus: false,
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: T.metric(28),
          decoration: InputDecoration(
            hintText: 'Enter value',
            hintStyle: T.bodyLg.c(AppColors.outline),
            suffixText: _q.unit,
            suffixStyle: T.bodyLg.c(AppColors.onSurfaceVariant),
            errorText: _numCtrl.text.isNotEmpty && !_canNext ? 'Enter a value between ${_q.min?.round()} and ${_q.max?.round()} ${_q.unit ?? ''}'.trim() : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        if (_q.optional) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextLinkButton("I don't know, skip", onTap: () {
              _numCtrl.clear();
              _next();
            }),
          ),
        ],
      ]);
}

// ---------------------------------------------------------------------------
// Assessment complete
// ---------------------------------------------------------------------------

class AssessmentCompleteScreen extends StatelessWidget {
  const AssessmentCompleteScreen({super.key, this.assessment});
  final Rec? assessment;

  @override
  Widget build(BuildContext context) {
    final done = assessment?['completed_at'] == null ? DateTime.now() : DateTime.parse(assessment!['completed_at']).toLocal();
    return VPage(
      header: TitleHeader('', close: true, onLeading: () => context.go('/home')),
      bottom: PrimaryButton('Done', onTap: () => context.go('/home')),
      children: [
        const SizedBox(height: Sp.lg),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: AppColors.tint(AppColors.tertiary), shape: BoxShape.circle),
            child: Icon(Symbols.check_rounded, size: 44, color: AppColors.tertiary, weight: 600),
          ),
        ),
        Column(children: [
          Text('Assessment complete', style: T.headlineLg, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Recorded on ${DateFormat('d MMMM yyyy').format(done)}', style: T.bodyMd.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: Sp.md),
          Text('Thanks for taking the time. Your measurements have been updated and your results are in Progress.',
              textAlign: TextAlign.center, style: T.bodyLg.c(AppColors.onSurfaceVariant)),
        ]),
        ListGroup(children: [
          ListRow(icon: Symbols.summarize_rounded, color: AppColors.primary, title: 'View summary', onTap: assessment == null ? null : () => showAssessmentSummary(context, assessment!)),
          ListRow(icon: Symbols.insights_rounded, color: AppColors.water, title: 'Open Progress', onTap: () => context.go('/progress')),
        ]),
        const PrivacyNote('Individual answers are never shared with lecturers or your faculty.'),
      ],
    );
  }
}
