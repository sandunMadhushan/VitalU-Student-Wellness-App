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
import '../../ui/ruler.dart';
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
  const _Actions({required this.label, required this.onContinue, this.busy = false, this.note});
  final String label;
  final VoidCallback? onContinue;
  final bool busy;

  /// Shown under the button, e.g. why it is disabled.
  final String? note;
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
        PrimaryButton(label, loading: busy, onTap: onContinue),
        if (note != null) Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(note!, style: T.bodySm.c(AppColors.onSurfaceVariant))),
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
    _faculty = facultyForEmail(p?.email) ?? p?.faculty;
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

  int? get _age {
    final d = _dob;
    if (d == null) return null;
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a;
  }

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
          ListRow(
            icon: Symbols.hourglass_rounded,
            color: AppColors.mind,
            title: 'Age',
            value: _age == null ? 'Set from date of birth' : '$_age years',
            chevron: false,
            onTap: _dob == null ? _pickDob : null,
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
            // A faculty email decides the faculty, so it is not editable then.
            chevron: facultyForEmail(AppState.instance.profile?.email) == null,
            onTap: facultyForEmail(AppState.instance.profile?.email) != null
                ? null
                : () async {
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
  late final Set<String> _personal = {...?AppState.instance.profile?.conditions.where((k) => !isFamilyCondition(k))};
  late final Set<String> _family = {...?AppState.instance.profile?.conditions.where(isFamilyCondition)};

  // A previously saved step counts as answered, so returning students are
  // not asked to tick "none" again.
  late bool _noPersonal = (AppState.instance.profile?.registrationStep ?? 0) >= 2 && _personal.isEmpty;
  late bool _noFamily = (AppState.instance.profile?.registrationStep ?? 0) >= 2 && _family.isEmpty;
  bool _busy = false;

  bool get _complete => (_personal.isNotEmpty || _noPersonal) && (_family.isNotEmpty || _noFamily);

  Future<void> _continue() async {
    if (!_complete) return;
    setState(() => _busy = true);
    try {
      await _saveStep({'health_conditions': [..._personal, ..._family]}, 2);
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
      bottom: _Actions(
        label: 'Continue',
        busy: _busy,
        onContinue: _complete ? _continue : null,
        note: _complete ? null : 'Answer both sections, or pick "None" in each',
      ),
      children: [
        const _StepProgress(step: 2),
        const _Intro('Your health background', 'This helps VitalU tailor gentle, preventative tips. You can change it later in your profile.'),
        _section(
          icon: Symbols.person_rounded,
          color: AppColors.primary,
          title: 'About you',
          subtitle: 'Anything you have been diagnosed with',
          chips: [
            for (final k in personalConditionKeys.where((k) => k != 'pcos' || AppState.instance.profile?.sex != 'male'))
              _chip(conditionByKey(k)!.label, _personal.contains(k), () {
                _personal.contains(k) ? _personal.remove(k) : _personal.add(k);
                if (_personal.isNotEmpty) _noPersonal = false;
              }),
            _chip('None of these', _noPersonal, () {
              _noPersonal = !_noPersonal;
              if (_noPersonal) _personal.clear();
            }, none: true),
          ],
        ),
        _section(
          icon: Symbols.family_restroom_rounded,
          color: AppColors.heart,
          title: 'Family history',
          subtitle: 'Parents, brothers, sisters or grandparents',
          chips: [
            for (final k in familyConditionKeys)
              _chip(familyConditionLabel(k), _family.contains(k), () {
                _family.contains(k) ? _family.remove(k) : _family.add(k);
                if (_family.isNotEmpty) _noFamily = false;
              }),
            _chip('None, or not sure', _noFamily, () {
              _noFamily = !_noFamily;
              if (_noFamily) _family.clear();
            }, none: true),
          ],
        ),
      ],
    );
  }

  Widget _section({required IconData icon, required Color color, required String title, required String subtitle, required List<Widget> chips}) => VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconCircle(icon, size: 34, iconSize: 18, fg: color, radius: 10, fill: 1),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.headlineSm),
                Text(subtitle, style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ]),
      );

  Widget _chip(String label, bool on, VoidCallback toggle, {bool none = false}) => VChip(
        label,
        height: 32,
        dense: true,
        selected: on,
        selectedColor: none ? AppColors.onSurfaceVariant : AppColors.primary,
        onTap: () => setState(toggle),
      );
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
  late double _height = (p?.heightCm ?? 160).clamp(120, 220).toDouble();
  late double _weight = (p?.weightKg ?? 60).clamp(30, 200).toDouble();
  late double _waist = (p?.waistCm ?? 76).clamp(45, 160).toDouble();
  late double _hip = (p?.hipCm ?? 96).clamp(60, 170).toDouble();
  late String? _shape = p?.bodyShape;
  String _hUnit = 'cm';
  String _wUnit = 'kg';
  String _gUnit = 'cm';
  int _page = 0;
  bool _busy = false;

  static const _titles = ['Height', 'Weight', 'Waist and hip', 'Body shape'];

  void _back() {
    if (_page > 0) {
      setState(() => _page--);
    } else {
      goBack(context, '/register/2');
    }
  }

  void _next() {
    if (_page < _titles.length - 1) {
      setState(() => _page++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (!(AppState.instance.profile?.basicsComplete ?? false)) {
      toast(context, 'Complete step 1 before creating your profile.', error: true);
      context.go('/register/1');
      return;
    }
    if (_shape == null) return;
    setState(() => _busy = true);
    final values = <String, dynamic>{
      'onboarding_completed': true,
      'height_cm': double.parse(_height.toStringAsFixed(1)),
      'weight_kg': double.parse(_weight.toStringAsFixed(1)),
      'waist_cm': double.parse(_waist.toStringAsFixed(1)),
      'hip_cm': double.parse(_hip.toStringAsFixed(1)),
      'water_goal_ml': Calc.waterTargetFor(_weight),
      'measured_at': DateTime.now().toUtc().toIso8601String(),
      'body_shape': _shape,
    };
    try {
      try {
        await _saveStep(values, 3);
      } on PostgrestException catch (e) {
        // The body shape column arrives with a database migration; never
        // block registration while it is pending.
        if (e.code != 'PGRST204' && e.code != '42703') rethrow;
        await _saveStep({...values}..remove('body_shape'), 3);
      }
      if (mounted) context.go('/register/done');
    } catch (_) {
      if (mounted) toast(context, 'Could not save. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _titles.length - 1;
    return VPage(
      header: RegistrationHeader(title: 'Step 3 of 3', onBack: _back),
      spacing: Sp.lg,
      bottom: _Actions(
        label: last ? 'Finish setup' : 'Next',
        busy: _busy,
        onContinue: last && _shape == null ? null : _next,
        note: last && _shape == null ? 'Pick the shape closest to yours' : null,
      ),
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _StepProgress(step: 3),
          const SizedBox(height: 10),
          Row(children: [
            for (int i = 0; i < _titles.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == _page ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(color: i <= _page ? AppColors.primary : AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(3)),
              ),
            ],
            const SizedBox(width: 10),
            Text('${_page + 1} of ${_titles.length} · ${_titles[_page]}', style: T.labelMd.c(AppColors.onSurfaceVariant)),
          ]),
        ]),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0.05, 0), end: Offset.zero).animate(a), child: child),
          ),
          child: KeyedSubtree(key: ValueKey(_page), child: _pageBody()),
        ),
      ],
    );
  }

  Widget _pageBody() => switch (_page) {
        0 => _heightPage(),
        1 => _weightPage(),
        2 => _girthPage(),
        _ => _shapePage(),
      };

  Widget _unitToggle(List<String> units, String value, ValueChanged<String> onChanged) =>
      Center(child: Segmented(options: units, value: value, onChanged: (u) => setState(() => onChanged(u))));

  Widget _bigValue(String value, String unit) => Text.rich(
        TextSpan(text: value, children: [TextSpan(text: ' $unit', style: T.headlineSm.c(AppColors.onSurfaceVariant))]),
        style: T.metric(40),
      );

  // Height: a vertical ruler, as on a wall.
  Widget _heightPage() {
    final cm = _hUnit == 'cm';
    final inches = _height / 2.54;
    final display = cm ? _bigValue(_height.round().toString(), 'cm') : _bigValue("${inches ~/ 12}' ${(inches % 12).round()}\"", '');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Intro('Please share your height', 'This helps us tailor your plan for the best results.'),
      const SizedBox(height: Sp.md),
      _unitToggle(const ['cm', 'ft'], _hUnit, (u) => _hUnit = u),
      const SizedBox(height: Sp.md),
      SizedBox(
        height: 380,
        child: Row(children: [
          RulerPicker(
            axis: Axis.vertical,
            crossExtent: 110,
            value: cm ? _height : inches.roundToDouble(),
            min: cm ? 120 : 48,
            max: cm ? 220 : 86,
            step: 1,
            majorEvery: cm ? 10 : 12,
            midEvery: cm ? 5 : 6,
            label: cm ? null : (v) => "${v ~/ 12}'",
            onChanged: (v) => setState(() => _height = cm ? v : v * 2.54),
          ),
          const SizedBox(width: Sp.md),
          Expanded(child: Center(child: display)),
        ]),
      ),
    ]);
  }

  // Weight: a horizontal ruler with a live BMI preview.
  Widget _weightPage() {
    final kg = _wUnit == 'kg';
    final bmi = Calc.bmi(_height, _weight)!;
    final cat = Calc.bmiCategory(bmi);
    final c = switch (cat) {
      'Normal Weight' => AppColors.tertiary,
      'Overweight' => AppColors.warning,
      'Obesity' => AppColors.error,
      _ => AppColors.water,
    };
    final shown = kg ? _weight : _weight * 2.20462;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Intro('Please share your weight', 'All bodies are unique. Tracking your weight helps us support your goals better.'),
      const SizedBox(height: Sp.md),
      _unitToggle(const ['kg', 'lbs'], _wUnit, (u) => _wUnit = u),
      const SizedBox(height: Sp.xl),
      Center(child: _bigValue(kg ? shown.toStringAsFixed(1) : shown.round().toString(), kg ? 'kg' : 'lbs')),
      const SizedBox(height: Sp.md),
      RulerPicker(
        value: kg ? double.parse(_weight.toStringAsFixed(1)) : shown.roundToDouble(),
        min: kg ? 30 : 66,
        max: kg ? 200 : 440,
        step: kg ? 0.1 : 1,
        majorEvery: 10,
        midEvery: 5,
        label: kg ? (v) => v.round().toString() : null,
        onChanged: (v) => setState(() => _weight = kg ? v : v / 2.20462),
      ),
      const SizedBox(height: Sp.lg),
      VCard(
        color: AppColors.surfaceContainerLow,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(TextSpan(text: 'Your BMI: ', children: [TextSpan(text: bmi.toStringAsFixed(1), style: T.headlineSm.c(c))]), style: T.labelLg),
          const SizedBox(height: 4),
          Text(
            cat == 'Normal Weight' ? 'You are in the healthy range. Keep up the good habits!' : 'Step by step! VitalU will help you move towards a healthier, more active you.',
            style: T.bodySm.c(AppColors.onSurfaceVariant),
          ),
        ]),
      ),
    ]);
  }

  // Waist and hip: two horizontal rulers and a how-to-measure picture.
  Widget _girthPage() {
    final cm = _gUnit == 'cm';
    double show(double v) => cm ? v : v / 2.54;
    Widget girth(String title, String hint, double value, double min, double max, ValueChanged<double> set) => VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: T.headlineSm),
                  Text(hint, style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
              MetricValue(show(value).toStringAsFixed(1), unit: _gUnit, size: 24),
            ]),
            const SizedBox(height: Sp.sm),
            RulerPicker(
              crossExtent: 78,
              spacing: 10,
              value: (show(value) * 2).round() / 2,
              min: cm ? min : (min / 2.54).floorToDouble(),
              max: cm ? max : (max / 2.54).ceilToDouble(),
              step: 0.5,
              majorEvery: 10,
              midEvery: 2,
              label: (v) => v.round().toString(),
              onChanged: (v) => setState(() => set(cm ? v : v * 2.54)),
            ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Intro('Your waist and hip', 'These show where your body stores weight, which matters for heart health.'),
      const SizedBox(height: Sp.md),
      Container(
        height: 200,
        decoration: BoxDecoration(color: AppColors.tint(AppColors.body), borderRadius: BorderRadius.circular(Rad.xl)),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Image.asset('assets/art/measure_guide.webp', fit: BoxFit.contain, alignment: Alignment.bottomCenter),
      ),
      const SizedBox(height: Sp.md),
      _unitToggle(const ['cm', 'in'], _gUnit, (u) => _gUnit = u),
      const SizedBox(height: Sp.md),
      girth('Waist', 'Midway between your lowest rib and hip bone, after breathing out', _waist, 45, 160, (v) => _waist = v),
      const SizedBox(height: Sp.md),
      girth('Hip', 'Around the widest part of your buttocks', _hip, 60, 170, (v) => _hip = v),
    ]);
  }

  // Body shape: where the body tends to store fat.
  Widget _shapePage() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Intro('Which body shape is closest to yours?', 'This helps us understand where your body tends to store fat. There is no right or wrong shape.'),
      const SizedBox(height: Sp.md),
      LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 2 * 10) / 3;
        return Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          for (final s in bodyShapes) SizedBox(width: w, child: _shapeCard(s)),
        ]);
      }),
    ]);
  }

  Widget _shapeCard(BodyShape s) {
    final on = _shape == s.key;
    final c = AppColors.primary;
    final male = AppState.instance.profile?.sex == 'male';
    // Men rarely have an hourglass figure; the balanced male shape is a trapezoid.
    final label = male && s.key == 'hourglass' ? 'Trapezoid' : s.label;
    final note = male && s.key == 'hourglass' ? 'Balanced, with a narrower waist' : s.note;
    return AnimatedContainer(
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
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _shape = s.key);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
            child: Column(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Rad.base),
                child: AspectRatio(
                  aspectRatio: 0.42,
                  child: Image.asset('assets/body_shapes/${male ? 'male' : 'female'}_${s.key}.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter),
                ),
              ),
              const SizedBox(height: 8),
              Text(label, style: T.labelMd.semi.c(on ? c : AppColors.onSurface), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(note, style: T.labelSm.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center, maxLines: 2),
            ]),
          ),
        ),
      ),
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
