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
  const _StepProgress({required this.step, required this.label, this.thin = false});
  final int step;
  final String label;
  final bool thin;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('STEP $step OF 3', style: T.labelSm.c(AppColors.tertiary).bold.tracking(1)),
          const Spacer(),
          Text(label, style: T.labelSm.c(AppColors.onSurfaceVariant).medium),
        ]),
        const SizedBox(height: Sp.xs + 2),
        Row(children: [
          for (int i = 1; i <= 3; i++) ...[
            if (i > 1) const SizedBox(width: Sp.xs + 2),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: thin ? 6 : 8,
                decoration: BoxDecoration(
                  color: i <= step ? AppColors.tertiary : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: i <= step ? Shadows.tinted(AppColors.tertiary, opacity: 0.25, blur: 8, y: 2, spread: 0) : null,
                ),
              ),
            ),
          ]
        ]),
      ]);
}

class _FooterNote extends StatelessWidget {
  const _FooterNote(this.text, {this.icon = Symbols.encrypted});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 14, color: AppColors.outline),
        const SizedBox(width: 6),
        Flexible(child: Text(text, textAlign: TextAlign.center, style: T.labelSm.c(AppColors.outline))),
      ]);
}

Future<void> _saveStep(Map<String, dynamic> values, int step) async {
  final current = AppState.instance.profile?.registrationStep ?? 0;
  await AppState.instance.updateProfile({...values, 'registration_step': step > current ? step : current});
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
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.tertiary)),
        child: child!,
      ),
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

  Widget _card({required String label, required Widget badge, String? help, required IconData icon, required Color iconBg, required Color iconFg, required Widget control}) {
    return VCard(
      shadow: const [BoxShadow(color: Color(0x0D1C1A26), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -6)],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Text(label.toUpperCase(), style: T.labelSm.c(AppColors.outline).bold.tracking(1)), const Spacer(), badge]),
        if (help != null) ...[const SizedBox(height: 2), Text(help, style: T.bodySm.c(AppColors.onSurfaceVariant))],
        const SizedBox(height: Sp.xs + 4),
        Row(children: [IconCircle(icon, bg: iconBg, fg: iconFg, iconSize: 20), const SizedBox(width: Sp.sm), Expanded(child: control)]),
      ]),
    );
  }

  Widget _selectPill(String text, VoidCallback onTap, {bool placeholder = false}) => Pressable(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 16, right: 12),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full)),
          child: Row(children: [
            Expanded(child: Text(text, style: T.labelLg.c(placeholder ? AppColors.outline : AppColors.onSurface), overflow: TextOverflow.ellipsis)),
            Icon(Symbols.expand_more, size: 20, color: AppColors.onSurfaceVariant),
          ]),
        ),
      );

  Future<void> _pickFrom(String title, List<String> options, String? current, ValueChanged<String> onPick) async {
    final v = await showVSheet<String>(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: T.headlineSm),
          const SizedBox(height: Sp.sm),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VCard(
                color: o == current ? AppColors.tertiaryFixed : AppColors.surfaceContainerLow,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                radius: Rad.md,
                onTap: () => Navigator.pop(ctx, o),
                child: Row(children: [
                  Expanded(child: Text(o, style: T.labelLg)),
                  if (o == current) Icon(Symbols.check_circle, color: AppColors.tertiary, fill: 1),
                ]),
              ),
            ),
        ]));
    if (v != null) onPick(v);
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: RegistrationHeader(onBack: () => context.canPop() ? context.pop() : null),
      spacing: Sp.sm,
      children: [
        const Padding(padding: EdgeInsets.only(top: Sp.sm, bottom: Sp.sm), child: _StepProgress(step: 1, label: 'Basic Info')),
        VCard(
          color: AppColors.surfaceContainerLow,
          shadow: Shadows.tiny,
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TagPill('Gentle Start', icon: Symbols.spa, bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixedVariant),
                const SizedBox(height: 6),
                Text('Tell us about you', style: T.headlineMd.lh(1.2)),
                const SizedBox(height: 4),
                Text('This helps VitalU tailor your daily baseline pace and care routine.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(width: Sp.sm),
            ClipOval(child: const AssetImg('heart_leaf', width: 64, height: 64)),
          ]),
        ),
        const SizedBox(height: 4),
        _card(
          label: 'Date of Birth',
          badge: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Symbols.lock, size: 13, color: AppColors.tertiary),
            const SizedBox(width: 2),
            Text('Private', style: T.labelSm.c(AppColors.tertiary)),
          ]),
          icon: Symbols.calendar_today,
          iconBg: AppColors.secondaryFixed,
          iconFg: AppColors.onSecondaryFixed,
          control: _selectPill(_dob == null ? 'Select date' : DateFormat('d MMMM yyyy').format(_dob!), _pickDob, placeholder: _dob == null),
        ),
        _card(
          label: 'Sex',
          badge: Text('Physiological metrics', style: T.labelSm.c(AppColors.onSurfaceVariant).medium),
          help: 'Helps tailor accurate hydration and heart rate baseline models.',
          icon: Symbols.ecg_heart,
          iconBg: AppColors.tertiaryFixed,
          iconFg: AppColors.onTertiaryFixedVariant,
          control: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full)),
            child: Row(children: [
              for (final s in const [('female', 'Female', Symbols.female), ('male', 'Male', Symbols.male)])
                Expanded(
                  child: Pressable(
                    onTap: () => setState(() => _sex = s.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: _sex == s.$1 ? AppColors.tertiary : Colors.transparent,
                        borderRadius: BorderRadius.circular(Rad.full),
                        boxShadow: _sex == s.$1 ? Shadows.tiny : null,
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(s.$3, size: 16, color: _sex == s.$1 ? AppColors.onTertiary : AppColors.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(s.$2, style: T.labelMd.c(_sex == s.$1 ? AppColors.onTertiary : AppColors.onSurfaceVariant)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
        _card(
          label: 'Faculty',
          badge: Text('Campus syncing', style: T.labelSm.c(AppColors.primary).medium),
          icon: Symbols.school,
          iconBg: AppColors.primaryFixed,
          iconFg: AppColors.onPrimaryFixed,
          control: _selectPill(_faculty ?? 'Select your faculty', () => _pickFrom('Faculty', faculties, _faculty, (v) => setState(() => _faculty = v)), placeholder: _faculty == null),
        ),
        _card(
          label: 'Academic Year',
          badge: Text('Exam cycle sync', style: T.labelSm.c(AppColors.onSurfaceVariant).medium),
          icon: Symbols.workspace_premium,
          iconBg: AppColors.surfaceContainerHigh,
          iconFg: AppColors.onSurface,
          control: _selectPill(_year ?? 'Select your year', () => _pickFrom('Academic Year', academicYears, _year, (v) => setState(() => _year = v)), placeholder: _year == null),
        ),
        VCard(
          color: AppColors.surfaceContainer,
          radius: Rad.xl,
          child: Row(children: [
            IconCircle(Symbols.verified, size: 36, iconSize: 18, shadow: Shadows.tiny),
            const SizedBox(width: Sp.sm),
            Expanded(child: Text('VitalU schedules periodic health assessments by faculty, so your check-ins fit your academic calendar.', style: T.bodySm.c(AppColors.onSurfaceVariant))),
          ]),
        ),
        const SizedBox(height: Sp.xs),
        PrimaryButton('Continue to Wellness Goals', icon: Symbols.arrow_forward, color: AppColors.tertiary, height: 52, loading: _busy, onTap: () => _continue()),
        Center(child: TextLinkButton('Skip for now, fill later', onTap: () => _continue(skip: true))),
        const _FooterNote('Your personal data is encrypted & private to you.'),
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
  late Set<String> _selected = {...?AppState.instance.profile?.conditions};
  bool _none = false;
  bool _busy = false;

  static const _keys = ['family_heart', 'family_diabetes', 'asthma_allergies', 'high_bp', 'migraine', 'anxiety_sleep'];

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
      header: RegistrationHeader(onBack: () => goBack(context, '/register/1')),
      spacing: Sp.md,
      children: [
        const Padding(padding: EdgeInsets.only(top: Sp.sm), child: _StepProgress(step: 2, label: 'Health Background')),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Any health history we should know?', style: T.headlineLg),
          const SizedBox(height: 4),
          Text('Optional — you can skip and add this later at any time.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ]),
        VCard(
          color: AppColors.surfaceContainerLow,
          clip: true,
          shadow: Shadows.tinted(AppColors.primary, opacity: 0.06, blur: 24, y: 8),
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned(right: -36, bottom: -44, child: Glow(color: AppColors.primaryFixed.withValues(alpha: 0.4), size: 96)),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconCircle(Symbols.verified_user, size: 40, iconSize: 20, fg: AppColors.tertiary, fill: 1, shadow: Shadows.tiny),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TagPill('Private & Encrypted', icon: Symbols.lock, bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixed),
                  const SizedBox(height: 6),
                  Text('Strictly confidential. VitalU uses this solely to tailor gentle preventative tips — never shared with lecturers or your faculty.',
                      style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
                ]),
              ),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Text('SELECT ANY THAT APPLY (OPTIONAL)', style: T.labelSm.c(AppColors.outline).bold.tracking(1)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() {
                  _selected.clear();
                  _none = false;
                }),
                child: Text('Clear', style: T.labelSm.c(AppColors.primary)),
              ),
            ]),
          ),
          const SizedBox(height: Sp.sm),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final k in _keys) _chip(conditionByKey(k)!),
            Pressable(
              onTap: () => setState(() {
                _none = !_none;
                if (_none) _selected.clear();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _none ? AppColors.onSurface : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(Rad.lg),
                  boxShadow: Shadows.tiny,
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Symbols.do_not_disturb_on, size: 18, color: _none ? Colors.white : AppColors.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text('None of these apply to me', style: T.bodyMd.medium.c(_none ? Colors.white : AppColors.onSurfaceVariant)),
                ]),
              ),
            ),
          ]),
        ]),
        Row(children: [
          Icon(Symbols.info, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text('You can update or remove any of these details at any time in your Health Profile.', style: T.bodySm.c(AppColors.onSurfaceVariant))),
        ]),
        Column(children: [
          PrimaryButton('Continue to Measurements', icon: Symbols.arrow_forward, color: AppColors.tertiary, loading: _busy, onTap: () => _continue()),
          TextLinkButton('Skip this step', onTap: () => _continue(skip: true)),
          const _FooterNote('Encrypted in transit & at rest • Private to you'),
        ]),
      ],
    );
  }

  Widget _chip(Condition c) {
    final on = _selected.contains(c.key);
    return Pressable(
      onTap: () => setState(() {
        on ? _selected.remove(c.key) : _selected.add(c.key);
        if (!on) _none = false;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: on ? AppColors.tertiary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(Rad.lg),
          boxShadow: on ? Shadows.tinted(AppColors.tertiary, opacity: 0.22, blur: 20, y: 8, spread: 0) : const [BoxShadow(color: Color(0x0A2D2B38), blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          IconCircle(c.icon, size: 32, iconSize: 18, bg: on ? Colors.white.withValues(alpha: 0.15) : AppColors.surfaceContainerLow, fg: on ? AppColors.onTertiary : (c.secondaryTint ? AppColors.secondary : AppColors.primary)),
          const SizedBox(width: 10),
          Text(c.label, style: T.bodyMd.c(on ? AppColors.onTertiary : AppColors.onSurface).w(on ? FontWeight.w600 : FontWeight.w500)),
          if (on) ...[const SizedBox(width: 6), Icon(Symbols.check_circle, size: 18, fill: 1, color: AppColors.tertiaryFixed)],
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — body measurements
// ---------------------------------------------------------------------------

class MeasureField extends StatelessWidget {
  const MeasureField({super.key, required this.controller, required this.units, required this.unit, required this.onUnit, this.hint, this.accent});
  final TextEditingController controller;
  final List<String> units;
  final String unit;
  final ValueChanged<String> onUnit;
  final String? hint;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final accent0 = accent ?? AppColors.tertiary;
    return Row(children: [
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: Sp.md),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full)),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: T.headlineSm,
              decoration: InputDecoration(isDense: true, border: InputBorder.none, hintText: hint, hintStyle: T.headlineSm.c(AppColors.outlineVariant)),
            ),
          ),
        ),
        const SizedBox(width: Sp.sm),
        Container(
          height: 52,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full)),
          child: Row(children: [
            for (final u in units)
              GestureDetector(
                onTap: () => onUnit(u),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: u == unit ? accent0 : Colors.transparent, borderRadius: BorderRadius.circular(Rad.full)),
                  child: Text(u, style: T.labelMd.c(u == unit ? Colors.white : AppColors.onSurfaceVariant)),
                ),
              ),
          ]),
        ),
      ]);
  }
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
      if (h != null && (h < 100 || h > 230)) err = 'Height looks unusual — please check it.';
      if (w != null && (w < 25 || w > 250)) err = 'Weight looks unusual — please check it.';
      if (wa != null && (wa < 40 || wa > 200)) err = 'Waist looks unusual — please check it.';
      if (hi != null && (hi < 50 || hi > 200)) err = 'Hip looks unusual — please check it.';
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

  Widget _card(String title, String sub, IconData icon, Measure m, {bool optional = false}) => VCard(
        radius: Rad.md,
        shadow: Shadows.card,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconCircle(icon, bg: AppColors.surfaceContainerLow, fg: AppColors.tertiary),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.headlineSm),
                Text(sub, style: T.bodySm.c(optional ? AppColors.outline : AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          const SizedBox(height: Sp.sm),
          MeasureField(controller: m.controller, units: [m.metricUnit, m.altUnit], unit: m.unit, onUnit: (u) => setState(() => m.switchTo(u))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: RegistrationHeader(onBack: () => goBack(context, '/register/2')),
      spacing: Sp.md,
      children: [
        const _StepProgress(step: 3, label: 'Body Measurements', thin: true),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TagPill('Optional & Confidential', icon: Symbols.lock, bg: AppColors.surfaceContainerHigh, fg: AppColors.tertiary),
          const SizedBox(height: Sp.xs + 2),
          Text('A few numbers to personalize your tools', style: T.headlineMd.bold),
          const SizedBox(height: 4),
          Text("Don't know these? No problem, skip and add later.", style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ]),
        _card('Height', 'For stride & metabolic rate', Symbols.height, _h),
        _card('Weight', 'Helps baseline hydration targets', Symbols.monitor_weight, _w),
        _card('Waist Circumference', 'Optional • Gentle estimate', Symbols.straighten, _waist, optional: true),
        _card('Hip Circumference', 'Optional • Balances ratio calculations', Symbols.accessibility_new, _hip, optional: true),
        VCard(
          color: AppColors.surfaceContainerHigh,
          radius: Rad.md,
          shadow: Shadows.tiny,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(Symbols.auto_awesome, size: 36, iconSize: 20, bg: AppColors.tertiaryContainer, fg: AppColors.onTertiaryContainer),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("We'll calculate your BMI and WHR automatically once you add these.", style: T.labelLg),
                const SizedBox(height: 4),
                Text('Zero judgment or rigid body targets — these simply unlock accurate hydration targets and heart-health insights tailored to you.',
                    style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: Sp.sm),
        Column(children: [
          PrimaryButton('Finish Setup', icon: Symbols.check, color: AppColors.tertiary, height: 54, loading: _busy, onTap: () => _finish()),
          TextLinkButton("I'll add this later", onTap: () => _finish(skip: true)),
          const _FooterNote('Private & encrypted • Only visible to you', icon: Symbols.verified_user),
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
    final name = AppState.instance.profile?.firstName ?? 'there';
    Widget tile(IconData icon, Color bg, Color fg, String t, String s) => Expanded(
          child: VCard(
            color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
            padding: const EdgeInsets.all(12),
            shadow: Shadows.soft,
            child: Column(children: [
              IconCircle(icon, bg: bg, fg: fg, fill: 1, shadow: Shadows.tiny),
              const SizedBox(height: 8),
              Text(t, style: T.labelMd, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(s, style: T.labelSm.c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
            ]),
          ),
        );
    return VPage(
      header: const BrandBackHeader(chip: 'All set'),
      backgroundDecoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.surface, AppColors.surfaceContainerLow, AppColors.surfaceContainer]),
      ),
      background: Colors.transparent,
      spacing: Sp.md,
      children: [
        Center(
          child: Pill(
            color: AppColors.surfaceContainerLowest,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            shadow: Shadows.tiny,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('PROFILE READY', style: T.labelSm.c(AppColors.tertiary).tracking(1)),
            ]),
          ),
        ),
        Center(
          child: Stack(alignment: Alignment.center, children: [
            Glow(color: AppColors.tertiaryFixedDim.withValues(alpha: 0.35), size: 200),
            Container(
              width: 224,
              height: 224,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(56), boxShadow: const [BoxShadow(color: Color(0x3860DDA2), blurRadius: 28, offset: Offset(0, 16))]),
              child: const AssetImg('registration_badge', radius: 56),
            ),
          ]),
        ),
        Column(children: [
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: "You're All Set, "),
              TextSpan(text: '$name!', style: TextStyle(color: AppColors.primary)),
            ]),
            textAlign: TextAlign.center,
            style: T.headlineXlMobile,
          ),
          const SizedBox(height: 6),
          Text('Your personalized health space is ready.', style: T.bodyMd.c(AppColors.onSurfaceVariant).medium),
          const SizedBox(height: 4),
          Text('Gentle reminders and tools crafted for your university rhythm — at your own pace.', textAlign: TextAlign.center, style: T.bodySm.c(AppColors.outline)),
        ]),
        Column(children: [
          Row(children: [
            Text('YOUR SPACE INCLUDES', style: T.labelSm.c(AppColors.outline).tracking(1.6)),
            const Spacer(),
            Text('3 Unlocked', style: T.labelSm.c(AppColors.primary).medium),
          ]),
          const SizedBox(height: Sp.sm),
          Row(children: [
            tile(Symbols.vital_signs, AppColors.tertiaryFixed, AppColors.onTertiaryFixed, 'Tools', 'Vitals & habits'),
            const SizedBox(width: Sp.xs),
            tile(Symbols.water_drop, AppColors.secondaryFixed, AppColors.onSecondaryFixed, 'Dietary', 'Meals & water'),
            const SizedBox(width: Sp.xs),
            tile(Symbols.lightbulb, AppColors.primaryFixed, AppColors.onPrimaryFixed, 'Learn', 'Campus tips'),
          ]),
        ]),
        VCard(
          gradient: LinearGradient(colors: [AppColors.surfaceContainerLow, AppColors.surfaceContainerHigh.withValues(alpha: 0.6)]),
          shadow: Shadows.tiny,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(Symbols.spa, size: 32, iconSize: 18, bg: AppColors.primaryContainer.withValues(alpha: 0.2)),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sanctuary First', style: T.labelSm.s(12)),
                const SizedBox(height: 2),
                Text('Campus life gets busy. Whenever you open VitalU, take a deep breath. You are doing great.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        PrimaryButton('Go to My Dashboard', icon: Symbols.arrow_forward, color: AppColors.tertiaryContainer, shadowColor: AppColors.tertiary, onTap: () => context.go('/home')),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Symbols.favorite, size: 16, fill: 1, color: AppColors.tertiary),
          const SizedBox(width: 6),
          Text('No streaks, no pressure. Just supportive daily care.', style: T.labelSm.c(AppColors.onSurfaceVariant.withValues(alpha: 0.8))),
        ]),
      ],
    );
  }
}
