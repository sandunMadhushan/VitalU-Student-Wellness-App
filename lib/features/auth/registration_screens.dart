import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/catalog.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
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
  const _Actions({required this.label, required this.onContinue, this.onSkip, this.busy = false, this.skipLabel = 'Skip for now', this.note});
  final String label;
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;
  final bool busy;
  final String skipLabel;

  /// Shown under the button instead of a skip link, e.g. why it is disabled.
  final String? note;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        PrimaryButton(label, loading: busy, onTap: onContinue),
        if (onSkip != null)
          TextLinkButton(skipLabel, color: AppColors.onSurfaceVariant, onTap: onSkip)
        else if (note != null)
          Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(note!, style: T.bodySm.c(AppColors.onSurfaceVariant))),
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
// Step 1: basic info
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
  final _regNo = TextEditingController();
  final _nameInit = TextEditingController();
  final _username = TextEditingController();
  String? _usernameError;
  bool _checkingUsername = false;
  bool _busy = false;

  static final _usernameFormat = RegExp(r'^[a-z][a-z0-9_.]{2,19}$');

  @override
  void initState() {
    super.initState();
    final p = AppState.instance.profile;
    _dob = p?.dob;
    _sex = p?.sex;
    _faculty = p?.faculty;
    _year = p?.academicYear;
    _regNo.text = p?.registrationNumber ?? '';
    _nameInit.text = p?.nameWithInitials ?? '';
    _username.text = p?.username ?? '';
    for (final c in [_regNo, _nameInit, _username]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _regNo.dispose();
    _nameInit.dispose();
    _username.dispose();
    super.dispose();
  }

  bool get _usernameValid => _usernameFormat.hasMatch(_username.text.trim().toLowerCase());

  bool get _complete =>
      _dob != null &&
      _sex != null &&
      _faculty != null &&
      _year != null &&
      _regNo.text.trim().length >= 3 &&
      _nameInit.text.trim().length >= 3 &&
      _usernameValid;

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

  Future<void> _continue() async {
    if (!_complete) return;
    final username = _username.text.trim().toLowerCase();
    setState(() {
      _busy = true;
      _usernameError = null;
    });
    try {
      if (username != (AppState.instance.profile?.username ?? '').toLowerCase()) {
        setState(() => _checkingUsername = true);
        final available = await Repo.usernameAvailable(username);
        setState(() => _checkingUsername = false);
        if (!available) {
          setState(() => _usernameError = 'That username is taken. Try another.');
          return;
        }
      }
      await _saveStep({
        'date_of_birth': DateFormat('yyyy-MM-dd').format(_dob!),
        'sex': _sex,
        'faculty': _faculty,
        'academic_year': _year,
        'registration_number': _regNo.text.trim().toUpperCase(),
        'name_with_initials': _nameInit.text.trim(),
        'username': username,
      }, 1);
      if (!mounted) return;
      // Students who finished registration earlier only needed to complete
      // the new required fields.
      if (AppState.instance.profile?.onboardingCompleted ?? false) {
        context.go('/home');
      } else {
        context.push('/register/2');
      }
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        setState(() => _usernameError = 'That username is taken. Try another.');
      } else if (mounted) {
        toast(context, 'Could not save. Please try again.', error: true);
      }
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
      bottom: _Actions(label: 'Continue', busy: _busy, onContinue: _complete ? _continue : null, note: _complete ? null : 'Fill in every field to continue'),
      children: [
        const _StepProgress(step: 1),
        const _Intro('Tell us about you', 'This helps VitalU set your daily targets and assessment schedule.'),
        ListGroup(dividerIndent: 60, children: [
          _textRow(Symbols.badge_rounded, AppColors.primary, _nameInit, 'Name with initials', hint: 'H.M.S. Perera', capitalize: TextCapitalization.words),
          _textRow(Symbols.account_circle_rounded, AppColors.mind, _username, 'Username',
              hint: 'hmsperera', lowercase: true, error: _usernameError, suffix: _checkingUsername ? const _MiniSpinner() : null),
          _textRow(Symbols.badge_rounded, AppColors.heart, _regNo, 'Registration number', hint: 'AG/21/045', capitalize: TextCapitalization.characters),
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
              _icon(Symbols.wc_rounded, AppColors.water),
              const SizedBox(width: 14),
              Expanded(child: Text('Sex', style: T.bodyLg.w(FontWeight.w600))),
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
              final v = await pickOption(context, 'Select your faculty', faculties, _faculty);
              if (v != null) setState(() => _faculty = v);
            },
          ),
          ListRow(
            icon: Symbols.calendar_month_rounded,
            color: AppColors.warning,
            title: 'Batch',
            value: _year ?? 'Select your batch',
            onTap: () async {
              final v = await pickOption(context, 'Select your batch', academicYears, _year);
              if (v != null) setState(() => _year = v);
            },
          ),
        ]),
      ],
    );
  }

  Widget _icon(IconData icon, Color c) => IconCircle(icon, size: 30, iconSize: 18, bg: c, fg: AppColors.isDark ? AppColors.surface : Colors.white, radius: 8, fill: 1);

  Widget _textRow(
    IconData icon,
    Color c,
    TextEditingController ctrl,
    String hintLabel, {
    required String hint,
    TextCapitalization capitalize = TextCapitalization.none,
    bool lowercase = false,
    String? error,
    Widget? suffix,
  }) {
    final field = Padding(
      padding: const EdgeInsets.fromLTRB(Sp.md, 4, Sp.md, 4),
      child: Row(children: [
        _icon(icon, c),
        const SizedBox(width: 14),
        Expanded(
          child: TextField(
            controller: ctrl,
            textCapitalization: capitalize,
            textInputAction: TextInputAction.done,
            inputFormatters: lowercase ? [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_.]')), LowerCaseTextFormatter()] : null,
            style: T.bodyLg.w(FontWeight.w600),
            decoration: InputDecoration(
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              hintText: hint,
              hintStyle: T.bodyLg.w(FontWeight.w600).c(AppColors.outline),
              prefixText: lowercase ? '@' : null,
              prefixStyle: T.bodyLg.w(FontWeight.w600).c(AppColors.onSurfaceVariant),
            ),
          ),
        ),
        ?suffix,
      ]),
    );
    if (error == null) return field;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      field,
      Padding(padding: const EdgeInsets.fromLTRB(Sp.md + 44, 0, Sp.md, 8), child: Text(error, style: T.bodySm.c(AppColors.error))),
    ]);
  }
}

