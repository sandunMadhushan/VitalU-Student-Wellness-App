import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'tool_widgets.dart';

/// Factor-based cardiovascular risk indicator. Each answer carries a point
/// value; the total is shown as a share of the maximum possible for the
/// factors that were actually answered, so leaving the optional blood tests
/// blank never inflates the score.
class _Factor {
  const _Factor(this.key, this.label, this.points, {this.note});
  final String key;
  final String label;
  final int points;
  final String? note;
}

class HeartRiskScreen extends StatefulWidget {
  const HeartRiskScreen({super.key});
  @override
  State<HeartRiskScreen> createState() => _HeartRiskScreenState();
}

class _HeartRiskScreenState extends State<HeartRiskScreen> {
  bool _loading = true;
  Rec? _result;
  bool _editing = false;

  // Inputs — prefilled from the profile where possible, editable here.
  String _age = '30-45';
  String _sex = 'female';
  double _heightCm = 165;
  double _weightKg = 60;
  String _smoking = 'never';
  String _activity = 'active';
  bool _familyHistory = false;
  bool _diabetes = false;
  bool _hypertension = false;
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  final _glucose = TextEditingController();
  final _cholesterol = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = AppState.instance.profile;
    final age = _ageFromDob(p?.dob);
    if (age != null) _age = age;
    if (p?.sex != null) _sex = p!.sex!;
    _heightCm = p?.heightCm ?? _heightCm;
    _weightKg = p?.weightKg ?? _weightKg;
    _familyHistory = (p?.conditions.contains('family_heart') ?? false) || (p?.conditions.contains('family_hypertension') ?? false);
    _hypertension = p?.conditions.contains('high_bp') ?? false;
    _heightCtrl.text = _heightCm.round().toString();
    _weightCtrl.text = _weightKg.round().toString();
    try {
      final rows = await Repo.toolResults('cvd', limit: 1);
      if (rows.isNotEmpty) _result = rows.first;
    } catch (_) {}
    _editing = _result == null;
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _sys.dispose();
    _dia.dispose();
    _glucose.dispose();
    _cholesterol.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  String? _ageFromDob(DateTime? dob) {
    if (dob == null) return null;
    final years = DateTime.now().difference(dob).inDays ~/ 365;
    if (years < 30) return 'under-30';
    if (years <= 45) return '30-45';
    if (years <= 60) return '46-60';
    return 'over-60';
  }

  double? get _bmi => Calc.bmi(_heightCm, _weightKg);

  List<_Factor> get _factors {
    final bmi = _bmi;
    return [
      _Factor('age', 'Age', const {'under-30': 0, '30-45': 1, '46-60': 2, 'over-60': 3}[_age]!),
      _Factor('sex', 'Sex', _sex == 'male' ? 1 : 0),
      if (bmi != null) _Factor('bmi', 'Body mass index', bmi < 25 ? 0 : (bmi < 30 ? 1 : 2), note: 'BMI ${bmi.toStringAsFixed(1)}'),
      _Factor('smoking', 'Smoking', const {'never': 0, 'occasional': 1, 'daily': 2}[_smoking]!),
      _Factor('activity', 'Physical activity', const {'active': 0, 'rarely': 1, 'inactive': 2}[_activity]!),
      _Factor('family', 'Family history of heart attack', _familyHistory ? 2 : 0),
      _Factor('diabetes', 'Diabetes', _diabetes ? 2 : 0),
      _Factor('hypertension', 'High blood pressure (diagnosed)', _hypertension ? 2 : 0),
      if (_bpPoints != null) _Factor('bp', 'Blood pressure', _bpPoints!, note: '$_sysVal/$_diaVal mmHg'),
      if (_glucosePoints != null) _Factor('glucose', 'Fasting blood sugar', _glucosePoints!, note: '$_glucoseVal mg/dL'),
      if (_cholesterolPoints != null) _Factor('cholesterol', 'Total cholesterol', _cholesterolPoints!, note: '$_cholesterolVal mg/dL'),
    ];
  }

  int? get _sysVal => int.tryParse(_sys.text);
  int? get _diaVal => int.tryParse(_dia.text);
  int? get _glucoseVal => int.tryParse(_glucose.text);
  int? get _cholesterolVal => int.tryParse(_cholesterol.text);

