import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

// ---------------------------------------------------------------------------
// Shared pieces
// ---------------------------------------------------------------------------

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (int i = 1; i <= 3; i++) ...[
          if (i > 1) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              decoration: BoxDecoration(color: i <= step ? AppColors.primary : AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ],
      ]);
}

class _Intro extends StatelessWidget {
  const _Intro(this.title, this.text);
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: T.headlineLg),
        const SizedBox(height: 6),
        Text(text, style: T.bodyLg.c(AppColors.onSurfaceVariant)),
      ]);
}

class _Actions extends StatelessWidget {
  const _Actions({required this.label, required this.onContinue, required this.onSkip, this.busy = false, this.skipLabel = 'Skip for now'});
  final String label;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final bool busy;
  final String skipLabel;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        PrimaryButton(label, loading: busy, onTap: onContinue),
        TextLinkButton(skipLabel, color: AppColors.onSurfaceVariant, onTap: onSkip),
      ]);
}

Future<void> _saveStep(Map<String, dynamic> values, int step) async {
  final current = AppState.instance.profile?.registrationStep ?? 0;
  await AppState.instance.updateProfile({...values, 'registration_step': step > current ? step : current});
}

/// Bottom-sheet list picker with a check on the current value.
Future<String?> pickOption(BuildContext context, String title, List<String> options, String? current) {
  return showVSheet<String>(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: T.headlineMd),
        const SizedBox(height: Sp.md),
        ListGroup(dividerIndent: 16, children: [
          for (final o in options)
            ListRow(
              title: o,
              trailing: o == current ? Icon(Symbols.check_rounded, color: AppColors.primary) : null,
              chevron: false,
              onTap: () => Navigator.pop(ctx, o),
            ),
        ]),
      ]));
}

// ---------------------------------------------------------------------------
// Step 1 — basic info
// ---------------------------------------------------------------------------

class RegistrationStep1 extends StatefulWidget {
  const RegistrationStep1({super.key});
  @override
  State<RegistrationStep1> createState() => _RegistrationStep1State();
}

