import 'dart:math' as math;

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

/// Heart-health check for young adults, inspired by the AHA "Life's Essential 8"
/// scoring. Validated 10-year CVD risk models are designed for people aged 40+,
/// so for undergraduates we score modifiable heart-health factors (0–100).
class HeartRiskScreen extends StatefulWidget {
  const HeartRiskScreen({super.key});
  @override
  State<HeartRiskScreen> createState() => _HeartRiskScreenState();
}

class _HeartRiskScreenState extends State<HeartRiskScreen> {
  bool _loading = true;
  Rec? _result;
  bool _editing = false;

  // Inputs
  final _sys = TextEditingController();
  final _dia = TextEditingController();
  bool _bpUnknown = false;
  bool _familyHeart = false;
  bool _familyBp = false;
  bool _familyDiabetes = false;
  String _tobacco = 'never';
  String _activity = '150+';
  String _fruitVeg = '2-3';
  String _sleep = '7-8';
  int? _avgSteps;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = AppState.instance.profile;
    _familyHeart = p?.conditions.contains('family_heart') ?? false;
    _familyBp = p?.conditions.contains('family_hypertension') ?? false;
    _familyDiabetes = p?.conditions.contains('family_diabetes') ?? false;
    try {
      final rows = await Repo.toolResults('cvd', limit: 1);
      if (rows.isNotEmpty) _result = rows.first;
      final now = DateTime.now();
      final steps = await Repo.stepsByDay(now.subtract(const Duration(days: 6)), now);
      if (steps.isNotEmpty) _avgSteps = (steps.values.reduce((a, b) => a + b) / 7).round();
    } catch (_) {}
    _editing = _result == null;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    final sys = int.tryParse(_sys.text);
    final dia = int.tryParse(_dia.text);
    if (!_bpUnknown && (sys == null || dia == null || sys < 70 || sys > 230 || dia < 40 || dia > 140)) {
      return toast(context, "Enter a valid blood pressure or choose \"I don't know\".", error: true);
    }
    final p = AppState.instance.profile;
    final bmi = p?.bmi;
    final s = sys ?? 0, dd = dia ?? 0;

    // --- Points (each 0..100) ---
    int bpPts;
    String bpLabel;
    if (_bpUnknown) {
      bpPts = 70;
      bpLabel = 'Unknown';
    } else if (s < 120 && dd < 80) {
      bpPts = 100;
      bpLabel = 'Optimal';
    } else if (s < 130 && dd < 80) {
      bpPts = 75;
      bpLabel = 'Elevated';
    } else if (s < 140 && dd < 90) {
      bpPts = 50;
      bpLabel = 'Stage 1';
    } else {
      bpPts = 20;
      bpLabel = 'High';
    }
    final actPts = {'150+': 100, '90-149': 80, '30-89': 50, '<30': 20}[_activity]!;
    final tobPts = {'never': 100, 'former': 75, 'occasional': 25, 'daily': 0}[_tobacco]!;
    final dietPts = {'5+': 100, '4': 80, '2-3': 50, '0-1': 25}[_fruitVeg]!;
    final sleepPts = {'7-8': 100, '9+': 90, '6': 70, '<6': 40}[_sleep]!;
    int bmiPts = 80;
    if (bmi != null) {
      bmiPts = bmi < 18.5 ? 80 : bmi < 23 ? 100 : bmi < 25 ? 85 : bmi < 30 ? 60 : 30;
    }
    final famCount = [_familyHeart, _familyBp, _familyDiabetes].where((e) => e).length;
    final avg = (bpPts + actPts + tobPts + dietPts + sleepPts + bmiPts) / 6;
    final score = math.max(0, (avg - famCount * 5)).round();
    final category = score >= 80 ? 'low' : (score >= 50 ? 'moderate' : 'elevated');