  int? get _bpPoints {
    final s = _sysVal, d = _diaVal;
    if (s == null || d == null) return null;
    if (s < 120 && d < 80) return 0;
    if (s < 140 && d < 90) return 1;
    return 2;
  }

  int? get _glucosePoints {
    final g = _glucoseVal;
    if (g == null) return null;
    if (g < 100) return 0;
    if (g < 126) return 1;
    return 2;
  }

  int? get _cholesterolPoints {
    final c = _cholesterolVal;
    if (c == null) return null;
    if (c < 200) return 0;
    if (c < 240) return 1;
    return 2;
  }

  Future<void> _submit() async {
    if ((_sys.text.isNotEmpty) != (_dia.text.isNotEmpty)) {
      return toast(context, 'Enter both systolic and diastolic, or leave both blank.', error: true);
    }
    final factors = _factors;
    final score = factors.fold<int>(0, (a, f) => a + f.points);
    final maxPossible = 3 + 1 + (_bmi != null ? 2 : 0) + 2 + 2 + 2 + 2 + 2 + (_bpPoints != null ? 2 : 0) + (_glucosePoints != null ? 2 : 0) + (_cholesterolPoints != null ? 2 : 0);
    final pct = maxPossible == 0 ? 0.0 : score / maxPossible;
    final category = pct < 0.35 ? 'low' : (pct < 0.6 ? 'moderate' : 'high');

    try {
      await Repo.saveToolResult('cvd', score: score, category: category, data: {
        'max': maxPossible,
        'age': _age,
        'sex': _sex,
        'height_cm': _heightCm,
        'weight_kg': _weightKg,
        'bmi': _bmi == null ? null : double.parse(_bmi!.toStringAsFixed(1)),
        'smoking': _smoking,
        'activity': _activity,
        'family_history': _familyHistory,
        'diabetes': _diabetes,
        'hypertension': _hypertension,
        'systolic': _sysVal,
        'diastolic': _diaVal,
        'glucose': _glucoseVal,
        'cholesterol': _cholesterolVal,
        'factors': {for (final f in factors) f.key: f.points},
      });
      final rows = await Repo.toolResults('cvd', limit: 1);
      setState(() {
        _result = rows.first;
        _editing = false;
      });
    } catch (_) {
      if (mounted) toast(context, 'Could not save your check. Please try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: TitleHeader('CVD risk indicator', onLeading: () => goBack(context, '/tools')),
      children: _loading ? [const Loading()] : (_editing ? _form() : _resultView()),
    );
  }

  Widget _section(String title, Widget child, {String? note}) => VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: T.headlineSm),
          if (note != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(note, style: T.bodySm.c(AppColors.onSurfaceVariant))),
          const SizedBox(height: 12),
          child,
        ]),
      );

  // ---------------------------------------------------------------------------
  List<Widget> _form() {
    Widget choice(String title, String value, List<(String, String)> opts, ValueChanged<String> onPick) => _section(
          title,
          Wrap(spacing: 8, runSpacing: 8, children: [for (final o in opts) VChip(o.$2, selected: value == o.$1, selectedColor: AppColors.heart, onTap: () => setState(() => onPick(o.$1)))]),
        );

    return [
      Text('A cardiovascular risk factor check. We pre-fill what we can from your profile — change anything that is out of date.', style: T.bodyLg.c(AppColors.onSurfaceVariant)),
      const ToolSubBar(),
      choice('Age', _age, const [('under-30', 'Under 30'), ('30-45', '30–45'), ('46-60', '46–60'), ('over-60', 'Over 60')], (v) => _age = v),
      choice('Sex', _sex, const [('female', 'Female'), ('male', 'Male')], (v) => _sex = v),
      _section(
        'Height and weight',
        note: _bmi == null ? null : 'BMI ${_bmi!.toStringAsFixed(1)}',
        Row(children: [
          Expanded(child: VTextField(controller: _heightCtrl, hint: 'Height (cm)', keyboard: TextInputType.number, onChanged: (v) => setState(() => _heightCm = double.tryParse(v) ?? _heightCm))),
          const SizedBox(width: Sp.sm),
          Expanded(child: VTextField(controller: _weightCtrl, hint: 'Weight (kg)', keyboard: TextInputType.number, onChanged: (v) => setState(() => _weightKg = double.tryParse(v) ?? _weightKg))),
        ]),
      ),
      choice('Smoking habit', _smoking, const [('never', 'Never smoked'), ('occasional', 'Occasionally'), ('daily', 'Daily smoker')], (v) => _smoking = v),
      choice('Physical activity', _activity, const [('active', 'Active, 3+ times a week'), ('rarely', 'Rarely active'), ('inactive', 'Not active at all')], (v) => _activity = v),
      _section(
        'Family history',
        note: 'Do your parents or siblings have a history of heart attacks or stroke?',
        Wrap(spacing: 8, runSpacing: 8, children: [VChip('Yes', selected: _familyHistory, selectedColor: AppColors.heart, onTap: () => setState(() => _familyHistory = !_familyHistory))]),
      ),
      _section(
        'Existing conditions',
        Wrap(spacing: 8, runSpacing: 8, children: [
          VChip('Diabetes', selected: _diabetes, selectedColor: AppColors.heart, onTap: () => setState(() => _diabetes = !_diabetes)),
          VChip('Hypertension (high BP)', selected: _hypertension, selectedColor: AppColors.heart, onTap: () => setState(() => _hypertension = !_hypertension)),
        ]),
      ),
      _section(
        'Blood pressure (optional)',
        note: 'In mmHg, for example 116 / 74',
        Row(children: [
          Expanded(child: VTextField(controller: _sys, hint: 'Systolic', keyboard: TextInputType.number)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('/', style: T.headlineMd.c(AppColors.outline))),
          Expanded(child: VTextField(controller: _dia, hint: 'Diastolic', keyboard: TextInputType.number)),
        ]),
      ),
      _section('Fasting blood sugar (optional)', note: 'In mg/dL, from a recent lab test', VTextField(controller: _glucose, hint: 'mg/dL', keyboard: TextInputType.number)),
      _section('Total cholesterol (optional)', note: 'In mg/dL, from a recent lab test', VTextField(controller: _cholesterol, hint: 'mg/dL', keyboard: TextInputType.number)),
      PrimaryButton('See my result', onTap: _submit),
      if (_result != null) Center(child: TextLinkButton('Cancel', color: AppColors.onSurfaceVariant, onTap: () => setState(() => _editing = false))),
      const PrivacyNote('A risk factor estimate, not a diagnosis of heart disease or any other condition.'),
    ];
  }

  // ---------------------------------------------------------------------------
  List<Widget> _resultView() {
    final r = _result!;
    final score = (r['score'] as num).round();
    final max = (r['data']?['max'] as num?)?.toInt() ?? 20;
    final d = Map<String, dynamic>.from(r['data'] ?? {});
    final cat = r['category'] as String? ?? 'low';
    final (title, color) = switch (cat) {
      'low' => ('Low', AppColors.tertiary),
      'moderate' => ('Moderate', AppColors.warning),
      _ => ('High', AppColors.error),
    };
    final factorData = Map<String, dynamic>.from(d['factors'] ?? {});

    return [
      VCard(
        child: Column(children: [
          Ring(
            value: max == 0 ? 0 : score / max,
            size: 150,
            stroke: 12,
            color: color,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$score', style: T.metric(40)),
              Text('of $max', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: Sp.md),
          Text('$title risk', style: T.headlineMd.c(color)),
          const SizedBox(height: 6),
          Text(
            'This reflects the risk factors you entered — not a 10-year clinical risk estimate. It does not rule out risk, even at the low end, and it is not a diagnosis.',
            textAlign: TextAlign.center,
            style: T.bodyMd.c(AppColors.onSurfaceVariant),
          ),
        ]),
      ),
      const SectionHeader('Contributing factors'),
      ListGroup(children: [
        for (final e in factorData.entries)
          ListRow(
            icon: _factorIcon(e.key),
            color: AppColors.heart,
            title: _factorLabel(e.key),
            trailing: Text(_pointsLabel(e.value as int), style: T.labelMd.c(e.value == 0 ? AppColors.tertiary : (e.value == 1 ? AppColors.warning : AppColors.error))),
          ),
      ]),
      const SectionHeader('What you can do'),
      VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final tip in _recommendations(factorData, d))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 7), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: AppColors.heart, shape: BoxShape.circle))),
                const SizedBox(width: 10),
                Expanded(child: Text(tip, style: T.bodyMd.c(AppColors.onSurfaceVariant))),
              ]),
            ),
        ]),
      ),
      ListGroup(children: [
        ListRow(icon: Symbols.stethoscope_rounded, color: AppColors.primary, title: 'Talk to a professional', onTap: () => context.push('/professionals')),
        ListRow(icon: Symbols.refresh_rounded, color: AppColors.onSurfaceVariant, title: 'Retake the check', onTap: () => setState(() => _editing = true)),
      ]),
      PrivacyNote('Checked ${DateFormat('d MMM yyyy').format(DateTime.parse(r['created_at']).toLocal())}. A risk factor estimate, not a diagnosis. Only you can see this.'),
    ];
  }

  String _pointsLabel(int p) => p == 0 ? 'Not a factor' : (p == 1 ? 'Some risk' : 'Higher risk');

  String _factorLabel(String k) => switch (k) {
        'age' => 'Age',
        'sex' => 'Sex',
        'bmi' => 'Body mass index',
        'smoking' => 'Smoking',
        'activity' => 'Physical activity',
        'family' => 'Family history',
        'diabetes' => 'Diabetes',
        'hypertension' => 'High blood pressure',
        'bp' => 'Blood pressure',
        'glucose' => 'Fasting blood sugar',
        'cholesterol' => 'Total cholesterol',
        _ => k,
      };

  IconData _factorIcon(String k) => switch (k) {
        'age' => Symbols.cake_rounded,
        'sex' => Symbols.wc_rounded,
        'bmi' => Symbols.monitor_weight_rounded,
        'smoking' => Symbols.smoking_rooms_rounded,
        'activity' => Symbols.directions_walk_rounded,
        'family' => Symbols.diversity_1_rounded,
        'diabetes' => Symbols.bloodtype_rounded,
        'hypertension' => Symbols.blood_pressure_rounded,
        'bp' => Symbols.blood_pressure_rounded,
        'glucose' => Symbols.bloodtype_rounded,
        'cholesterol' => Symbols.science_rounded,
        _ => Symbols.favorite_rounded,
      };

  /// Always offered, regardless of risk level — a low score narrows risk, it
  /// never rules it out.
  List<String> _recommendations(Map<String, dynamic> factors, Map<String, dynamic> d) {
    final tips = <String>[];
    if ((factors['smoking'] ?? 0) > 0) tips.add('Avoiding smoking and vaping is one of the most powerful things you can do for your heart.');
    if ((factors['activity'] ?? 0) > 0) tips.add('Aim for at least 150 minutes of moderate activity a week; brisk walking between classes counts.');
    if ((factors['bmi'] ?? 0) > 0) tips.add('A gradual move toward a healthy weight, through diet and activity, eases strain on the heart.');
    if ((factors['bp'] ?? 0) > 0 || d['hypertension'] == true) tips.add('Less salt, regular activity and good sleep help keep blood pressure in a healthy range.');
    if ((factors['glucose'] ?? 0) > 0 || d['diabetes'] == true) tips.add('Favour whole grains and pulses over refined carbs and sugary drinks to support steady blood sugar.');
    if ((factors['cholesterol'] ?? 0) > 0) tips.add('Oily fish, nuts and olive oil in place of fried food and ghee can help improve cholesterol over time.');
    if ((factors['family'] ?? 0) > 0) tips.add('With a family history, regular blood pressure, sugar and cholesterol checks are worthwhile even without symptoms.');
    if (tips.isEmpty) tips.add('Your current habits support heart health. Keep walking, sleeping well and eating a varied diet — regular check-ups still matter.');
    tips.add('This tool estimates risk from the factors you entered; it cannot see everything about your health, so a normal result does not guarantee you are risk-free.');
    return tips;
  }
}
