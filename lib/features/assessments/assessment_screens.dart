import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
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
      body: 'Your ${w['term']} is now open. It takes about 7 minutes.',
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
    String d(String k) => DateFormat('d MMMM').format(DateTime.parse(target![k]).toLocal());

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
                  child: Text('A short check-in every six months from the university health administration, covering ten areas of student life. About 7 minutes.',
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
                  Text(target == null ? 'To be announced' : (target['term'] ?? DateFormat('MMMM yyyy').format(DateTime.parse(target['opens_at']).toLocal())), style: T.headlineLg),
                  const SizedBox(height: 6),
                  Text(
                    target == null
                        ? 'The university will announce the next window. You will get a reminder.'
                        : isOpen
                            ? 'Open from ${d('opens_at')} to ${d('closes_at')}. No preparation needed.'
                            : 'Opens ${d('opens_at')} and stays open until ${d('closes_at')}.',
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

/// The domain scores as labelled bars.
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
          if (s['phq2'] != null)
            ListRow(icon: Symbols.psychology_rounded, color: AppColors.mind, title: 'Mood screen (PHQ-2)', value: '${s['phq2']} / 6${(s['phq2_positive'] ?? false) == true ? ', worth a chat' : ''}', chevron: false),
          // Older assessments kept the PSS-4 stress score.
          if (s['stress'] != null) ListRow(icon: Symbols.psychology_rounded, color: AppColors.mind, title: 'Perceived stress (PSS-4)', value: '${s['stress']} / 16', chevron: false),
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
  Rec? _window;
  List<AQuestion> _questions = [];
  List<ADomain> _domains = defaultDomains;
  Map<String, dynamic> _answers = {};

  /// Id of the first question on the page being shown.
  String? _current;
  bool _intro = true;
  bool _saving = false;
  bool _advancing = false;
  final _ctrls = <String, TextEditingController>{};
  final _textCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final (open, _) = await Repo.currentAndNextWindow();
      if (open == null) {
        _error = 'There is no assessment open for your faculty right now.';
      } else {
        _window = open;
        var domains = <ADomain>[];
        var questions = <AQuestion>[];
        try {
          final qs = await Repo.assessmentQuestions();
          questions = [for (final q in qs) AQuestion.fromJson(q)];
          final ds = await Repo.assessmentDomains();
          domains = [for (final d in ds) ADomain.fromJson(d)];
        } catch (e) {
          debugPrint('assessment questions: $e');
        }
        if (questions.isEmpty) (domains, questions) = await bundledQuestionnaire();
        if (domains.isNotEmpty) _domains = domains;
        // Sections the administration switched off are not asked this round.
        final hidden = {for (final d in _domains) if (!d.active) d.id};
        _questions = questions.where((q) => !hidden.contains(q.domain)).toList();

        final a = await Repo.startAssessment(open);
        if (a['status'] == 'completed') {
          if (mounted) context.pushReplacement('/assessments/complete', extra: a);
          return;
        }
        _assessment = a;
        _answers = Map<String, dynamic>.from(a['answers'] ?? {});
        final i = (a['current_index'] as int? ?? 0).clamp(0, _questions.length - 1);
        _current = _questions[i].id;
        _intro = _answers.isEmpty && i == 0;
        await _prefill();
      }
    } catch (e) {
      debugPrint('assessment load: $e');
      _error = 'Could not load the assessment. Please check your connection.';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Fills answers the student has already given VitalU: body measurements,
  /// accommodation and the latest blood pressure and lab values.
  Future<void> _prefill() async {
    final p = AppState.instance.profile;
    LatestVitals v = const LatestVitals();
    try {
      v = await Repo.latestVitals();
    } catch (_) {}
    num? r1(num? x) => x == null ? null : double.parse(x.toStringAsFixed(1));
    final known = <String, Object?>{
      'height_cm': r1(p?.heightCm),
      'weight_kg': r1(p?.weightKg),
      'waist_cm': r1(p?.waistCm),
      'hip_cm': r1(p?.hipCm),
      'accommodation': p?.accommodation,
      'sbp': v.bp?.value.round(),
      'dbp': v.bp?.extra?.round(),
      'fbg': v.fastingGlucose?.value.round(),
      'tg': v.triglycerides?.value.round(),
    };
    for (final q in _questions) {
      final k = known[q.prefill];
      if (k != null) _answers.putIfAbsent(q.id, () => k);
    }
    _syncFields();
  }

  // --- Pages ----------------------------------------------------------------

  /// Questions that apply, grouped into pages: consecutive number questions
  /// of one section share a page; everything else has a page of its own.
  List<List<AQuestion>> get _pages {
    final out = <List<AQuestion>>[];
    for (final q in _questions.where((q) => q.visible(_answers))) {
      final last = out.isEmpty ? null : out.last;
      if (q.kind == AKind.number && last != null && last.first.kind == AKind.number && last.first.domain == q.domain) {
        last.add(q);
      } else {
        out.add([q]);
      }
    }
    return out;
  }

  int get _pageIndex {
    final pages = _pages;
    final i = pages.indexWhere((p) => p.any((q) => q.id == _current));
    return i < 0 ? 0 : i;
  }

  List<AQuestion> get _page => _pages[_pageIndex];
  AQuestion get _q => _page.first;
  ADomain get _domain => _domains.firstWhere((d) => d.id == _q.domain, orElse: () => defaultDomains.firstWhere((d) => d.id == _q.domain, orElse: () => defaultDomains.first));
  List<int> get _domainOrder => _questions.map((q) => q.domain).toSet().toList();

  TextEditingController _ctrl(String id) => _ctrls.putIfAbsent(id, TextEditingController.new);

  String _fmt(Object? v) => v == null ? '' : (v is num && v == v.roundToDouble() ? v.toInt().toString() : '$v');

  void _syncFields() {
    if (_current == null) return;
    for (final q in _page) {
      if (q.kind == AKind.number) _ctrl(q.id).text = _fmt(_answers[q.id]);
    }
    if (_q.kind == AKind.text) _textCtrl.text = _answers[_q.id]?.toString() ?? '';
  }

  bool _numberOk(AQuestion q) {
    final t = _ctrl(q.id).text;
    if (t.isEmpty) return q.optional;
    final v = double.tryParse(t);
    return v != null && v >= (q.min ?? 0) && v <= (q.max ?? 99999);
  }

  bool get _canNext => switch (_q.kind) {
        AKind.single || AKind.scale || AKind.profile => _answers[_q.id] != null,
        AKind.multi => _q.optional || ((_answers[_q.id] as List?)?.isNotEmpty ?? false),
        AKind.text => true,
        AKind.number => _page.every(_numberOk),
      };

  void _captureFields() {
    for (final q in _page) {
      if (q.kind == AKind.number) {
        final v = double.tryParse(_ctrl(q.id).text);
        v == null ? _answers.remove(q.id) : _answers[q.id] = v;
      }
    }
    if (_q.kind == AKind.text) {
      final t = _textCtrl.text.trim();
      t.isEmpty ? _answers.remove(_q.id) : _answers[_q.id] = t;
    }
  }

  Future<void> _next() async {
    _captureFields();
    final pages = _pages;
    final i = _pageIndex;
    if (i >= pages.length - 1) return _submit();
    setState(() {
      _current = pages[i + 1].first.id;
      _syncFields();
    });
    unawaited(Repo.saveAssessmentProgress(_assessment!['id'], _answers, _questions.indexWhere((q) => q.id == _current)).catchError((_) {}));
  }

  void _back() {
    final i = _pageIndex;
    if (i == 0) {
      setState(() => _intro = true);
      return;
    }
    _captureFields();
    setState(() {
      _current = _pages[i - 1].first.id;
      _syncFields();
    });
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final p = AppState.instance.profile;
      final (scores, label) = scoreAssessment(_questions, _answers, profile: p);
      await Repo.completeAssessment(_assessment!['id'], _answers, scores, label);
      await _saveMeasurements();
      if (mounted) context.pushReplacement('/assessments/complete', extra: {..._assessment!, 'completed_at': DateTime.now().toUtc().toIso8601String(), 'scores': scores, 'result_label': label});
    } catch (e) {
      debugPrint('assessment submit: $e');
      if (mounted) toast(context, 'Could not submit. Please check your connection and try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Keeps the profile and vitals in step with what was entered, with the
  /// date and where the values were measured.
  Future<void> _saveMeasurements() async {
    final source = _answers['k_source'] as String?;
    final measured = source != null && source != 'none';
    final when = switch (_answers['k_when']) {
      'month' => DateTime.now().subtract(const Duration(days: 14)),
      'six' => DateTime.now().subtract(const Duration(days: 90)),
      'older' => DateTime.now().subtract(const Duration(days: 240)),
      _ => DateTime.now(),
    };
    num? a(String k) => _answers[k] as num?;
    final update = <String, dynamic>{};
    if (measured) {
      for (final (q, f) in const [('k_height', 'height_cm'), ('k_weight', 'weight_kg'), ('k_waist', 'waist_cm'), ('k_hip', 'hip_cm')]) {
        if (a(q) != null) update[f] = a(q);
      }
      if (update.isNotEmpty) update['measured_at'] = when.toUtc().toIso8601String();
    }
    final living = _answers['f_living'] as String?;
    if (living != null && living != AppState.instance.profile?.accommodation) update['accommodation'] = living;
    if (update.isNotEmpty) {
      try {
        await AppState.instance.updateProfile({...update, if (measured && update.containsKey('measured_at')) 'measurement_source': source});
      } catch (_) {
        // The measurement_source column arrives with a database migration.
        await AppState.instance.updateProfile(update);
      }
    }
    if (measured && [a('k_sbp'), a('k_fbg'), a('k_tg'), a('k_chol')].any((x) => x != null)) {
      final bpOk = a('k_sbp') != null && a('k_dbp') != null;
      await Repo.saveVitals(
        systolic: bpOk ? a('k_sbp')!.round() : null,
        diastolic: bpOk ? a('k_dbp')!.round() : null,
        fastingGlucose: a('k_fbg')?.toDouble(),
        triglycerides: a('k_tg')?.toDouble(),
        cholesterol: a('k_chol')?.toDouble(),
        measuredOn: when,
        source: source,
      );
    }
  }

  /// One-tap questions move on by themselves after a beat, so the choice is
  /// visible before the next question slides in.
  void _pick(String value, {bool advance = true}) {
    if (_advancing) return;
    HapticFeedback.selectionClick();
    setState(() {
      _answers[_q.id] = value;
      if (advance) _advancing = true;
    });
    if (!advance) return;
    Future.delayed(const Duration(milliseconds: 320), () async {
      if (!mounted) return;
      _advancing = false;
      await _next();
    });
  }

  void _toggleMulti(AOption o) {
    HapticFeedback.selectionClick();
    final list = List<String>.from((_answers[_q.id] as List?) ?? const []);
    setState(() {
      if (list.contains(o.value)) {
        list.remove(o.value);
      } else if (o.exclusive) {
        list
          ..clear()
          ..add(o.value);
      } else {
        list.removeWhere((v) => v == 'none' || v == 'pns');
        if (_q.maxChoices != null && list.length >= _q.maxChoices!) {
          toast(context, 'Pick up to ${_q.maxChoices}.');
          return;
        }
        list.add(o.value);
      }
      list.isEmpty ? _answers.remove(_q.id) : _answers[_q.id] = list;
    });
  }

  Future<void> _saveAndExit() async {
    if (_assessment != null && _current != null) {
      _captureFields();
      try {
        await Repo.saveAssessmentProgress(_assessment!['id'], _answers, _questions.indexWhere((q) => q.id == _current));
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

    final pages = _pages;
    final pi = _pageIndex;
    final total = pages.length;
    final secs = (total - pi) * 9;
    final last = pi == total - 1;
    final order = _domainOrder;
    final sectionNo = order.indexOf(_q.domain) + 1;
    final autoAdvance = switch (_q.kind) {
      AKind.single => _q.style != 'slider',
      AKind.scale => true,
      _ => false,
    };
    final firstOfDomain = pi == 0 || pages[pi - 1].first.domain != _q.domain;

    return VPage(
      header: TitleHeader('Section $sectionNo of ${order.length}', close: true, onLeading: _saveAndExit),
      spacing: Sp.lg,
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!autoAdvance || _answers[_q.id] != null)
          PrimaryButton(
            last ? 'Submit' : ((_q.kind == AKind.text && _textCtrl.text.trim().isEmpty) || (_q.kind == AKind.multi && _q.optional && _answers[_q.id] == null) ? 'Skip' : 'Next'),
            loading: _saving,
            onTap: _canNext && !_advancing ? _next : null,
          ),
        if (autoAdvance && _answers[_q.id] == null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Tap an answer to move on', style: T.bodySm.c(AppColors.onSurfaceVariant))),
        TextLinkButton(pi == 0 ? 'Back to the introduction' : 'Go to previous question', leading: Symbols.arrow_back_rounded, color: AppColors.onSurfaceVariant, onTap: _saving ? null : _back),
      ]),
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Question ${pi + 1} of $total', style: T.labelMd.c(AppColors.onSurfaceVariant))),
            Text(secs <= 60 ? 'Almost done' : 'About ${(secs / 60).ceil()} min left', style: T.labelMd.c(AppColors.onSurfaceVariant)),
          ]),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(end: (pi + 1) / total),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Bar(value: v, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          // One segment per section, filled as they are completed.
          Row(children: [
            for (int i = 0; i < order.length; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  margin: EdgeInsets.only(right: i == order.length - 1 ? 0 : 3),
                  decoration: BoxDecoration(color: i < sectionNo ? AppColors.primary.withValues(alpha: i == sectionNo - 1 ? 1 : 0.45) : AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(2)),
                ),
              ),
          ]),
        ]),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: child)),
          child: KeyedSubtree(key: ValueKey(_current), child: _question(firstOfDomain)),
        ),
        PrivacyNote(_q.domain == 11
            ? 'Measurements are saved to your own profile with the date and where they were taken. The administration only sees pooled figures.'
            : 'Answers are pooled with other students. The administration never sees your name or individual answers.'),
      ],
    );
  }

  Widget _introPage() {
    return VPage(
      header: TitleHeader('Health assessment', close: true, onLeading: _saveAndExit),
      bottom: PrimaryButton(_answers.length > 4 ? 'Continue where I left off' : 'Begin', onTap: () => setState(() => _intro = false)),
      children: [
        Center(child: ClipRRect(borderRadius: BorderRadius.circular(28), child: Image.asset('assets/icons3d/assessment.jpg', width: 120, height: 120, fit: BoxFit.cover))),
        Column(children: [
          Text('From the university health administration', style: T.labelMd.c(AppColors.primary), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Your six-monthly health check-in', style: T.headlineLg, textAlign: TextAlign.center),
          if (_window != null) ...[
            const SizedBox(height: 6),
            Text(
              'Open ${DateFormat('d MMM').format(DateTime.parse(_window!['opens_at']).toLocal())} to ${DateFormat('d MMM yyyy').format(DateTime.parse(_window!['closes_at']).toLocal())}',
              style: T.labelMd.c(AppColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 8),
          Text(
              'The administration uses these answers only to build an overall picture of student health. No personal identifiers are used, and the results guide future health and nutrition programmes on campus.',
              textAlign: TextAlign.center,
              style: T.bodyLg.c(AppColors.onSurfaceVariant)),
        ]),
        const _WhyItMatters(),
        ListGroup(children: [
          ListRow(icon: Symbols.groups_rounded, color: AppColors.primary, title: 'Used only as a group overview', subtitle: 'Results are pooled, and nothing is shown for groups smaller than five', chevron: false),
          ListRow(icon: Symbols.visibility_off_rounded, color: AppColors.mind, title: 'No personal identifiers', subtitle: 'Your name, registration number and contact details are never part of the results', chevron: false),
          ListRow(icon: Symbols.timer_rounded, color: AppColors.warning, title: 'About ${(_pages.length * 9 / 60).ceil()} minutes', subtitle: '${_domainOrder.length} short sections. Most questions are one tap', chevron: false),
          ListRow(icon: Symbols.save_rounded, color: AppColors.tertiary, title: 'Saves as you go', subtitle: 'Close any time and continue later while it is open', chevron: false),
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
      if (_q.image != null) ...[_QuestionImage(asset: 'assets/${_q.image}'), const SizedBox(height: Sp.md)],
      if (_q.kind != AKind.number) ...[
        Text(_q.text, style: T.headlineMd.lh(1.25)),
        if ((_q.help ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          _q.style == 'days' ? _ServingHint(_q.help!) : Text(_q.help!, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ],
      ] else
        Text(_page.length > 1 ? 'Enter the values you have' : _q.text, style: T.headlineMd.lh(1.25)),
      const SizedBox(height: Sp.lg),
      switch (_q.kind) {
        AKind.single => switch (_q.style) {
            'days' => _days(),
            'faces' => _faces(),
            'slider' => _slider(),
            _ => Column(children: [for (final o in _q.options) _option(o)]),
          },
        AKind.scale => _faces(),
        AKind.multi => _multi(),
        AKind.number => _numbers(),
        AKind.text => VTextField(controller: _textCtrl, hint: 'Type here (optional)', maxLines: 4, onChanged: (_) => setState(() {})),
        AKind.profile => _profileConfirm(),
      },
    ]);
  }

  Widget _option(AOption o) {
    final on = _answers[_q.id] == o.value;
    final c = AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedScale(
        scale: on ? 1.02 : 1,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
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
      ),
    );
  }

  /// Days-of-the-week answers: each choice shows how many of seven days it
  /// means, as a row of dots.
  Widget _days() {
    int daysOf(String v) => switch (v) {
          '0' => 0,
          '7' => 7,
          _ => int.tryParse(v.split('-').last) ?? 0,
        };
    final c = AppColors.nutrition;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.05,
      children: [
        for (final o in _q.options)
          Builder(builder: (context) {
            final on = _answers[_q.id] == o.value;
            final n = daysOf(o.value);
            return AnimatedScale(
              scale: on ? 1.04 : 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(o.label, style: T.labelLg.w(FontWeight.w800).c(on ? c : AppColors.onSurface)),
                        const SizedBox(height: 6),
                        Row(children: [
                          for (int i = 0; i < 7; i++)
                            Expanded(
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 160 + i * 40),
                                height: 8,
                                margin: EdgeInsets.only(right: i == 6 ? 0 : 3),
                                decoration: BoxDecoration(
                                  color: i < n ? (on ? c : c.withValues(alpha: 0.55)) : AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  /// Faces from unhappy to happy. The face follows the answer's score, so
  /// "Not at all" on a symptom question is the happy face.
  Widget _faces() {
    const faces = [
      Symbols.sentiment_very_dissatisfied_rounded,
      Symbols.sentiment_dissatisfied_rounded,
      Symbols.sentiment_neutral_rounded,
      Symbols.sentiment_satisfied_rounded,
      Symbols.sentiment_very_satisfied_rounded,
    ];
    final colors = [AppColors.error, AppColors.activity, AppColors.warning, AppColors.water, AppColors.tertiary];
    final opts = _q.options;
    final maxScore = opts.map((o) => o.score ?? 0).fold<num>(0, (a, b) => b > a ? b : a);
    int level(int i) {
      final s = opts[i].score;
      if (s != null && maxScore > 0) return (s / maxScore * 4).round();
      return (i * 4 / (opts.length - 1).clamp(1, 99)).round();
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (int i = 0; i < opts.length; i++)
        Expanded(
          child: Builder(builder: (context) {
            final on = _answers[_q.id] == opts[i].value;
            final c = colors[level(i)];
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
                    scale: on ? 1.18 : 1,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Icon(faces[level(i)], size: 32, color: on ? Colors.white : c, fill: 1),
                  ),
                ),
                const SizedBox(height: 6),
                Text(opts[i].label, style: T.labelSm.c(on ? AppColors.onSurface : AppColors.onSurfaceVariant).w(on ? FontWeight.w800 : FontWeight.w600), textAlign: TextAlign.center, maxLines: 3),
              ]),
            );
          }),
        ),
    ]);
  }

  /// An illustrated slider: the picture changes as the student slides.
  Widget _slider() {
    final opts = _q.options;
    final i = opts.indexWhere((o) => o.value == _answers[_q.id]);
    final cur = i < 0 ? null : opts[i];
    final shown = cur ?? opts[opts.length ~/ 2];
    final c = AppColors.primary;
    Widget art(AOption o) => o.image != null
        ? ClipRRect(borderRadius: BorderRadius.circular(Rad.xl), child: Image.asset('assets/${o.image}', height: 190, fit: BoxFit.contain))
        : Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.tint(AppColors.sleep)),
            child: Icon(iconByName(o.icon), size: 76, color: AppColors.sleep, fill: 1),
          );
    return Column(children: [
      SizedBox(
        height: 200,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          transitionBuilder: (child, a) => ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: FadeTransition(opacity: a, child: child)),
          child: Opacity(key: ValueKey(shown.value), opacity: cur == null ? 0.45 : 1, child: Center(child: art(shown))),
        ),
      ),
      const SizedBox(height: 10),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: Column(key: ValueKey(cur?.value), children: [
          Text(cur?.label ?? 'Slide to choose', style: T.headlineSm.c(cur == null ? AppColors.onSurfaceVariant : c)),
          if (cur?.hint != null) Text(cur!.hint!, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ]),
      ),
      const SizedBox(height: 8),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(trackHeight: 6, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 13)),
        child: Slider(
          value: (i < 0 ? opts.length ~/ 2 : i).toDouble(),
          min: 0,
          max: (opts.length - 1).toDouble(),
          divisions: opts.length - 1,
          activeColor: cur == null ? AppColors.outlineVariant : c,
          onChanged: (v) => _pick(opts[v.round()].value, advance: false),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          Expanded(child: Text(opts.first.hint ?? opts.first.label, style: T.labelSm.c(AppColors.onSurfaceVariant))),
          Text(opts.last.hint ?? opts.last.label, style: T.labelSm.c(AppColors.onSurfaceVariant)),
        ]),
      ),
    ]);
  }

  Widget _multi() {
    final picked = List<String>.from((_answers[_q.id] as List?) ?? const []);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_q.maxChoices != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('${picked.length} of ${_q.maxChoices} picked', style: T.labelMd.c(AppColors.primary))),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in _q.options)
          VChip(o.label, icon: picked.contains(o.value) ? Symbols.check_rounded : null, selected: picked.contains(o.value), selectedColor: o.exclusive ? AppColors.onSurfaceVariant : AppColors.primary, onTap: () => _toggleMulti(o)),
      ]),
    ]);
  }

  /// The number questions of this page, as one short form.
  Widget _numbers() {
    final fromProfile = _page.any((q) => q.prefill != null && _answers[q.id] != null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final q in _page) ...[
        Text(q.text, style: T.labelLg.semi),
        if (q.help != null) Text(q.help!, style: T.bodySm.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: _ctrl(q.id),
          onChanged: (_) => setState(() {}),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: T.metric(20),
          decoration: InputDecoration(
            hintText: q.optional ? 'Leave blank if unknown' : 'Enter value',
            hintStyle: T.bodyMd.c(AppColors.outline),
            suffixText: q.unit,
            suffixStyle: T.bodyLg.c(AppColors.onSurfaceVariant),
            errorText: _ctrl(q.id).text.isNotEmpty && !_numberOk(q) ? 'Between ${q.min?.round()} and ${q.max?.round()} ${q.unit ?? ''}'.trim() : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),
      ],
      if (fromProfile)
        Row(children: [
          Icon(Symbols.person_check_rounded, size: 16, color: AppColors.tertiary, fill: 1),
          const SizedBox(width: 6),
          Expanded(child: Text('Some values came from your profile. Change any that are out of date.', style: T.bodySm.c(AppColors.onSurfaceVariant))),
        ]),
    ]);
  }

  /// Shows age, faculty, academic year and accommodation from the profile.
  Widget _profileConfirm() {
    final p = AppState.instance.profile;
    String v(String? s) => (s == null || s.isEmpty) ? 'Not set' : s;
    final rows = [
      (Symbols.cake_rounded, 'Age', p?.age == null ? 'Not set' : '${p!.age} years'),
      (Symbols.school_rounded, 'Faculty', v(p?.faculty?.replaceFirst('Faculty of ', ''))),
      (Symbols.calendar_month_rounded, 'Academic year', v(p?.academicYear)),
      (Symbols.home_rounded, 'Accommodation', accommodationOptions[p?.accommodation] ?? 'Not set'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      ListGroup(children: [for (final r in rows) ListRow(icon: r.$1, color: AppColors.primary, title: r.$2, value: r.$3, chevron: false)]),
      const SizedBox(height: Sp.md),
      _option(_q.options.first),
      SoftButton('Update my details', icon: Symbols.edit_rounded, onTap: () async {
        await context.push('/profile/edit');
        if (!mounted) return;
        setState(() => _answers[_q.id] = _q.options.length > 1 ? _q.options[1].value : 'updated');
      }),
    ]);
  }
}