    try {
      await Repo.saveToolResult('cvd', score: score, category: category, data: {
        'bp': _bpUnknown ? null : '$sys/$dia',
        'bp_label': bpLabel,
        'family_count': famCount,
        'family_heart': _familyHeart,
        'family_bp': _familyBp,
        'family_diabetes': _familyDiabetes,
        'tobacco': _tobacco,
        'activity': _activity,
        'avg_steps': _avgSteps,
        'fruit_veg': _fruitVeg,
        'sleep': _sleep,
        'bmi': bmi == null ? null : double.parse(bmi.toStringAsFixed(1)),
        'points': {'bp': bpPts, 'activity': actPts, 'tobacco': tobPts, 'diet': dietPts, 'sleep': sleepPts, 'bmi': bmiPts},
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
      header: TitleHeader('Heart risk', onLeading: () => goBack(context, '/tools')),
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
    Widget choice(String title, String value, List<(String, String)> opts, ValueChanged<String> onPick, {String? note}) => _section(
          title,
          Wrap(spacing: 8, runSpacing: 8, children: [for (final o in opts) VChip(o.$2, selected: value == o.$1, selectedColor: AppColors.heart, onTap: () => setState(() => onPick(o.$1)))]),
          note: note,
        );

    return [
      Text('Answer a few questions. We combine them with your BMI and family history into a heart-health score out of 100.', style: T.bodyLg.c(AppColors.onSurfaceVariant)),
      const ToolSubBar(),
      _section(
        'Recent blood pressure',
        note: 'In mmHg, for example 116 / 74',
        Column(children: [
          if (!_bpUnknown)
            Row(children: [
              Expanded(child: VTextField(controller: _sys, hint: 'Systolic', keyboard: TextInputType.number)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('/', style: T.headlineMd.c(AppColors.outline))),
              Expanded(child: VTextField(controller: _dia, hint: 'Diastolic', keyboard: TextInputType.number)),
            ]),
          SwitchListTile(
            value: _bpUnknown,
            onChanged: (v) => setState(() => _bpUnknown = v),
            contentPadding: EdgeInsets.zero,
            title: Text("I don't know my blood pressure", style: T.bodyLg),
          ),
        ]),
      ),
      _section(
        'Family history',
        Wrap(spacing: 8, runSpacing: 8, children: [
          VChip('Heart disease or stroke', selected: _familyHeart, selectedColor: AppColors.heart, onTap: () => setState(() => _familyHeart = !_familyHeart)),
          VChip('High blood pressure', selected: _familyBp, selectedColor: AppColors.heart, onTap: () => setState(() => _familyBp = !_familyBp)),
          VChip('Diabetes', selected: _familyDiabetes, selectedColor: AppColors.heart, onTap: () => setState(() => _familyDiabetes = !_familyDiabetes)),
        ]),
        note: 'Parents or siblings',
      ),
      choice('Smoking or vaping', _tobacco, const [('never', 'Never'), ('former', 'Quit'), ('occasional', 'Occasionally'), ('daily', 'Daily')], (v) => _tobacco = v),
      choice('Moderate activity per week', _activity, const [('150+', '150+ min'), ('90-149', '90–149 min'), ('30-89', '30–89 min'), ('<30', 'Under 30 min')], (v) => _activity = v,
          note: _avgSteps != null ? 'You average ${Fmt.thousands(_avgSteps!)} steps a day' : null),
      choice('Fruit and vegetable servings a day', _fruitVeg, const [('5+', '5+'), ('4', '4'), ('2-3', '2–3'), ('0-1', '0–1')], (v) => _fruitVeg = v),
      choice('Sleep per night', _sleep, const [('<6', 'Under 6 h'), ('6', '6 h'), ('7-8', '7–8 h'), ('9+', '9+ h')], (v) => _sleep = v),
      if (AppState.instance.profile?.bmi == null)
        ListGroup(children: [
          ListRow(icon: Symbols.monitor_weight_rounded, color: AppColors.body, title: 'Add height and weight', subtitle: 'For a more personal result', onTap: () => context.push('/tools/bmi')),
        ]),
      PrimaryButton('See my result', onTap: _submit),
      if (_result != null) Center(child: TextLinkButton('Cancel', color: AppColors.onSurfaceVariant, onTap: () => setState(() => _editing = false))),
      const PrivacyNote('An educational lifestyle check, not a medical diagnosis.'),
    ];
  }

  // ---------------------------------------------------------------------------
  List<Widget> _resultView() {
    final r = _result!;
    final score = (r['score'] as num).round();
    final d = Map<String, dynamic>.from(r['data'] ?? {});
    final cat = r['category'] as String? ?? 'low';
    final (title, summary, color) = switch (cat) {
      'low' => ('Low risk', 'Your heart-health habits are in a strong place. Keep walking, sleeping well and staying hydrated.', AppColors.tertiary),
      'moderate' => ('Moderate', 'A good foundation with a few areas to work on. Small, steady changes in activity, meals or sleep can lift your score over a semester.', AppColors.warning),
      _ => ('Elevated', 'Several factors could be putting extra load on your heart. This is not a diagnosis; a campus doctor can check your blood pressure and advise.', AppColors.error),
    };
    final famCount = (d['family_count'] as num?)?.toInt() ?? 0;
    final bpLabel = d['bp_label'] as String? ?? 'Unknown';
    final activeOk = d['activity'] == '150+' || d['activity'] == '90-149';
    final actLabel = {'150+': 'Great', '90-149': 'Good', '30-89': 'Building', '<30': 'Low'}[d['activity']] ?? '—';

    Widget status(String text, bool ok) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ok ? Symbols.check_circle_rounded : Symbols.error_rounded, size: 16, color: ok ? AppColors.tertiary : AppColors.warning, fill: 1),
          const SizedBox(width: 4),
          Text(text, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ]);

    return [
      VCard(
        child: Column(children: [
          Ring(
            value: score / 100,
            size: 150,
            stroke: 12,
            color: color,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$score', style: T.metric(44)),
              Text('of 100', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: Sp.md),
          Text(title, style: T.headlineMd.c(color)),
          const SizedBox(height: 6),
          Text(summary, textAlign: TextAlign.center, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ]),
      ),
      const SectionHeader('Contributing factors'),
      ListGroup(children: [
        ListRow(icon: Symbols.blood_pressure_rounded, color: AppColors.heart, title: 'Blood pressure', subtitle: d['bp'] ?? 'Not entered', trailing: status(bpLabel, bpLabel == 'Optimal')),
        ListRow(icon: Symbols.diversity_1_rounded, color: AppColors.heart, title: 'Family history', subtitle: famCount == 0 ? 'None noted' : '$famCount noted', trailing: status(famCount == 0 ? 'Clear' : 'Be aware', famCount == 0)),
        ListRow(
          icon: Symbols.directions_walk_rounded,
          color: AppColors.activity,
          title: 'Activity',
          subtitle: d['avg_steps'] != null ? 'About ${Fmt.k(d['avg_steps'])} steps a day' : '${d['activity']} min a week',
          trailing: status(actLabel, activeOk),
        ),
      ]),
      ListGroup(children: [
        ListRow(icon: Symbols.bar_chart_rounded, color: AppColors.heart, title: 'See full breakdown', onTap: () => _explain(d, score)),
        ListRow(icon: Symbols.stethoscope_rounded, color: AppColors.primary, title: 'Talk to a professional', onTap: () => context.push('/professionals')),
        ListRow(icon: Symbols.refresh_rounded, color: AppColors.onSurfaceVariant, title: 'Retake the check', onTap: () => setState(() => _editing = true)),
      ]),
      VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Why a score and not a 10-year risk?', style: T.headlineSm),
          const SizedBox(height: 4),
          Text('Clinical 10-year risk calculators are built for adults over 40. For students, the habits that shape heart health (sleep, movement, food, not smoking) are the useful thing to track.',
              style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ]),
      ),
      PrivacyNote('Checked ${DateFormat('d MMM yyyy').format(DateTime.parse(r['created_at']).toLocal())}. Only you can see this.'),
    ];
  }

