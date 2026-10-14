import 'dart:async';

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
// Health Assessments: status & history
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
      body: 'Your ${w['term']} assessment is now open. It takes about 6 minutes.',
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
              Row(children: [
                ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/icons3d/assessment.jpg', width: 64, height: 64, fit: BoxFit.cover)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('A short check-in every six months from the university health administration, covering ten areas of student life. About 6 minutes.',
                      style: T.bodyLg.c(AppColors.onSurfaceVariant)),
                ),
              ]),
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
                        ? 'The university will announce the next window. You will get a reminder.'
                        : isOpen
                            ? 'Closes ${DateFormat('d MMMM').format(DateTime.parse(target['closes_at']).toLocal())}. No preparation needed.'
                            : 'Opens ${DateFormat('d MMMM').format(DateTime.parse(target['opens_at']).toLocal())} for one week. No preparation needed.',
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

/// Colour for a 0 to 100 well-being score.
Color domainColor(num v) => v >= 75 ? AppColors.tertiary : (v >= 55 ? AppColors.water : (v >= 35 ? AppColors.warning : AppColors.error));

/// The ten domain scores as labelled bars.
class DomainBars extends StatelessWidget {
  const DomainBars({super.key, required this.domains});
  final Map<String, dynamic> domains;

  @override
  Widget build(BuildContext context) {
    final ids = domains.keys.map(int.tryParse).whereType<int>().toList()..sort();
    return Column(children: [
      for (final id in ids)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Icon(defaultDomains.where((d) => d.id == id).firstOrNull?.iconData ?? Symbols.assignment_rounded, size: 18, color: domainColor(domains['$id'] as num)),
            const SizedBox(width: 8),
            SizedBox(width: 128, child: Text(domainShortNames[id] ?? 'Area $id', style: T.labelMd, maxLines: 2)),
            const SizedBox(width: 8),
            Expanded(child: Bar(value: (domains['$id'] as num) / 100, height: 8, color: domainColor(domains['$id'] as num))),
            const SizedBox(width: 8),
            SizedBox(width: 28, child: Text('${domains['$id']}', textAlign: TextAlign.right, style: T.labelMd.tnum)),
          ]),
        ),
    ]);
  }
}