/// A food or plate photo above a question, easing in.
class _QuestionImage extends StatelessWidget {
  const _QuestionImage({required this.asset});
  final String asset;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.92, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutBack,
        builder: (_, s, child) => Transform.scale(scale: s, child: child),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Rad.xl),
          child: AspectRatio(aspectRatio: 16 / 9, child: Image.asset(asset, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())),
        ),
      );
}

/// The serving definition under a food question, set apart so it is read.
class _ServingHint extends StatelessWidget {
  const _ServingHint(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.tint(AppColors.nutrition), borderRadius: BorderRadius.circular(Rad.md)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Symbols.front_hand_rounded, size: 20, color: AppColors.nutrition, fill: 1),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: T.bodyMd.c(AppColors.onSurface).lh(1.4))),
        ]),
      );
}

/// Why the check-in matters for young adults in Sri Lanka.
class _WhyItMatters extends StatelessWidget {
  const _WhyItMatters();
  @override
  Widget build(BuildContext context) {
    final c = AppColors.heart;
    Widget fact(String big, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 72, child: Text(big, style: T.metric(22).c(c))),
            Expanded(child: Text(text, style: T.bodyMd.lh(1.4))),
          ]),
        );
    return VCard(
      color: Color.alphaBlend(c.withValues(alpha: AppColors.isDark ? 0.14 : 0.06), AppColors.surfaceContainerLowest),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Symbols.cardiology_rounded, color: c, fill: 1),
          const SizedBox(width: 8),
          Expanded(child: Text('Why this matters', style: T.headlineSm)),
        ]),
        const SizedBox(height: 8),
        Text('Heart disease, diabetes and high blood pressure often start quietly in young adulthood, years before they cause symptoms.', style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.45)),
        const SizedBox(height: 12),
        fact('1 in 3', 'Sri Lankan adults has raised blood pressure (34.8%).'),
        fact('4 in 10', 'Sri Lankan adults are overweight, with a BMI of 25 or more (39.4%).'),
        fact('15%', 'of Peradeniya students in one study already had high triglycerides, and none met the daily fruit and vegetable target.'),
        Text('Small changes now, like regular meals, more vegetables and daily movement, lower these risks for life. Your answers help the university plan that support.',
            style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.45)),
        const SizedBox(height: 8),
        Text('Sources: Sri Lanka STEPS NCD Risk Factor Survey 2021 (Ministry of Health and WHO); Ralapanawa et al., iPURSE 2023, University of Peradeniya.',
            style: T.labelSm.c(AppColors.outline)),
      ]),
    );
  }
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
    final reachOut = scores['phq2_positive'] == true;
    return VPage(
      header: TitleHeader('', close: true, onLeading: () => context.go('/home')),
      bottom: PrimaryButton('Done', onTap: () => context.go('/home')),
      children: [
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.4, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: AppColors.tint(AppColors.tertiary), shape: BoxShape.circle),
              child: Icon(Symbols.check_rounded, size: 44, color: AppColors.tertiary, weight: 600),
            ),
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
        if (reachOut)
          VCard(
            color: AppColors.tint(AppColors.mind),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(Symbols.favorite_rounded, color: AppColors.mind, fill: 1),
                const SizedBox(width: 8),
                Expanded(child: Text('You do not have to carry it alone', style: T.headlineSm)),
              ]),
              const SizedBox(height: 6),
              Text(
                  'Your answers suggest the last two weeks have felt heavy. That is common and nothing to be ashamed of. A short chat with a counsellor can really help. Only you can see this.',
                  style: T.bodyMd.lh(1.45)),
              const SizedBox(height: 12),
              SoftButton('Talk to a counsellor', icon: Symbols.support_agent_rounded, onTap: () => context.push('/professionals')),
              const SizedBox(height: 8),
              SoftButton('Ask the health centre anonymously', icon: Symbols.lock_rounded, onTap: () => context.push('/consult')),
              const SizedBox(height: 8),
              Text('In crisis? Call 1926 (National Mental Health Helpline, 24/7) or 1990 for an ambulance.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
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
          ListRow(icon: Symbols.picture_as_pdf_rounded, color: AppColors.heart, title: 'My personal health report', subtitle: 'A one-page PDF of your results', onTap: () => context.push('/profile/summary')),
          ListRow(icon: Symbols.insights_rounded, color: AppColors.water, title: 'Open my progress', onTap: () => context.go('/progress')),
        ]),
        const PrivacyNote('The administration only sees pooled results from groups of five or more students, never your individual answers.'),
      ],
    );
  }
}
