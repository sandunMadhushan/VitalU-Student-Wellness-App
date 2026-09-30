import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/catalog.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../auth/registration_screens.dart' show Measure, MeasureField, pickOption;

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final p = AppState.instance.profile!;
  late final _name = TextEditingController(text: p.fullName == 'Student' ? '' : p.fullName);
  late final _regNo = TextEditingController(text: p.registrationNumber ?? '');
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
    if (_regNo.text.trim().length < 3 || _dob == null || _sex == null || _faculty == null || _year == null) {
      return toast(context, 'Registration number, date of birth, sex, faculty and batch are required.', error: true);
    }
    setState(() => _saving = true);
    try {
      final measured = [_h.metric, _w.metric, _waist.metric, _hip.metric].any((v) => v != null);
      await AppState.instance.updateProfile({
        'full_name': _name.text.trim().isEmpty ? null : _name.text.trim(),
        'date_of_birth': _dob == null ? null : DateFormat('yyyy-MM-dd').format(_dob!),
        'sex': _sex,
        'faculty': _faculty,
        'academic_year': _year,
        'registration_number': _regNo.text.trim().toUpperCase(),
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
        toast(context, 'Profile updated');
        goBack(context, '/profile');
      }
    } catch (e) {
      if (mounted) toast(context, 'Could not save changes. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _label(String text) => Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(text, style: T.labelMd.c(AppColors.onSurfaceVariant)));

  Widget _measureRow(IconData icon, Color c, String label, Measure m) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 10),
        child: Row(children: [
          IconCircle(icon, size: 32, iconSize: 18, fg: c, radius: 8, fill: 1),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: T.bodyLg)),
          MeasureField(controller: m.controller, units: [m.metricUnit, m.altUnit], unit: m.unit, onUnit: (u) => setState(() => m.switchTo(u))),
        ]),
      );

  Widget _stepRow(IconData icon, Color c, String label, String value, double v, double min, double max, double step, ValueChanged<double> onChanged) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 6, 8, 6),
        child: Row(children: [
          IconCircle(icon, size: 32, iconSize: 18, fg: c, radius: 8, fill: 1),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: T.bodyLg)),
          IconButton(tooltip: 'Decrease', icon: const Icon(Symbols.remove_rounded), onPressed: v <= min ? null : () => onChanged((v - step).clamp(min, max))),
          SizedBox(width: 64, child: Text(value, style: T.labelLg.semi.tnum, textAlign: TextAlign.center)),
          IconButton(tooltip: 'Increase', icon: const Icon(Symbols.add_rounded), onPressed: v >= max ? null : () => onChanged((v + step).clamp(min, max))),
        ]),
      );

  Widget _removable(IconData icon, Color c, String title, VoidCallback onRemove, {String? subtitle}) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 4, 4, 4),
        child: Row(children: [
          IconCircle(icon, size: 32, iconSize: 18, fg: c, radius: 8, fill: 1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.bodyLg),
              if (subtitle != null) Text(subtitle, style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          IconButton(tooltip: 'Remove', icon: Icon(Symbols.remove_circle_rounded, color: AppColors.error), onPressed: onRemove),
        ]),
      );

  Widget _addField(TextEditingController ctrl, String hint, VoidCallback onAdd) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 4, 4, 4),
        child: Row(children: [
          Icon(Symbols.add_circle_rounded, size: 24, color: AppColors.primary, fill: 1),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: ctrl,
              style: T.bodyLg,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onAdd(),
              decoration: InputDecoration(filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, hintText: hint, contentPadding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          TextButton(onPressed: onAdd, child: const Text('Add')),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: TitleHeader('Edit profile', close: true, onLeading: () => goBack(context, '/profile')),
      bottom: PrimaryButton('Save changes', loading: _saving, onTap: _save),
      spacing: Sp.lg,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _label('Personal details'),
          ListGroup(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.md, 12, Sp.md, 12),
              child: Column(children: [
                VTextField(controller: _name, hint: 'Full name', icon: Symbols.person_rounded),
                const SizedBox(height: 10),
                VTextField(controller: _regNo, hint: 'Registration number', icon: Symbols.badge_rounded),
              ]),
            ),
            ListRow(
              icon: Symbols.cake_rounded,
              color: AppColors.cycle,
              title: 'Date of birth',
              value: _dob == null ? 'Select' : DateFormat('d MMM yyyy').format(_dob!),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _dob ?? DateTime(2003), firstDate: DateTime(1960), lastDate: DateTime.now().subtract(const Duration(days: 365 * 15)));
                if (d != null) setState(() => _dob = d);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 12),
              child: Row(children: [
                IconCircle(Symbols.wc_rounded, size: 32, iconSize: 18, fg: AppColors.water, radius: 8, fill: 1),
                const SizedBox(width: 12),
                Expanded(child: Text('Sex', style: T.bodyLg)),
                Segmented(options: const ['Female', 'Male'], value: _sex == 'male' ? 'Male' : (_sex == 'female' ? 'Female' : ''), onChanged: (v) => setState(() => _sex = v.toLowerCase())),
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
              title: 'Batch',
              value: _year ?? 'Select',
              onTap: () async {
                final v = await pickOption(context, 'Select your batch', academicYears, _year);
                if (v != null) setState(() => _year = v);
              },
            ),
          ]),
        ]),
        ListGroup(
          header: 'Body measurements',
          footer: 'BMI and waist-to-hip ratio update when you save.',
          children: [
            _measureRow(Symbols.height_rounded, AppColors.body, 'Height', _h),
            _measureRow(Symbols.monitor_weight_rounded, AppColors.body, 'Weight', _w),
            _measureRow(Symbols.straighten_rounded, AppColors.body, 'Waist', _waist),
            _measureRow(Symbols.accessibility_new_rounded, AppColors.body, 'Hip', _hip),
          ],
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _label('Health conditions'),
          VCard(
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in _editConds)
                VChip(conditionByKey(k)!.label, selected: _conds.contains(k), onTap: () => setState(() => _conds.contains(k) ? _conds.remove(k) : _conds.add(k))),
              for (final c in _custom) VChip(c, icon: Symbols.close_rounded, selected: true, onTap: () => setState(() => _custom.remove(c))),
              VChip('Add other', icon: Symbols.add_rounded, onTap: () async {
                final c = TextEditingController();
                await showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('Add a condition', style: T.headlineMd),
                      const SizedBox(height: Sp.md),
                      VTextField(controller: c, hint: 'For example, thyroid condition'),
                      const SizedBox(height: Sp.md),
                      PrimaryButton('Add', onTap: () {
                        if (c.text.trim().isNotEmpty) setState(() => _custom.add(c.text.trim()));
                        Navigator.pop(ctx);
                      }),
                    ]));
              }),
            ]),
          ),
        ]),
        ListGroup(header: 'Medications and supplements', children: [
          for (final m in _meds) _removable(Symbols.medication_rounded, AppColors.primary, '${m['name']}', () => setState(() => _meds.remove(m))),
          _addField(_medCtrl, 'For example, Vitamin D3 1000 IU', _addMed),
        ]),
        ListGroup(header: 'Allergies', children: [
          for (final a in _allergies) _removable(Symbols.allergy_rounded, AppColors.error, a, () => setState(() => _allergies.remove(a))),
          _addField(_allergyCtrl, 'For example, penicillin or peanuts', _addAllergy),
        ]),
        ListGroup(header: 'Family history', children: [
          for (final f in _family) _removable(Symbols.family_restroom_rounded, AppColors.heart, '${f['condition']}', subtitle: '${f['relation']}', () => setState(() => _family.remove(f))),
          ListRow(icon: Symbols.add_rounded, color: AppColors.primary, title: 'Add family record', chevron: false, onTap: _addFamilyRecord),
        ]),
        ListGroup(header: 'Daily goals', children: [
          _stepRow(Symbols.water_drop_rounded, AppColors.water, 'Water', '${_water.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '')} L', _water, 1.0, 4.0, 0.25, (v) => setState(() => _water = v)),
          _stepRow(Symbols.bedtime_rounded, AppColors.sleep, 'Sleep', '${_sleep.toStringAsFixed(1)} h', _sleep, 5.0, 10.0, 0.5, (v) => setState(() => _sleep = v)),
          ListRow(
            icon: Symbols.directions_walk_rounded,
            color: AppColors.activity,
            title: 'Activity level',
            subtitle: _activity,
            onTap: () async {
              final v = await pickOption(context, 'Activity level', const ['Mostly sitting', 'Light Walking (Campus)', 'Moderate Walking (Campus)', 'Active / Sports'], _activity);
              if (v != null) setState(() => _activity = v);
            },
          ),
        ]),
        const PrivacyNote('Health details stay private. Health centre staff only see them if you share them during a consultation.'),
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
            Text('Add family record', style: T.headlineMd),
            const SizedBox(height: Sp.md),
            Text('Relative', style: T.labelLg.semi),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in const ['Mother', 'Father', 'Sibling', 'Grandparent']) VChip(r, selected: relation == r, onTap: () => set(() => relation = r)),
            ]),
            const SizedBox(height: Sp.md),
            Text('Condition', style: T.labelLg.semi),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in const ['Heart disease', 'Stroke', 'High blood pressure', 'Diabetes', 'High cholesterol', 'Asthma', 'Other'])
                VChip(c, selected: condition == c, onTap: () => set(() => condition = c)),
            ]),
            const SizedBox(height: Sp.lg),
            PrimaryButton('Save', onTap: () {
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