Future<void> showAssessmentSummary(BuildContext context, Rec a) {
  final s = Map<String, dynamic>.from(a['scores'] ?? {});
  final domains = Map<String, dynamic>.from(s['domains'] ?? {});
  String stressLabel(num v) => v <= 6 ? 'low' : (v <= 10 ? 'moderate' : 'high');
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
        if (domains.isNotEmpty) ...[
          Text('Your well-being by area (out of 100)', style: T.labelLg),
          const SizedBox(height: Sp.sm),
          DomainBars(domains: domains),
        ],
        ListGroup(children: [
          if (s['bmi'] != null) ListRow(icon: Symbols.monitor_weight_rounded, color: AppColors.body, title: 'BMI', value: '${s['bmi']}', chevron: false),
          if (s['whr'] != null) ListRow(icon: Symbols.straighten_rounded, color: AppColors.body, title: 'Waist-to-hip ratio', value: '${s['whr']}', chevron: false),
          if (s['stress'] != null)
            ListRow(icon: Symbols.psychology_rounded, color: AppColors.mind, title: 'Perceived stress (PSS-4)', value: '${s['stress']} / 16, ${stressLabel(s['stress'] as num)}', chevron: false),
          // Older assessments kept these scores.
          if (s['diet_score'] != null) ListRow(icon: Symbols.restaurant_rounded, color: AppColors.nutrition, title: 'Eating habits', value: '${s['diet_score']} / 10', chevron: false),
          if (s['activity_days'] != null) ListRow(icon: Symbols.directions_walk_rounded, color: AppColors.activity, title: 'Active days last week', value: '${s['activity_days']}', chevron: false),
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
  List<AQuestion> _questions = defaultQuestions;
  List<ADomain> _domains = defaultDomains;
  Map<String, dynamic> _answers = {};
  int _index = 0;
  bool _intro = true;
  bool _saving = false;
  bool _advancing = false;
  final _numCtrl = TextEditingController();
  final _textCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _numCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final (open, _) = await Repo.currentAndNextWindow();
      if (open == null) {
        _error = 'There is no assessment open for your faculty right now.';
      } else {
        try {
          final qs = await Repo.assessmentQuestions();
          if (qs.isNotEmpty) _questions = [for (final q in qs) AQuestion.fromJson(q)];
          final ds = await Repo.assessmentDomains();
          if (ds.isNotEmpty) _domains = [for (final d in ds) ADomain.fromJson(d)];
        } catch (e) {
          debugPrint('assessment questions: $e');
        }
        final a = await Repo.startAssessment(open);
        if (a['status'] == 'completed') {
          if (mounted) context.pushReplacement('/assessments/complete', extra: a);
          return;
        }
        _assessment = a;
        _answers = Map<String, dynamic>.from(a['answers'] ?? {});
        _index = (a['current_index'] as int? ?? 0).clamp(0, _questions.length - 1);
        _intro = _answers.isEmpty && _index == 0;
        final p = AppState.instance.profile;
        final profileValues = {'height_cm': p?.heightCm, 'weight_kg': p?.weightKg, 'waist_cm': p?.waistCm, 'hip_cm': p?.hipCm};
        for (final q in _questions) {
          final v = profileValues[q.prefill];
          if (v != null) _answers.putIfAbsent(q.id, () => double.parse(v.toStringAsFixed(1)));
        }
        _syncFields();
      }
    } catch (e) {
      _error = 'Could not load the assessment. Please check your connection.';
    }
    if (mounted) setState(() => _loading = false);
  }

  AQuestion get _q => _questions[_index];
  ADomain get _domain => _domains.firstWhere((d) => d.id == _q.domain, orElse: () => defaultDomains.firstWhere((d) => d.id == _q.domain, orElse: () => defaultDomains.first));
  List<int> get _domainOrder => _questions.map((q) => q.domain).toSet().toList();

  void _syncFields() {
    final v = _answers[_q.id];
    if (_q.kind == AKind.number) _numCtrl.text = v == null ? '' : (v is num && v == v.roundToDouble() ? v.toInt().toString() : '$v');
    if (_q.kind == AKind.text) _textCtrl.text = v?.toString() ?? '';
  }

  bool get _canNext => switch (_q.kind) {
        AKind.single || AKind.scale => _answers[_q.id] != null,
        AKind.multi => (_answers[_q.id] as List?)?.isNotEmpty ?? false,
        AKind.text => true,
        AKind.number => _numCtrl.text.isEmpty ? _q.optional : (() {
            final v = double.tryParse(_numCtrl.text);
            return v != null && v >= (_q.min ?? 0) && v <= (_q.max ?? 99999);
          })(),
      };

  void _captureField() {
    if (_q.kind == AKind.number) {
      final v = double.tryParse(_numCtrl.text);
      v == null ? _answers.remove(_q.id) : _answers[_q.id] = v;
    }
    if (_q.kind == AKind.text) {
      final t = _textCtrl.text.trim();
      t.isEmpty ? _answers.remove(_q.id) : _answers[_q.id] = t;
    }
  }

  Future<void> _next() async {
    _captureField();
    if (_index == _questions.length - 1) return _submit();
    setState(() {
      _index++;
      _syncFields();
    });
    unawaited(Repo.saveAssessmentProgress(_assessment!['id'], _answers, _index).catchError((_) {}));
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final (scores, label) = scoreAssessment(_questions, _answers);
      await Repo.completeAssessment(_assessment!['id'], _answers, scores, label);
      // Keep the personal profile in sync with freshly measured values.
      final update = <String, dynamic>{};
      for (final q in _questions.where((q) => q.prefill != null)) {
        if (_answers[q.id] != null) update[q.prefill!] = _answers[q.id];
      }
      if (update.isNotEmpty) {
        update['measured_at'] = DateTime.now().toUtc().toIso8601String();
        await AppState.instance.updateProfile(update);
      }
      if (mounted) context.pushReplacement('/assessments/complete', extra: {..._assessment!, 'completed_at': DateTime.now().toUtc().toIso8601String(), 'scores': scores, 'result_label': label});
    } catch (e) {
      if (mounted) toast(context, 'Could not submit. Please check your connection and try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Single choice and scale questions move on by themselves after a beat,
  /// so the choice is visible before the next question slides in.
  void _pick(String value) {
    if (_advancing) return;
    HapticFeedback.selectionClick();
    setState(() {
      _answers[_q.id] = value;
      _advancing = true;
    });
    Future.delayed(const Duration(milliseconds: 280), () async {
      if (!mounted) return;
      _advancing = false;
      await _next();
    });
  }

  void _toggleMulti(AOption o) {
    HapticFeedback.selectionClick();
    final list = List<String>.from((_answers[_q.id] as List?) ?? const []);
    final exclusive = o.value == 'none';
    setState(() {
      if (list.contains(o.value)) {
        list.remove(o.value);
      } else if (exclusive) {
        list
          ..clear()
          ..add(o.value);
      } else {
        list.remove('none');
        if (_q.maxChoices != null && list.length >= _q.maxChoices!) {
          toast(context, 'Pick up to ${_q.maxChoices}.');
          return;
        }
        list.add(o.value);
      }
      list.isEmpty ? _answers.remove(_q.id) : _answers[_q.id] = list;
    });
  }

  void _back() {
    if (_index == 0) {
      setState(() => _intro = true);
      return;
    }
    _captureField();
    setState(() {
      _index--;
      _syncFields();
    });
  }

  Future<void> _saveAndExit() async {
    if (_assessment != null) {
      _captureField();
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
    if (_intro) return _introPage();

    final total = _questions.length;
    final remaining = total - _index;
    final mins = (remaining * 10 / 60).ceil();
    final last = _index == total - 1;
    final order = _domainOrder;
    final sectionNo = order.indexOf(_q.domain) + 1;
    final autoAdvance = _q.kind == AKind.single || _q.kind == AKind.scale;
    final firstOfDomain = _index == 0 || _questions[_index - 1].domain != _q.domain;

    return VPage(
      header: TitleHeader('Section $sectionNo of ${order.length}', close: true, onLeading: _saveAndExit),
      spacing: Sp.lg,
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!autoAdvance || _answers[_q.id] != null)
          PrimaryButton(
            last ? 'Submit' : (_q.kind == AKind.text && _textCtrl.text.trim().isEmpty ? 'Skip' : 'Next'),
            loading: _saving,
            onTap: _canNext && !_advancing ? _next : null,
          ),
        if (autoAdvance && _answers[_q.id] == null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Tap an answer to move on', style: T.bodySm.c(AppColors.onSurfaceVariant))),
        TextLinkButton(_index == 0 ? 'Back to the introduction' : 'Go to previous question', leading: Symbols.arrow_back_rounded, color: AppColors.onSurfaceVariant, onTap: _saving ? null : _back),
      ]),
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Question ${_index + 1} of $total', style: T.labelMd.c(AppColors.onSurfaceVariant))),
            Text(mins <= 1 ? 'Almost done' : 'About $mins min left', style: T.labelMd.c(AppColors.onSurfaceVariant)),
          ]),
          const SizedBox(height: 8),
          Bar(value: (_index + 1) / total, color: AppColors.primary),
          const SizedBox(height: 10),
          // One dot per area, filled as they are completed.
          Row(children: [
            for (int i = 0; i < order.length; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == order.length - 1 ? 0 : 3),
                  decoration: BoxDecoration(color: i < sectionNo ? AppColors.primary.withValues(alpha: i == sectionNo - 1 ? 1 : 0.45) : AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ]),
        ]),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: child)),
          child: KeyedSubtree(key: ValueKey(_index), child: _question(firstOfDomain)),
        ),
        const PrivacyNote('Answers are pooled with other students. The administration never sees your name or individual answers.'),
      ],
    );
  }

  Widget _introPage() {
    return VPage(
      header: TitleHeader('Health assessment', close: true, onLeading: _saveAndExit),
      bottom: PrimaryButton(_answers.length > 4 ? 'Continue where I left off' : 'Begin', onTap: () => setState(() => _intro = false)),
      children: [
        Center(child: ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.asset('assets/icons3d/assessment.jpg', width: 132, height: 132, fit: BoxFit.cover))),
        Column(children: [
          Text('From the university health administration', style: T.labelMd.c(AppColors.primary), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Your six-monthly health check-in', style: T.headlineLg, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('These questions help the university understand the overall health of its students. Your answers support future health and nutrition programmes on campus.',
              textAlign: TextAlign.center, style: T.bodyLg.c(AppColors.onSurfaceVariant)),
        ]),
        ListGroup(children: [
          ListRow(icon: Symbols.groups_rounded, color: AppColors.primary, title: 'Used only as a group overview', subtitle: 'Results are pooled, and nothing is shown for groups smaller than five', chevron: false),
          ListRow(icon: Symbols.visibility_off_rounded, color: AppColors.mind, title: 'No personal identifiers', subtitle: 'Your name, registration number and contact details are never part of the results', chevron: false),
          ListRow(icon: Symbols.timer_rounded, color: AppColors.warning, title: 'About 6 minutes', subtitle: '${_domainOrder.length} short sections. Most questions are one tap', chevron: false),
          ListRow(icon: Symbols.save_rounded, color: AppColors.tertiary, title: 'Saves as you go', subtitle: 'Close any time and continue later this week', chevron: false),
        ]),
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
          for (final id in _domainOrder) TagPill(domainShortNames[id] ?? 'Area $id', icon: _domains.firstWhere((d) => d.id == id, orElse: () => defaultDomains.first).iconData, bg: AppColors.surfaceContainer),
        ]),
      ],
    );
  }

  Widget _question(bool firstOfDomain) {
    final d = _domain;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        IconCircle(d.iconData, size: 30, iconSize: 17, fg: AppColors.primary, radius: 9, fill: 1),
        const SizedBox(width: 8),
        Expanded(child: Text(d.title, style: T.labelMd.semi.c(AppColors.primary))),
      ]),
      if (firstOfDomain && d.blurb.isNotEmpty) ...[
        const SizedBox(height: 4),
        Padding(padding: const EdgeInsets.only(left: 38), child: Text(d.blurb, style: T.bodySm.c(AppColors.onSurfaceVariant))),
      ],
      const SizedBox(height: Sp.md),
      Text(_q.text, style: T.headlineMd.lh(1.25)),
      if ((_q.help ?? '').isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(_q.help!, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
      ],
      const SizedBox(height: Sp.lg),
      switch (_q.kind) {
        AKind.single => Column(children: [for (final o in _q.options) _option(o)]),
        AKind.scale => _scale(),
        AKind.multi => _multi(),
        AKind.number => _numberInput(),
        AKind.text => VTextField(controller: _textCtrl, hint: 'Type here (optional)', maxLines: 4, onChanged: (_) => setState(() {})),
      },
    ]);
  }

  Widget _option(AOption o) {
    final on = _answers[_q.id] == o.value;
    final c = AppColors.primary;
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
            onTap: () => _pick(o.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 14),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o.label, style: T.bodyLg.w(FontWeight.w700)),
                    if (o.hint != null) Text(o.hint!, style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  ]),
                ),
                Icon(on ? Symbols.check_circle_rounded : Symbols.radio_button_unchecked_rounded, color: on ? c : AppColors.outline, fill: on ? 1 : 0),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// Five faces from low to high, for 1 to 5 ratings.
  Widget _scale() {
    const faces = [
      Symbols.sentiment_very_dissatisfied_rounded,
      Symbols.sentiment_dissatisfied_rounded,
      Symbols.sentiment_neutral_rounded,
      Symbols.sentiment_satisfied_rounded,
      Symbols.sentiment_very_satisfied_rounded,
    ];
    final colors = [AppColors.error, AppColors.activity, AppColors.warning, AppColors.water, AppColors.tertiary];
    final opts = _q.options;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (int i = 0; i < opts.length; i++)
        Expanded(
          child: Builder(builder: (context) {
            final on = _answers[_q.id] == opts[i].value;
            final c = colors[(i * (colors.length - 1) / (opts.length - 1).clamp(1, 99)).round()];
            return GestureDetector(
              onTap: () => _pick(opts[i].value),
              behavior: HitTestBehavior.opaque,
              child: Column(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? c : c.withValues(alpha: AppColors.isDark ? 0.18 : 0.10),
                    border: Border.all(color: on ? c : Colors.transparent, width: 2),
                  ),
                  child: AnimatedScale(
                    scale: on ? 1.15 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(faces[(i * (faces.length - 1) / (opts.length - 1).clamp(1, 99)).round()], size: 32, color: on ? Colors.white : c, fill: 1),
                  ),
                ),
                const SizedBox(height: 6),
                Text(opts[i].label, style: T.labelSm.c(on ? AppColors.onSurface : AppColors.onSurfaceVariant).w(on ? FontWeight.w800 : FontWeight.w600), textAlign: TextAlign.center, maxLines: 2),
              ]),
            );
          }),
        ),
    ]);
  }

  Widget _multi() {
    final picked = List<String>.from((_answers[_q.id] as List?) ?? const []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_q.maxChoices != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${picked.length} of ${_q.maxChoices} picked', style: T.labelMd.c(AppColors.primary))),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in _q.options)
          VChip(o.label, icon: picked.contains(o.value) ? Symbols.check_rounded : null, selected: picked.contains(o.value), selectedColor: o.value == 'none' ? AppColors.onSurfaceVariant : AppColors.primary, onTap: () => _toggleMulti(o)),
      ]),
    ]);
  }

  Widget _numberInput() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: _numCtrl,
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
        if (_q.prefill != null && _answers[_q.id] != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Symbols.person_check_rounded, size: 16, color: AppColors.tertiary, fill: 1),
            const SizedBox(width: 6),
            Expanded(child: Text('From your profile. Tap Next if it is still right.', style: T.bodySm.c(AppColors.onSurfaceVariant))),
          ]),
        ],
        if (_q.optional) ...[
          const SizedBox(height: 4),
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
    final scores = Map<String, dynamic>.from(assessment?['scores'] ?? {});
    final domains = Map<String, dynamic>.from(scores['domains'] ?? {});
    return VPage(
      header: TitleHeader('', close: true, onLeading: () => context.go('/home')),
      bottom: PrimaryButton('Done', onTap: () => context.go('/home')),
      children: [
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: AppColors.tint(AppColors.tertiary), shape: BoxShape.circle),
            child: Icon(Symbols.check_rounded, size: 44, color: AppColors.tertiary, weight: 600),
          ),
        ),
        Column(children: [
          Text('Thank you!', style: T.headlineLg, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Recorded on ${DateFormat('d MMMM yyyy').format(done)}', style: T.bodyMd.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: Sp.md),
          Text('Your answers join those of other students to help the university plan better health and nutrition support. Your measurements in VitalU have been updated too.',
              textAlign: TextAlign.center, style: T.bodyLg.c(AppColors.onSurfaceVariant)),
        ]),
        if (domains.isNotEmpty)
          VCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Your snapshot', style: T.headlineSm),
              const SizedBox(height: 2),
              Text('Well-being by area, out of 100. Higher is healthier. Only you can see this.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              const SizedBox(height: Sp.md),
              DomainBars(domains: domains),
            ]),
          ),
        ListGroup(children: [
          ListRow(icon: Symbols.summarize_rounded, color: AppColors.primary, title: 'View summary', onTap: assessment == null ? null : () => showAssessmentSummary(context, assessment!)),
          ListRow(icon: Symbols.insights_rounded, color: AppColors.water, title: 'Open my progress', onTap: () => context.go('/progress')),
        ]),
        const PrivacyNote('The administration only sees pooled results from groups of five or more students, never your individual answers.'),
      ],
    );
  }
}
