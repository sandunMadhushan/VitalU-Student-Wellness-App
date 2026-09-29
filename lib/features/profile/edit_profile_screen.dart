import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/catalog.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../auth/registration_screens.dart' show Measure;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final p = AppState.instance.profile!;
  late final _name = TextEditingController(text: p.fullName == 'Student' ? '' : p.fullName);
  late DateTime? _dob = p.dob;
  late String? _sex = p.sex;
  late String? _faculty = p.faculty;
  late String? _year = p.academicYear;
  late final _h = Measure('cm', 'in', 0.393701, p.heightCm);
  late final _w = Measure('kg', 'lb', 2.20462, p.weightKg);
  late final _waist = Measure('cm', 'in', 0.393701, p.waistCm);
  late final _hip = Measure('cm', 'in', 0.393701, p.hipCm);
  late final Set<String> _conds = {...p.conditions};
  late final List<String> _custom = [...p.customConditions];
  late final List<Map<String, dynamic>> _meds = [...p.medications];
  final _medCtrl = TextEditingController();
  late final List<String> _allergies = [...p.allergies];
  final _allergyCtrl = TextEditingController();
  late final List<Map<String, dynamic>> _family = [...p.familyHistory];
  late double _water = p.waterGoalMl / 1000;
  late double _sleep = p.sleepGoalHours;
  late String _activity = p.activityLevel;
  bool _saving = false;

  static const _editConds = [
    'asthma_allergies',
    'allergies_intolerances',
    'migraine',
    'gastritis',
    'family_heart',
    'family_diabetes',
    'family_cholesterol',
    'family_obesity',
    'high_bp',
    'anxiety_sleep',
    'pcos',
    'anaemia',
    'constipation',
    'skin_disease',
    'kidney_disease',
    'liver_disease',
    'hemorrhoids',
    'std',
  ];

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final measured = [_h.metric, _w.metric, _waist.metric, _hip.metric].any((v) => v != null);
      await AppState.instance.updateProfile({
        'full_name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'date_of_birth': _dob == null ? null : DateFormat('yyyy-MM-dd').format(_dob!),
        'sex': _sex,
        'faculty': _faculty,
        'academic_year': _year,
        'height_cm': _h.metric,
        'weight_kg': _w.metric,
        'waist_cm': _waist.metric,
        'hip_cm': _hip.metric,
        if (measured) 'measured_at': DateTime.now().toUtc().toIso8601String(),
        'health_conditions': _conds.toList(),
        'custom_conditions': _custom,
        'medications': _meds,
        'allergies': _allergies,
        'family_history': _family,
        'water_goal_ml': (_water * 1000).round(),
        'sleep_goal_hours': _sleep,
        'activity_level': _activity,
      });
      if (mounted) {
        toast(context, 'Profile updated 🌿');
        goBack(context, '/profile');
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not save changes. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(String title, String sub, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.toUpperCase(), style: T.labelSm.c(AppColors.tertiary).bold.tracking(1)),
            Text(sub, style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(height: 8),
        VCard(shadow: Shadows.tiny, child: child),
      ]);

  Widget _measureRow(IconData icon, String label, Measure m) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full)),
        child: Row(children: [
          const SizedBox(width: 8),
          Icon(icon, size: 20, color: AppColors.tertiary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: T.labelMd)),
          SizedBox(
            width: 72,
            child: TextField(
              controller: m.controller,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: T.headlineSm,
              decoration: InputDecoration(isDense: true, border: InputBorder.none, hintText: '—', hintStyle: T.headlineSm.c(AppColors.outlineVariant)),
            ),
          ),
          const SizedBox(width: 8),
          Segmented(options: [m.metricUnit, m.altUnit], value: m.unit, onChanged: (u) => setState(() => m.switchTo(u))),
        ]),
      );

  Future<void> _pick(String title, List<String> options, ValueChanged<String> onPick) async {
    final v = await showVSheet<String>(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: T.headlineSm),
          const SizedBox(height: Sp.sm),
          for (final o in options) ListTile(title: Text(o, style: T.labelLg), onTap: () => Navigator.pop(ctx, o)),
        ]));
    if (v != null) setState(() => onPick(v));
  }

  Widget _goal(IconData icon, String label, String value, double v, double min, double max, double step, ValueChanged<double> onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconCircle(icon, size: 32, iconSize: 18, bg: AppColors.surfaceContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: T.labelLg)),
          Text(value, style: T.headlineSm.c(AppColors.tertiary)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          CircleButton(Symbols.remove, size: 40, iconSize: 18, bg: AppColors.surfaceContainer, fg: AppColors.onSurface, onTap: () => onChanged((v - step).clamp(min, max))),
          Expanded(child: VSlider(value: v, min: min, max: max, divisions: ((max - min) / step).round(), color: AppColors.tertiary, onChanged: onChanged)),
          CircleButton(Symbols.add, size: 40, iconSize: 18, bg: AppColors.surfaceContainer, fg: AppColors.onSurface, onTap: () => onChanged((v + step).clamp(min, max))),
        ]),
      ]);

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: const BrandBackHeader(chip: 'Edit Profile'),
      backgroundDecoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.surface, AppColors.surfaceContainerLow, AppColors.surfaceContainer]),
      ),
      background: Colors.transparent,
      spacing: Sp.lg,
      children: [
        Column(children: [
          const SizedBox(height: 4),
          TagPill('Zero-Pressure Edits • Private & Encrypted', icon: Symbols.lock, iconColor: AppColors.tertiary),
          const SizedBox(height: Sp.md),
          IconCircle(Symbols.tune, size: 48, iconSize: 24, bg: AppColors.surfaceContainerHigh, shadow: Shadows.tiny),
          const SizedBox(height: 8),
          Text('Update Your Information', style: T.headlineMd),
          const SizedBox(height: 2),
          SizedBox(width: 280, child: Text('Your personal sanctuary for gentle, mindful recalibration.', textAlign: TextAlign.center, style: T.bodySm.c(AppColors.onSurfaceVariant))),
          const SizedBox(height: Sp.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(Rad.lg),
            child: SizedBox(
              height: 96,
              child: Stack(fit: StackFit.expand, children: [
                const AssetImg('morning_bedside'),
                Container(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.surface.withValues(alpha: 0.85), AppColors.surface.withValues(alpha: 0.4), Colors.transparent])),
                  padding: const EdgeInsets.symmetric(horizontal: Sp.md),
                  alignment: Alignment.centerLeft,
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('MINDFUL SYNC', style: T.labelSm.c(AppColors.tertiary).tracking(1)),
                    Text('Paced to your semester', style: T.headlineSm),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
        _section(
          'Personal Details',
          'Used to personalise targets and assessments',
          Column(children: [
            VTextField(controller: _name, hint: 'Full name', icon: Symbols.person),
            const SizedBox(height: Sp.sm),
            Row(children: [
              Expanded(
                child: SoftButton(_dob == null ? 'Date of birth' : DateFormat('d MMM yyyy').format(_dob!), icon: Symbols.calendar_today, iconColor: AppColors.secondary, height: 48, style: T.labelMd, onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _dob ?? DateTime(2003), firstDate: DateTime(1960), lastDate: DateTime.now().subtract(const Duration(days: 365 * 15)));
                  if (d != null) setState(() => _dob = d);
                }),
              ),
              const SizedBox(width: 8),
              Segmented(options: const ['Female', 'Male'], value: _sex == 'male' ? 'Male' : (_sex == 'female' ? 'Female' : ''), small: false, onChanged: (v) => setState(() => _sex = v.toLowerCase())),
            ]),
            const SizedBox(height: Sp.sm),
            SoftButton(_faculty ?? 'Select faculty', icon: Symbols.school, iconColor: AppColors.primary, height: 48, style: T.labelMd, onTap: () => _pick('Faculty', faculties, (v) => _faculty = v)),
            const SizedBox(height: Sp.sm),
            SoftButton(_year ?? 'Select academic year', icon: Symbols.workspace_premium, iconColor: AppColors.primary, height: 48, style: T.labelMd, onTap: () => _pick('Academic Year', academicYears, (v) => _year = v)),
          ]),
        ),
        _section(
          'Anthropometrics & Body Metrics',
          'Update anytime to calibrate your daily hydration and stride',
          Column(children: [
            _measureRow(Symbols.height, 'Height', _h),
            const SizedBox(height: Sp.sm),
            _measureRow(Symbols.monitor_weight, 'Weight', _w),
            const SizedBox(height: Sp.sm),
            _measureRow(Symbols.straighten, 'Waist', _waist),
            const SizedBox(height: Sp.sm),
            _measureRow(Symbols.accessibility_new, 'Hip', _hip),
            const SizedBox(height: Sp.sm),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Symbols.magic_button, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('BMI & WHR recalculate automatically upon saving.', style: T.labelSm.c(AppColors.onSurfaceVariant)),
            ]),
          ]),
        ),
        _section(
          'Health Background & Conditions',
          'Select all that apply',
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in _editConds)
              VChip(conditionByKey(k)!.label, icon: _conds.contains(k) ? Symbols.check : null, selected: _conds.contains(k), selectedColor: AppColors.tertiary, color: AppColors.surfaceContainer,
                  onTap: () => setState(() => _conds.contains(k) ? _conds.remove(k) : _conds.add(k))),
            for (final c in _custom) VChip(c, icon: Symbols.close, selected: true, selectedColor: AppColors.tertiary, onTap: () => setState(() => _custom.remove(c))),
            VChip('None of these', selected: _conds.isEmpty && _custom.isEmpty, selectedColor: AppColors.onSurface, color: AppColors.surfaceContainer, onTap: () => setState(() {
                  _conds.clear();
                  _custom.clear();
                })),
            VChip('Add custom condition...', icon: Symbols.add, color: AppColors.surfaceContainerLow, fg: AppColors.primary, onTap: () async {
              final c = TextEditingController();
              await showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Custom condition', style: T.headlineMd),
                    const SizedBox(height: Sp.md),
                    VTextField(controller: c, hint: 'e.g. Thyroid condition'),
                    const SizedBox(height: Sp.md),
                    PrimaryButton('Add', color: AppColors.tertiary, onTap: () {
                      if (c.text.trim().isNotEmpty) setState(() => _custom.add(c.text.trim()));
                      Navigator.pop(ctx);
                    }),
                  ]));
            }),
          ]),
        ),
        _section(
          'Current Medications & Supplements',
          'Keep track of active prescriptions or daily vitamins',
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_meds.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in _meds)
                  Container(
                    height: 38,
                    padding: const EdgeInsets.only(left: 14, right: 6),
                    decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(Rad.full), boxShadow: Shadows.tiny),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Symbols.medication, size: 16, color: AppColors.tertiary),
                      const SizedBox(width: 6),
                      Text('${m['name']}', style: T.labelMd),
                      const SizedBox(width: 4),
                      GestureDetector(onTap: () => setState(() => _meds.remove(m)), child: Icon(Symbols.close, size: 16, color: AppColors.onSurfaceVariant)),
                    ]),
                  ),
              ]),
            if (_meds.isNotEmpty) const SizedBox(height: Sp.md),
            Container(
              padding: const EdgeInsets.only(left: 16, right: 6),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full)),
              child: Row(children: [
                Icon(Symbols.vaccines, size: 20, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _medCtrl,
                    style: T.bodyMd,
                    onSubmitted: (_) => _addMed(),
                    decoration: InputDecoration(border: InputBorder.none, hintText: 'e.g., Vitamin D3, 1000 IU', hintStyle: T.bodyMd.c(AppColors.outline)),
                  ),
                ),
                CircleButton(Symbols.add, size: 36, iconSize: 20, bg: AppColors.tertiary, fg: AppColors.onTertiary, onTap: _addMed),
              ]),
            ),
            const SizedBox(height: Sp.md),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(Rad.base)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Symbols.verified_user, size: 18, color: AppColors.tertiary),
                const SizedBox(width: 8),
                Expanded(child: Text('Campus health practitioners only see this if you choose to share it during a consultation.', style: T.bodySm.c(AppColors.onSurfaceVariant))),
              ]),
            ),
          ]),
        ),
        _section(
          'Allergies',
          'Anything campus health staff should know before treating you',
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_allergies.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in _allergies)
                  Container(
                    height: 38,
                    padding: const EdgeInsets.only(left: 14, right: 6),
                    decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(Rad.full), boxShadow: Shadows.tiny),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Symbols.warning, size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      Text(a, style: T.labelMd.c(AppColors.onErrorContainer)),
                      const SizedBox(width: 4),
                      GestureDetector(onTap: () => setState(() => _allergies.remove(a)), child: Icon(Symbols.close, size: 16, color: AppColors.onErrorContainer)),
                    ]),
                  ),
              ]),
            if (_allergies.isNotEmpty) const SizedBox(height: Sp.md),
            Container(
              padding: const EdgeInsets.only(left: 16, right: 6),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full)),
              child: Row(children: [
                Icon(Symbols.warning, size: 20, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _allergyCtrl,
                    style: T.bodyMd,
                    onSubmitted: (_) => _addAllergy(),
                    decoration: InputDecoration(border: InputBorder.none, hintText: 'e.g. Penicillin, peanuts, dust', hintStyle: T.bodyMd.c(AppColors.outline)),
                  ),
                ),
                CircleButton(Symbols.add, size: 36, iconSize: 20, bg: AppColors.tertiary, fg: AppColors.onTertiary, onTap: _addAllergy),
              ]),
            ),
          ]),
        ),
        _section(
          'Family Health History',
          'Confidential — helps tailor gentle preventative tips',
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_family.isEmpty) Text('No records yet', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            for (final f in _family)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Expanded(child: Text('${f['relation']}', style: T.labelMd)),
                  Flexible(child: Text('${f['condition']}', textAlign: TextAlign.right, style: T.labelSm.c(AppColors.onSurfaceVariant))),
                  const SizedBox(width: 4),
                  GestureDetector(onTap: () => setState(() => _family.remove(f)), child: Icon(Symbols.close, size: 16, color: AppColors.onSurfaceVariant)),
                ]),
              ),
            const SizedBox(height: Sp.sm),
            SoftButton('Add Family Record', icon: Symbols.add, color: AppColors.surfaceContainerLow, fg: AppColors.tertiary, height: 44, style: T.labelMd, onTap: _addFamilyRecord),
          ]),
        ),
        _section(
          'Lifestyle Pacing & Goals',
          'Calibrate comfortable targets for your study-rest cadence',
          Column(children: [
            _goal(Symbols.water_drop, 'Daily Hydration', '${_water.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '')} L', _water, 1.0, 4.0, 0.25, (v) => setState(() => _water = v)),
            const SizedBox(height: Sp.sm),
            _goal(Symbols.bedtime, 'Sleep Target', '${_sleep.toStringAsFixed(1)} hrs', _sleep, 5.0, 10.0, 0.5, (v) => setState(() => _sleep = v)),
            const SizedBox(height: Sp.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final a in const ['Mostly sitting', 'Light Walking (Campus)', 'Moderate Walking (Campus)', 'Active / Sports'])
                  VChip(a, selected: _activity == a, selectedColor: AppColors.tertiary, onTap: () => setState(() => _activity = a)),
              ]),
            ),
          ]),
        ),
        Column(children: [
          PrimaryButton('Save Changes', leadingIcon: Symbols.check, color: AppColors.tertiary, height: 54, loading: _saving, onTap: _save),
          TextLinkButton('Discard changes', onTap: () => goBack(context, '/profile')),
        ]),
      ],
    );
  }

  void _addAllergy() {
    final t = _allergyCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _allergies.add(t);
      _allergyCtrl.clear();
    });
  }

  Future<void> _addFamilyRecord() async {
    String relation = 'Mother';
    String condition = 'High blood pressure';
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add Family Health Record', style: T.headlineMd),
            const SizedBox(height: Sp.md),
            Text('Relative', style: T.labelLg),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in const ['Mother', 'Father', 'Sibling', 'Grandparent']) VChip(r, selected: relation == r, selectedColor: AppColors.secondary, onTap: () => set(() => relation = r)),
            ]),
            const SizedBox(height: Sp.md),
            Text('Condition', style: T.labelLg),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in const ['Heart disease', 'Stroke', 'High blood pressure', 'Diabetes', 'High cholesterol', 'Asthma', 'Other'])
                VChip(c, selected: condition == c, selectedColor: AppColors.secondary, onTap: () => set(() => condition = c)),
            ]),
            const SizedBox(height: Sp.lg),
            PrimaryButton('Save Record', color: AppColors.secondary, onTap: () {
              setState(() {
                _family.add({'relation': relation, 'condition': condition, 'added': DateFormat('yyyy-MM-dd').format(DateTime.now())});
                if (condition == 'Heart disease' || condition == 'Stroke') _conds.add('family_heart');
                if (condition == 'Diabetes') _conds.add('family_diabetes');
                if (condition == 'High blood pressure') _conds.add('family_hypertension');
                if (condition == 'High cholesterol') _conds.add('family_cholesterol');
              });
              Navigator.pop(ctx);
            }),
          ]);
        }));
  }

  void _addMed() {
    final t = _medCtrl.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _meds.add({'name': t});
      _medCtrl.clear();
    });
  }
}