  void _explain(Map<String, dynamic> d, int score) {
    final pts = Map<String, dynamic>.from(d['points'] ?? {});
    String tip(String k) => switch (k) {
          'bp' => 'Below 120/80 is ideal. Less salt, regular activity and good sleep help keep it there.',
          'activity' => 'Aim for at least 150 minutes of moderate activity a week. Brisk walking between classes counts.',
          'tobacco' => 'Avoiding smoking and vaping is one of the most powerful things you can do for your heart.',
          'diet' => 'Fill half your plate with vegetables and fruit; choose whole grains, pulses and fish.',
          'sleep' => '7 to 9 hours of sleep supports healthy blood pressure and metabolism.',
          _ => 'A healthy weight and waist size reduce strain on the heart.',
        };
    final names = {'bp': 'Blood pressure', 'activity': 'Physical activity', 'tobacco': 'Smoking and vaping', 'diet': 'Fruit and vegetables', 'sleep': 'Sleep', 'bmi': 'Body weight (BMI)'};
    showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Score breakdown', style: T.headlineMd),
          const SizedBox(height: 4),
          Text('$score out of 100. Higher is better.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.lg),
          for (final k in names.keys)
            if (pts[k] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text(names[k]!, style: T.labelLg.semi)), Text('${pts[k]}', style: T.labelLg.tnum.c(AppColors.onSurfaceVariant))]),
                  const SizedBox(height: 6),
                  Bar(value: (pts[k] as num) / 100, color: (pts[k] as num) >= 80 ? AppColors.tertiary : ((pts[k] as num) >= 50 ? AppColors.warning : AppColors.error)),
                  const SizedBox(height: 6),
                  Text(tip(k), style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
          if ((d['family_count'] ?? 0) > 0)
            Text('Family history can raise lifetime risk, so regular blood pressure, sugar and cholesterol checks are worthwhile.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          SoftButton('Read: Heart health starts at university', onTap: () {
            Navigator.pop(ctx);
            context.push('/library/article/heart-health-basics');
          }),
        ]));
  }
}