class _RegistrationStep1State extends State<RegistrationStep1> {
  DateTime? _dob;
  String? _sex;
  String? _faculty;
  String? _year;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = AppState.instance.profile;
    _dob = p?.dob;
    _sex = p?.sex;
    _faculty = p?.faculty;
    _year = p?.academicYear;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 21, 1, 1),
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year - 15, 12, 31),
    );
    if (d != null) setState(() => _dob = d);
  }

  Future<void> _continue({bool skip = false}) async {
    setState(() => _busy = true);
    try {
      await _saveStep(
        skip
            ? {}
            : {
                if (_dob != null) 'date_of_birth': DateFormat('yyyy-MM-dd').format(_dob!),
                if (_sex != null) 'sex': _sex,
                if (_faculty != null) 'faculty': _faculty,
                if (_year != null) 'academic_year': _year,
              },
        1,
      );
      if (mounted) context.push('/register/2');
    } catch (e) {
      if (mounted) toast(context, 'Could not save. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: RegistrationHeader(title: 'Step 1 of 3', onBack: () => context.canPop() ? context.pop() : null),
      spacing: Sp.lg,
      bottom: _Actions(label: 'Continue', busy: _busy, onContinue: () => _continue(), onSkip: () => _continue(skip: true)),
      children: [
        const _StepProgress(step: 1),
        const _Intro('Tell us about you', 'This helps VitalU set your daily targets and assessment schedule.'),
        ListGroup(dividerIndent: 60, children: [
          ListRow(
            icon: Symbols.cake_rounded,
            color: AppColors.cycle,
            title: 'Date of birth',
            value: _dob == null ? 'Select' : DateFormat('d MMM yyyy').format(_dob!),
            onTap: _pickDob,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 12),
            child: Row(children: [
              IconCircle(Symbols.wc_rounded, size: 32, iconSize: 18, fg: AppColors.water, radius: 8, fill: 1),
              const SizedBox(width: 12),
              Expanded(child: Text('Sex', style: T.bodyLg)),
              Segmented(
                options: const ['Female', 'Male'],
                value: _sex == 'male' ? 'Male' : (_sex == 'female' ? 'Female' : ''),
                onChanged: (v) => setState(() => _sex = v.toLowerCase()),
              ),
            ]),
          ),
          ListRow(
            icon: Symbols.school_rounded,
            color: AppColors.primary,
            title: 'Faculty',
            subtitle: _faculty,
            value: _faculty == null ? 'Select' : null,
            onTap: () async {
              final v = await pickOption(context, 'Faculty', faculties, _faculty);
              if (v != null) setState(() => _faculty = v);
            },
          ),
          ListRow(
            icon: Symbols.calendar_month_rounded,
            color: AppColors.warning,
            title: 'Academic year',
            value: _year ?? 'Select',
            onTap: () async {
              final v = await pickOption(context, 'Academic year', academicYears, _year);
              if (v != null) setState(() => _year = v);
            },
          ),
        ]),
        Text('Sex is used for body-metric ranges. Health assessments are scheduled by faculty, so check-ins follow your academic calendar.',
            style: T.bodySm.c(AppColors.onSurfaceVariant)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — health background
// ---------------------------------------------------------------------------

class RegistrationStep2 extends StatefulWidget {
  const RegistrationStep2({super.key});
  @override
  State<RegistrationStep2> createState() => _RegistrationStep2State();
}

class _RegistrationStep2State extends State<RegistrationStep2> {
  late final Set<String> _selected = {...?AppState.instance.profile?.conditions};
  bool _none = false;
  bool _busy = false;

  static const _keys = [
    'family_heart',
    'family_diabetes',
    'family_cholesterol',
    'family_obesity',
    'asthma_allergies',
    'allergies_intolerances',
    'high_bp',
    'migraine',
    'anxiety_sleep',
    'gastritis',
    'constipation',
    'skin_disease',
    'kidney_disease',
    'liver_disease',
    'hemorrhoids',
    'anaemia',
    'std',
    'pcos',
  ];

  Future<void> _continue({bool skip = false}) async {
    setState(() => _busy = true);
    try {
      await _saveStep(skip ? {} : {'health_conditions': _none ? <String>[] : _selected.toList()}, 2);
      if (mounted) context.push('/register/3');
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: RegistrationHeader(title: 'Step 2 of 3', onBack: () => goBack(context, '/register/1')),
      spacing: Sp.lg,
      bottom: _Actions(label: 'Continue', busy: _busy, onContinue: () => _continue(), onSkip: () => _continue(skip: true), skipLabel: 'Skip this step'),
      children: [
        const _StepProgress(step: 2),
        const _Intro('Any health history?', 'Optional. Select anything that applies to you or your family. You can change this later in your profile.'),
        VCard(
          color: AppColors.surfaceContainer,
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.lock_rounded, size: 18, color: AppColors.onSurfaceVariant, fill: 1),
            const SizedBox(width: 10),
            Expanded(child: Text('VitalU uses this solely to tailor gentle preventative tips — never shared with lecturers or your faculty.', style: T.bodySm.c(AppColors.onSurfaceVariant))),
          ]),
        ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in _keys) _chip(conditionByKey(k)!),
          VChip(
            'None of these',
            icon: Symbols.block_rounded,
            selected: _none,
            selectedColor: AppColors.onSurfaceVariant,
            onTap: () => setState(() {
              _none = !_none;
              if (_none) _selected.clear();
            }),
          ),
        ]),
      ],
    );
  }

  Widget _chip(Condition c) {
    final on = _selected.contains(c.key);
    return VChip(
      c.label,
      selected: on,
      onTap: () => setState(() {
        on ? _selected.remove(c.key) : _selected.add(c.key);
        if (!on) _none = false;
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — body measurements
// ---------------------------------------------------------------------------

/// Numeric entry with a unit switch.
class MeasureField extends StatelessWidget {
  const MeasureField({super.key, required this.controller, required this.units, required this.unit, required this.onUnit, this.hint, this.accent});
  final TextEditingController controller;
  final List<String> units;
  final String unit;
  final ValueChanged<String> onUnit;
  final String? hint;
  final Color? accent;
  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(
          width: 76,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            style: T.bodyLg.tnum,
            decoration: InputDecoration(isDense: true, hintText: hint ?? '—', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          ),
        ),
        const SizedBox(width: 8),
        Segmented(options: units, value: unit, onChanged: onUnit),
      ]);
}

/// Unit-aware numeric measurement controller (stores metric).
class Measure {
  Measure(this.metricUnit, this.altUnit, this.factor, double? initial) : unit = metricUnit {
    if (initial != null) controller.text = _fmt(initial);
  }
  final String metricUnit;
  final String altUnit;
  final double factor; // alt = metric * factor
  String unit;
  final controller = TextEditingController();

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  double? get metric {
    final v = double.tryParse(controller.text);
    if (v == null) return null;
    return unit == metricUnit ? v : v / factor;
  }

  void switchTo(String u) {
    if (u == unit) return;
    final m = metric;
    unit = u;
    if (m != null) controller.text = _fmt(u == metricUnit ? m : m * factor);
  }
}

class RegistrationStep3 extends StatefulWidget {
  const RegistrationStep3({super.key});
  @override
  State<RegistrationStep3> createState() => _RegistrationStep3State();
}

class _RegistrationStep3State extends State<RegistrationStep3> {
  final p = AppState.instance.profile;
  late final _h = Measure('cm', 'in', 0.393701, p?.heightCm);
  late final _w = Measure('kg', 'lb', 2.20462, p?.weightKg);
  late final _waist = Measure('cm', 'in', 0.393701, p?.waistCm);
  late final _hip = Measure('cm', 'in', 0.393701, p?.hipCm);
  bool _busy = false;

  Future<void> _finish({bool skip = false}) async {
    String? err;
    if (!skip) {
      final h = _h.metric, w = _w.metric, wa = _waist.metric, hi = _hip.metric;
      if (h != null && (h < 100 || h > 230)) err = 'Height looks unusual. Please check it.';
      if (w != null && (w < 25 || w > 250)) err = 'Weight looks unusual. Please check it.';
      if (wa != null && (wa < 40 || wa > 200)) err = 'Waist looks unusual. Please check it.';
      if (hi != null && (hi < 50 || hi > 200)) err = 'Hip looks unusual. Please check it.';
    }
    if (err != null) return toast(context, err, error: true);
    setState(() => _busy = true);
    try {
      final values = <String, dynamic>{'onboarding_completed': true};
      if (!skip) {
        if (_h.metric != null) values['height_cm'] = _h.metric;
        if (_w.metric != null) {
          values['weight_kg'] = _w.metric;
          values['water_goal_ml'] = Calc.waterTargetFor(_w.metric);
        }
        if (_waist.metric != null) values['waist_cm'] = _waist.metric;
        if (_hip.metric != null) values['hip_cm'] = _hip.metric;
        if (values.length > 1) values['measured_at'] = DateTime.now().toUtc().toIso8601String();
      }
      await _saveStep(values, 3);
      if (mounted) context.go('/register/done');
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String title, String? sub, IconData icon, Measure m) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 12),
        child: Row(children: [
          IconCircle(icon, size: 32, iconSize: 18, fg: AppColors.body, radius: 8, fill: 1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.bodyLg),
              if (sub != null) Text(sub, style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          MeasureField(controller: m.controller, units: [m.metricUnit, m.altUnit], unit: m.unit, onUnit: (u) => setState(() => m.switchTo(u))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: RegistrationHeader(title: 'Step 3 of 3', onBack: () => goBack(context, '/register/2')),
      spacing: Sp.lg,
      bottom: _Actions(label: 'Finish setup', busy: _busy, onContinue: () => _finish(), onSkip: () => _finish(skip: true), skipLabel: "I'll add these later"),
      children: [
        const _StepProgress(step: 3),
        const _Intro('A few numbers to personalize your tools', "Don't know these? No problem, skip and add later."),
        ListGroup(dividerIndent: 60, children: [
          _row('Height', null, Symbols.height_rounded, _h),
          _row('Weight', null, Symbols.monitor_weight_rounded, _w),
          _row('Waist', 'Optional', Symbols.straighten_rounded, _waist),
          _row('Hip', 'Optional', Symbols.accessibility_new_rounded, _hip),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Registration complete
// ---------------------------------------------------------------------------

class RegistrationComplete extends StatelessWidget {
  const RegistrationComplete({super.key});

  @override
  Widget build(BuildContext context) {
    final name = AppState.instance.profile?.firstName;
    return VPage(
      spacing: Sp.lg,
      topPadding: Sp.xl,
      bottom: PrimaryButton('Go to my dashboard', onTap: () => context.go('/home')),
      children: [
        Column(children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: AppColors.tint(AppColors.tertiary), shape: BoxShape.circle),
            child: Icon(Symbols.check_rounded, size: 40, color: AppColors.tertiary, weight: 600),
          ),
          const SizedBox(height: Sp.md),
          Text(name == null ? "You're all set" : "You're all set, $name", textAlign: TextAlign.center, style: T.headlineXlMobile),
          const SizedBox(height: Sp.sm),
          Text('Your personalized health space is ready.', textAlign: TextAlign.center, style: T.bodyLg.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text('Gentle reminders and tools crafted for your university rhythm, at your own pace.', textAlign: TextAlign.center, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ]),
        ListGroup(header: 'Your space includes', children: [
          ListRow(icon: Symbols.monitor_heart_rounded, color: AppColors.heart, title: 'Health Tools', subtitle: 'Vitals and daily habits', chevron: false),
          ListRow(icon: Symbols.restaurant_rounded, color: AppColors.nutrition, title: 'Nutrition Hub', subtitle: 'Meals, diversity and budget', chevron: false),
          ListRow(icon: Symbols.menu_book_rounded, color: AppColors.water, title: 'Health Education', subtitle: 'Short reads for campus life', chevron: false),
          ListRow(icon: Symbols.support_agent_rounded, color: AppColors.primary, title: 'Health Support', subtitle: 'Professionals and emergency lines', chevron: false),
          ListRow(icon: Symbols.insights_rounded, color: AppColors.mind, title: 'My Progress', subtitle: 'Trends and milestones', chevron: false),
        ]),
      ],
    );
  }
}