class _MiniSpinner extends StatelessWidget {
  const _MiniSpinner();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 8),
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      );
}

// ---------------------------------------------------------------------------
// Step 2: health background
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
      spacing: Sp.md,
      bottom: _Actions(label: 'Continue', busy: _busy, onContinue: () => _continue(), onSkip: () => _continue(skip: true), skipLabel: 'Skip this step'),
      children: [
        const _StepProgress(step: 2),
        const _Intro('Any health history?', 'Select anything that applies to you or your family. You can change this later in your profile.'),
        VCard(
          color: AppColors.surfaceContainer,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.lock_rounded, size: 16, color: AppColors.onSurfaceVariant, fill: 1),
            const SizedBox(width: 8),
            Expanded(child: Text('VitalU uses this solely to tailor gentle preventative tips.', style: T.bodySm.c(AppColors.onSurfaceVariant))),
          ]),
        ),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in _keys) _chip(conditionByKey(k)!),
          VChip(
            'None of these',
            height: 30,
            dense: true,
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
      height: 30,
      dense: true,
      selected: on,
      onTap: () => setState(() {
        on ? _selected.remove(c.key) : _selected.add(c.key);
        if (!on) _none = false;
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: body measurements
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
            decoration: InputDecoration(isDense: true, hintText: hint ?? '-', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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
    if (!(AppState.instance.profile?.basicsComplete ?? false)) {
      toast(context, 'Complete step 1 before creating your profile.', error: true);
      context.go('/register/1');
      return;
    }
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
          _row('Waist', null, Symbols.straighten_rounded, _waist),
          _row('Hip', null, Symbols.accessibility_new_rounded, _hip),
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
          ListRow(icon: Symbols.monitor_heart_rounded, color: AppColors.heart, title: 'Health tools', subtitle: 'Vitals and daily habits', chevron: false),
          ListRow(icon: Symbols.restaurant_rounded, color: AppColors.nutrition, title: 'Nutrition hub', subtitle: 'Smart eating', chevron: false),
          ListRow(icon: Symbols.menu_book_rounded, color: AppColors.water, title: 'Health education', subtitle: 'Short reads for campus life', chevron: false),
          ListRow(icon: Symbols.support_agent_rounded, color: AppColors.primary, title: 'Health support', subtitle: 'Professionals and emergency lines', chevron: false),
          ListRow(icon: Symbols.insights_rounded, color: AppColors.mind, title: 'My progress', subtitle: 'Trends and milestones', chevron: false),
        ]),
      ],
    );
  }
}
