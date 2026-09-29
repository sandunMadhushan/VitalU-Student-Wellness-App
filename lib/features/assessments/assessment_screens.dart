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
      title: 'Health Assessment Window',
      body: 'Your ${w['term']} assessment is now open. Take 5 gentle minutes whenever you feel ready.',
      category: 'milestone',
      label: 'Campus Milestone',
      icon: 'event_upcoming',
      route: '/assessments/run',
      at: DateTime.parse(w['opens_at']).toLocal(),
    );
    setState(() => _reminded = true);
    if (mounted) toast(context, "Reminder set — we'll nudge you when it opens.");
  }

  @override
  Widget build(BuildContext context) {
    final completed = _history.where((h) => h['status'] == 'completed').toList();
    final inProgress = _open == null ? null : _history.where((h) => h['window_id'] == _open!['id'] && h['status'] != 'completed').firstOrNull;
    final openDone = _open != null && _history.any((h) => h['window_id'] == _open!['id'] && h['status'] == 'completed');
    final target = (_open != null && !openDone) ? _open : _next;

    return VPage(
      header: const MainHeader('Home'),
      nav: NavTab.home,
      onRefresh: _load,
      children: _loading
          ? [const Loading()]
          : [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainerHigh, fg: AppColors.onSurface, shadow: Shadows.tiny, onTap: () => goBack(context)),
                  const Spacer(),
                  TagPill('Protected & Private', icon: Symbols.verified_user, fill: 1, fg: AppColors.tertiary),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Health Assessments', style: T.headlineLg),
                const SizedBox(height: 2),
                Text('Periodic student wellness reviews & check-in milestones', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
              VCard(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceContainerLow, AppColors.surfaceContainer, AppColors.surfaceContainerHigh]),
                shadow: Shadows.tiny,
                child: Row(children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: Shadows.soft),
                    child: const AssetImg('wellness_journal', radius: 16),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Symbols.eco, size: 16, color: AppColors.tertiary),
                        const SizedBox(width: 4),
                        Flexible(child: Text('Gentle Periodic Check-ins', style: T.labelMd.c(AppColors.tertiary))),
                      ]),
                      const SizedBox(height: 4),
                      Text('Holistic reviews conducted about every six months to keep you thriving throughout your university journey.',
                          style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.35)),
                    ]),
                  ),
                ]),
              ),
              VCard(
                padding: const EdgeInsets.all(Sp.lg),
                shadow: Shadows.tiny,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    IconCircle(Symbols.calendar_today, size: 32, iconSize: 18, bg: AppColors.surfaceContainer),
                    const SizedBox(width: 8),
                    Expanded(child: Text(target == _open && _open != null ? 'Assessment Window Open' : 'Next Scheduled Assessment', style: T.labelMd.c(AppColors.onSurfaceVariant))),
                    TagPill(
                      target == null ? 'To be announced' : (target == _open ? (inProgress != null ? 'In progress' : 'Open now') : 'Not yet open'),
                      bg: target == _open && _open != null ? AppColors.tertiaryFixed : AppColors.surfaceContainerHigh,
                      fg: target == _open && _open != null ? AppColors.onTertiaryFixedVariant : AppColors.onSurfaceVariant,
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Text(target == null ? 'Coming soon' : DateFormat('MMMM yyyy').format(DateTime.parse(target['opens_at']).toLocal()), style: T.headlineXlMobile),
                  const SizedBox(height: 8),
                  Text(
                    target == null
                        ? 'Your university will announce the next assessment window. You will get a gentle reminder.'
                        : target == _open
                            ? 'Window closes ${DateFormat('d MMMM').format(DateTime.parse(target['closes_at']).toLocal())}. A gentle 5-minute self-reflection — no preparation needed.'
                            : 'Your assessment window opens automatically on ${DateFormat('d MMMM').format(DateTime.parse(target['opens_at']).toLocal())}. No preparation needed — just a gentle 5-minute self-reflection.',
                    style: T.bodySm.c(AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 16),
                  if (target != null && target == _open)
                    PrimaryButton(inProgress != null ? 'Continue Assessment' : 'Start Assessment', icon: Symbols.arrow_forward, height: 48, onTap: () async {
                      await context.push('/assessments/run');
                      _load();
                    })
                  else
                    SoftButton(
                      _reminded ? 'Reminder Set' : 'Remind Me When Open',
                      icon: _reminded ? Symbols.notifications_active : Symbols.notifications,
                      iconColor: AppColors.primary,
                      height: 48,
                      style: T.labelMd,
                      onTap: target == null || _reminded ? null : _remind,
                    ),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(children: [
                    Expanded(child: Text('Your Assessment History', style: T.headlineSm)),
                    TagPill('${completed.length} Completed', bg: AppColors.surfaceContainerHighest),
                  ]),
                ),
                const SizedBox(height: 12),
                if (completed.isEmpty)
                  const EmptyState(icon: Symbols.history_edu, title: 'No completed assessments yet', text: 'Your periodic check-ins will appear here, so you can see changes over time.')
                else
                  for (final h in completed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: VCard(
                        shadow: Shadows.tiny,
                        onTap: () => showAssessmentSummary(context, h),
                        child: Row(children: [
                          IconCircle(Symbols.check_circle, size: 40, iconSize: 20, bg: AppColors.surfaceContainer, fg: AppColors.tertiary, fill: 1),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(h['title'] ?? 'Health Assessment', style: T.labelLg, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                                Text(DateFormat('MMM d, yyyy').format(DateTime.parse(h['completed_at']).toLocal()), style: T.bodySm.c(AppColors.onSurfaceVariant)),
                                Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, shape: BoxShape.circle)),
                                Pill(color: AppColors.surfaceContainerLow, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), child: Text(h['result_label'] ?? 'Recorded', style: T.labelSm.c(AppColors.tertiary))),
                              ]),
                            ]),
                          ),
                          Icon(Symbols.chevron_right, color: AppColors.outlineVariant, size: 20),
                        ]),
                      ),
                    ),
              ]),
              VCard(
                color: AppColors.surfaceContainerHigh,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    IconCircle(Symbols.favorite, size: 32, iconSize: 18, fg: AppColors.secondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Need guidance right now?', style: T.labelLg),
                        const SizedBox(height: 4),
                        Text("You don't have to wait for an official milestone. You can consult campus health advisors or use daily tools whenever you need a boost.",
                            style: T.bodySm.c(AppColors.onSurfaceVariant)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Pressable(
                      onTap: () => context.go('/tools'),
                      child: Pill(
                        color: AppColors.surfaceContainerLowest,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shadow: Shadows.tiny,
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Explore Health Tools', style: T.labelMd.c(AppColors.primary)),
                          const SizedBox(width: 6),
                          Icon(Symbols.arrow_forward, size: 16, color: AppColors.primary),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
    );
  }
}

Future<void> showAssessmentSummary(BuildContext context, Rec a) {
  final s = Map<String, dynamic>.from(a['scores'] ?? {});
  Widget line(String k, String v, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: VCard(
          color: AppColors.surfaceContainerLow,
          radius: Rad.base,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(k, style: T.bodyMd)),
            Text(v, style: T.labelLg),
          ]),
        ),
      );
  String stressLabel(num v) => v <= 6 ? 'Low' : (v <= 10 ? 'Moderate' : 'High');
  return showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(a['title'] ?? 'Assessment Summary', style: T.headlineMd),
        const SizedBox(height: 4),
        Text('${a['result_label'] ?? ''} • ${a['completed_at'] == null ? '' : DateFormat('d MMM yyyy').format(DateTime.parse(a['completed_at']).toLocal())}',
            style: T.bodySm.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: Sp.md),
        if (s['bmi'] != null) line('BMI', '${s['bmi']}', Symbols.scale),
        if (s['whr'] != null) line('Waist-to-hip ratio', '${s['whr']}', Symbols.straighten),
        if (s['sbp'] != null) line('Systolic blood pressure', '${(s['sbp'] as num).round()} mmHg', Symbols.monitor_heart),
        line('Nutrition habits', '${s['diet_score'] ?? 0} / 10', Symbols.restaurant),
        line('Active days (last week)', '${s['activity_days'] ?? 0}', Symbols.directions_walk),
        line('Typical sleep', '${s['sleep_hours'] ?? '-'} h', Symbols.bedtime),
        line('Perceived stress (PSS-4)', '${s['stress'] ?? 0} / 16 • ${stressLabel((s['stress'] ?? 0) as num)}', Symbols.psychology),
        const SizedBox(height: Sp.sm),
        Text('This summary is for your own reflection and is not a diagnosis. If anything worries you, a campus health professional can help.',
            style: T.bodySm.c(AppColors.outline)),
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
        header: TitleHeader('Health Assessment', close: true, onLeading: () => goBack(context)),
        children: [
          if (_loading) const Loading() else EmptyState(icon: Symbols.event_busy, title: 'Assessment not available', text: _error, action: SoftButton('Back', onTap: () => goBack(context))),
        ],
      );
    }
    final section = assessmentSections[_q.section];
    final remaining = assessmentQuestions.length - _index;
    final mins = (remaining * 15 / 60).ceil();

    return VPage(
      header: TitleHeader(section.title, close: true, upper: true, filledButton: true, onLeading: _saveAndExit),
      backgroundDecoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.surface, AppColors.surfaceContainerLow, AppColors.primaryFixed.withValues(alpha: 0.2)]),
      ),
      background: Colors.transparent,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: Sp.sm),
          child: Row(children: [
            TagPill('Confidential', icon: Symbols.lock, fill: 1, iconColor: AppColors.primary),
            const Spacer(),
            TagPill('~$mins min${mins == 1 ? '' : 's'} remaining', icon: Symbols.schedule, bg: AppColors.surfaceContainerHigh),
          ]),
        ),
        VCard(
          padding: const EdgeInsets.all(Sp.sm),
          shadow: Shadows.tiny,
          child: Column(children: [
            Row(children: [
              Text('Section ${_q.section + 1} of ${assessmentSections.length}', style: T.labelSm.tracking(0.4)),
              const Spacer(),
              Text(section.title, style: T.labelSm.c(AppColors.primary)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              for (int i = 0; i < assessmentSections.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 8,
                    decoration: BoxDecoration(
                      color: i < _q.section ? AppColors.primary : (i == _q.section ? AppColors.primaryContainer : AppColors.surfaceVariant),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: i == _q.section ? const [BoxShadow(color: Color(0x807459F7), blurRadius: 8)] : null,
                    ),
                  ),
                ),
              ]
            ]),
          ]),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _questionCard(section, key: ValueKey(_index)),
        ),
        Container(
          padding: const EdgeInsets.all(Sp.sm),
          decoration: BoxDecoration(color: AppColors.surfaceContainer.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(Rad.lg)),
          child: Row(children: [
            Icon(Symbols.verified_user, size: 18, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text('Your responses are confidential. Only anonymised, grouped results are shared with the university — and only with your consent.', style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.3))),
          ]),
        ),
        Column(children: [
          PrimaryButton(_index == assessmentQuestions.length - 1 ? 'Submit Assessment' : 'Next', icon: Symbols.arrow_forward, height: 52, loading: _saving, onTap: _canNext ? _next : null),
          if (_index > 0) TextLinkButton('Back to previous question', leading: Symbols.arrow_back, onTap: _back),
        ]),
      ],
    );
  }

  Widget _questionCard(ASection section, {Key? key}) {
    return VCard(
      key: key,
      padding: const EdgeInsets.all(Sp.lg),
      clip: true,
      shadow: Shadows.card,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(top: -76, right: -76, child: Glow(color: AppColors.primaryFixed.withValues(alpha: 0.4), size: 160)),
        Positioned(bottom: -68, left: -68, child: Glow(color: AppColors.secondaryFixed.withValues(alpha: 0.3), size: 144)),
        Column(children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 128,
              height: 128,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.lg)),
              child: AssetImg(section.image, radius: Rad.base),
            ),
            Positioned(
              bottom: -8,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, shape: BoxShape.circle, boxShadow: Shadows.tiny),
                child: Icon(section.icon, size: 18, color: AppColors.tertiary, fill: 1),
              ),
            ),
          ]),
          const SizedBox(height: Sp.sm + 4),
          Pill(
            color: AppColors.primaryFixed,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_q.categoryIcon, size: 14, color: AppColors.onPrimaryFixedVariant),
              const SizedBox(width: 6),
              Flexible(child: Text(_q.category.toUpperCase(), style: T.labelSm.c(AppColors.onPrimaryFixedVariant).tracking(1), overflow: TextOverflow.ellipsis)),
            ]),
          ),
          const SizedBox(height: Sp.xs + 2),
          Text(_q.text, style: T.headlineSm, textAlign: TextAlign.center),
          const SizedBox(height: Sp.xs),
          Text(_q.help, style: T.bodySm.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
          const SizedBox(height: Sp.md),
          if (_q.type == AType.choice)
            for (final o in _q.options) Padding(padding: const EdgeInsets.only(bottom: Sp.xs), child: _option(o))
          else
            _numberInput(),
        ]),
      ]),
    );
  }

  Widget _option(AOption o) {
    final on = _answers[_q.id] == o.value;
    return Pressable(
      scale: 0.99,
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _answers[_q.id] = o.value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.all(Sp.sm),
        decoration: BoxDecoration(
          color: on ? AppColors.primaryFixed.withValues(alpha: 0.5) : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(Rad.base),
          boxShadow: on ? Shadows.tiny : null,
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.title, style: T.labelLg.c(on ? AppColors.primary : AppColors.onSurface)),
              if (o.subtitle != null) Text(o.subtitle!, style: T.bodySm.c(on ? AppColors.onSurface : AppColors.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: Sp.sm),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: on ? AppColors.primary : AppColors.surfaceContainerHighest, shape: BoxShape.circle),
            child: on ? Icon(Symbols.check, size: 16, color: AppColors.onPrimary) : null,
          ),
        ]),
      ),
    );
  }

  Widget _numberInput() => Column(children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: Sp.md),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full)),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _numCtrl,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                style: T.headlineMd,
                decoration: InputDecoration(border: InputBorder.none, hintText: 'Enter value', hintStyle: T.headlineSm.c(AppColors.outlineVariant)),
              ),
            ),
            Text(_q.unit ?? '', style: T.labelLg.c(AppColors.primary)),
          ]),
        ),
        if (_numCtrl.text.isNotEmpty && !_canNext)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Please enter a value between ${_q.min?.round()} and ${_q.max?.round()} ${_q.unit}.', style: T.bodySm.c(AppColors.error)),
          ),
        if (_q.optional)
          TextLinkButton("I don't know — skip", onTap: () {
            _numCtrl.clear();
            _next();
          }),
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
    Widget callout(IconData icon, Color bg, Color fg, String t, String s) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(Rad.base), boxShadow: Shadows.tiny),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(icon, size: 32, iconSize: 18, bg: bg, fg: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: T.labelMd),
                Text(s, style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        );

    return VPage(
      header: TitleHeader('Assessment Milestone Confirmation', close: true, onLeading: () => context.go('/home')),
      spacing: Sp.md,
      children: [
        Center(child: TagPill('Confidential', icon: Symbols.lock, fill: 1, iconColor: AppColors.primary, upper: true, bg: AppColors.surfaceContainer)),
        SizedBox(
          height: 220,
          child: Stack(alignment: Alignment.center, children: [
            Glow(color: AppColors.primaryFixed.withValues(alpha: 0.7), size: 224),
            Container(
              width: 192,
              height: 192,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(40),
                boxShadow: const [
                  BoxShadow(color: Color(0x1F984062), blurRadius: 36, offset: Offset(0, 16), spreadRadius: -8),
                  BoxShadow(color: Color(0x145B3CDD), blurRadius: 20, offset: Offset(0, 6), spreadRadius: -4),
                ],
              ),
              child: const AssetImg('assessment_badge', radius: 34),
            ),
            Positioned(
              top: 4,
              right: 70,
              child: IconCircle(Symbols.auto_awesome, size: 28, iconSize: 16, bg: AppColors.surfaceContainerLow, fg: AppColors.primaryContainer, fill: 1),
            ),
            Positioned(bottom: 12, left: 70, child: IconCircle(Symbols.favorite, size: 24, iconSize: 14, bg: AppColors.secondaryFixed, fg: AppColors.secondary, fill: 1)),
          ]),
        ),
        Column(children: [
          Pill(color: AppColors.tertiaryFixed, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: Text('Milestone Achieved', style: T.labelSm.c(AppColors.onTertiaryFixedVariant))),
          const SizedBox(height: 6),
          Text('Assessment Complete!', style: T.headlineLg),
          const SizedBox(height: 6),
          Text('Thank you — your honest reflections cultivate personalized support for your semester ahead.', textAlign: TextAlign.center, style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.6)),
          const SizedBox(height: 4),
          Text('Taking time for your physical well-being, energy, and routine is a vital pause for a thriving campus life.', textAlign: TextAlign.center, style: T.bodySm.c(AppColors.outline)),
        ]),
        VCard(
          color: AppColors.surfaceContainerLow,
          shadow: Shadows.tiny,
          child: Column(children: [
            Row(children: [
              IconCircle(Symbols.event_available, size: 36, iconSize: 19, bg: AppColors.surfaceContainerHighest),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('REVIEW TIMESTAMP', style: T.labelSm.c(AppColors.outline).tracking(1)),
                  Text(DateFormat('MMMM d, yyyy').format(done), style: T.headlineSm),
                ]),
              ),
              TagPill('Recorded', icon: Symbols.check_circle, fill: 1, bg: AppColors.tertiaryFixed.withValues(alpha: 0.6), fg: AppColors.tertiary),
            ]),
            const SizedBox(height: 14),
            callout(Symbols.insights, AppColors.secondaryFixed, AppColors.secondary, 'Fresh Insights Ready', 'Your updated measurements and wellbeing results are synced to your Progress hub.'),
            const SizedBox(height: 8),
            callout(Symbols.history_edu, AppColors.primaryFixed, AppColors.primary, 'Accessible Anytime', 'Revisit your results anytime under Health Assessments.'),
          ]),
        ),
        PrimaryButton('Back to Dashboard', icon: Symbols.arrow_forward, height: 52, onTap: () => context.go('/home')),
        SoftButton('View Assessment Summary', icon: Symbols.menu_book, color: AppColors.surfaceContainer, fg: AppColors.onSurfaceVariant, height: 48, style: T.labelMd, onTap: assessment == null ? null : () => showAssessmentSummary(context, assessment!)),
        Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Symbols.verified_user, size: 15, color: AppColors.outline),
            const SizedBox(width: 4),
            Text('CAMPUS PRIVACY GUARANTEE', style: T.labelSm.c(AppColors.outline).tracking(1)),
          ]),
          const SizedBox(height: 4),
          Text('Individual responses are never shared with lecturers or your faculty. University reports only use anonymised, grouped results from students who consented.',
              textAlign: TextAlign.center, style: T.bodySm.c(AppColors.outline).lh(1.35)),
        ]),
      ],
    );
  }
}
