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
      header: const TitleHeader('Heart Health Check'),
      backgroundDecoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFEEF7FF), AppColors.surface, AppColors.surface]),
      ),
      background: Colors.transparent,
      children: _loading ? [const Loading()] : (_editing ? _form() : _resultView()),
    );
  }

  // ---------------------------------------------------------------------------
  List<Widget> _form() {
    Widget choice(String title, IconData icon, String value, List<(String, String)> opts, ValueChanged<String> onPick) => VCard(
          shadow: Shadows.soft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [IconCircle(icon, size: 36, iconSize: 20, bg: AppColors.surfaceContainer), const SizedBox(width: 10), Expanded(child: Text(title, style: T.labelLg))]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [for (final o in opts) VChip(o.$2, selected: value == o.$1, selectedColor: AppColors.secondary, onTap: () => setState(() => onPick(o.$1)))]),
          ]),
        );

    return [
      const Padding(padding: EdgeInsets.only(top: Sp.sm), child: ToolSubBar(label: 'Confidential • Heart Check', icon: Symbols.lock)),
      VCard(
        clip: true,
        shadow: Shadows.card,
        child: Row(children: [
          const AssetImg('heart_pulse', width: 72, height: 72, radius: 20),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('A 60-second heart check', style: T.headlineSm),
              const SizedBox(height: 2),
              Text('Answer a few lifestyle questions. We combine them with your BMI and family history to show your heart-health profile.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
      VCard(
        shadow: Shadows.soft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconCircle(Symbols.monitor_heart, size: 36, iconSize: 20, bg: AppColors.surfaceContainer),
            const SizedBox(width: 10),
            Expanded(child: Text('Recent blood pressure', style: T.labelLg)),
          ]),
          const SizedBox(height: 12),
          if (!_bpUnknown)
            Row(children: [
              Expanded(child: VTextField(controller: _sys, hint: 'Systolic e.g. 116', keyboard: TextInputType.number)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('/', style: T.headlineMd.c(AppColors.outline))),
              Expanded(child: VTextField(controller: _dia, hint: 'Diastolic e.g. 74', keyboard: TextInputType.number)),
            ]),
          const SizedBox(height: 8),
          Row(children: [
            Switch(value: _bpUnknown, activeThumbColor: AppColors.secondary, onChanged: (v) => setState(() => _bpUnknown = v)),
            const SizedBox(width: 6),
            Expanded(child: Text("I don't know my blood pressure", style: T.bodySm.c(AppColors.onSurfaceVariant))),
          ]),
        ]),
      ),
      VCard(
        shadow: Shadows.soft,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const IconCircle(Symbols.diversity_1, size: 36, iconSize: 20, bg: AppColors.surfaceContainer, fg: AppColors.secondary),
            const SizedBox(width: 10),
            Expanded(child: Text('Family history (parents or siblings)', style: T.labelLg)),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            VChip('Heart disease / stroke', selected: _familyHeart, selectedColor: AppColors.secondary, onTap: () => setState(() => _familyHeart = !_familyHeart)),
            VChip('High blood pressure', selected: _familyBp, selectedColor: AppColors.secondary, onTap: () => setState(() => _familyBp = !_familyBp)),
            VChip('Diabetes', selected: _familyDiabetes, selectedColor: AppColors.secondary, onTap: () => setState(() => _familyDiabetes = !_familyDiabetes)),
          ]),
        ]),
      ),
      choice('Smoking or vaping', Symbols.smoke_free, _tobacco, const [('never', 'Never'), ('former', 'Quit'), ('occasional', 'Occasionally'), ('daily', 'Daily')], (v) => _tobacco = v),
      choice(
          'Moderate activity per week${_avgSteps != null ? ' (you average ${Fmt.thousands(_avgSteps!)} steps/day)' : ''}',
          Symbols.directions_walk,
          _activity,
          const [('150+', '150+ min'), ('90-149', '90–149 min'), ('30-89', '30–89 min'), ('<30', '< 30 min')],
          (v) => _activity = v),
      choice('Fruit & vegetable servings per day', Symbols.nutrition, _fruitVeg, const [('5+', '5+'), ('4', '4'), ('2-3', '2–3'), ('0-1', '0–1')], (v) => _fruitVeg = v),
      choice('Typical sleep per night', Symbols.bedtime, _sleep, const [('<6', '< 6 h'), ('6', '6 h'), ('7-8', '7–8 h'), ('9+', '9+ h')], (v) => _sleep = v),
      if (AppState.instance.profile?.bmi == null)
        VCard(
          color: AppColors.surfaceContainerLow,
          onTap: () => context.push('/tools/bmi'),
          child: Row(children: [
            const Icon(Symbols.info, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text('Add your height & weight (BMI tool) for a more personal result.', style: T.bodySm.c(AppColors.onSurfaceVariant))),
            const Icon(Symbols.chevron_right, size: 18),
          ]),
        ),
      PrimaryButton('See My Heart Profile', leadingIcon: Symbols.auto_awesome, color: AppColors.onSurface, height: 52, onTap: _submit),
      if (_result != null) Center(child: TextLinkButton('Cancel', onTap: () => setState(() => _editing = false))),
      const PrivacyNote('This is an educational lifestyle check, not a medical diagnosis.'),
    ];
  }

  // ---------------------------------------------------------------------------
  List<Widget> _resultView() {
    final r = _result!;
    final score = (r['score'] as num).round();
    final d = Map<String, dynamic>.from(r['data'] ?? {});
    final cat = r['category'] as String? ?? 'low';
    final (title, badge, summary, badgeColor) = switch (cat) {
      'low' => (
          'Low Risk • Restful Rhythm',
          'Optimal Pace',
          'Your heart-health habits sit in a gentle, resilient zone. Everyday routines like walking between lectures and regular hydration keep your heart smiling.',
          AppColors.tertiary
        ),
      'moderate' => (
          'Moderate • Gentle Watch',
          'Steady Pace',
          'A good foundation with a few areas to nurture. Small, consistent changes in activity, meals or sleep can lift your score over the semester.',
          AppColors.primary
        ),
      _ => (
          'Elevated • Check-in Suggested',
          'Extra Care',
          'Several factors could be putting extra load on your heart. This is not a diagnosis — a campus doctor can check your blood pressure and guide next steps.',
          AppColors.secondary
        ),
    };
    final famCount = (d['family_count'] as num?)?.toInt() ?? 0;
    final bpLabel = d['bp_label'] as String? ?? 'Unknown';
    final actLabel = {'150+': 'Balanced', '90-149': 'Good', '30-89': 'Building', '<30': 'Low'}[d['activity']] ?? '—';
    final healthy = [bpLabel == 'Optimal', famCount == 0, d['activity'] == '150+' || d['activity'] == '90-149'].where((e) => e).length;

    Widget factor(IconData icon, Color c, String label, String value, String status, bool ok) => Expanded(
          child: VCard(
            radius: Rad.base,
            padding: const EdgeInsets.all(12),
            shadow: Shadows.tiny,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconCircle(icon, size: 32, iconSize: 18, bg: AppColors.surfaceContainer, fg: c),
              const SizedBox(height: 8),
              Text(label, style: T.labelSm.c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(value, style: T.labelMd, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: ok ? AppColors.tertiary : AppColors.secondary, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Flexible(child: Text(status, style: T.labelSm.c(ok ? AppColors.tertiary : AppColors.secondary), overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),
        );

    return [
      Padding(
        padding: const EdgeInsets.only(top: Sp.sm),
        child: Row(children: [
          TagPill('Confidential', icon: Symbols.lock, iconColor: AppColors.tertiary, bg: AppColors.surfaceContainerLow),
          const Spacer(),
          const Icon(Symbols.verified, size: 16, color: AppColors.secondary),
          const SizedBox(width: 4),
          Text('Young-Adult Baseline', style: T.labelSm.c(AppColors.onSurfaceVariant.withValues(alpha: 0.8))),
        ]),
      ),
      VCard(
        padding: const EdgeInsets.all(Sp.lg),
        clip: true,
        shadow: Shadows.card,
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(top: -60, right: -60, child: Glow(color: AppColors.secondaryFixed.withValues(alpha: 0.4), size: 192)),
          Positioned(bottom: -50, left: -50, child: Glow(color: AppColors.primaryFixed.withValues(alpha: 0.3), size: 176)),
          Column(children: [
            SizedBox(
              width: 224,
              height: 236,
              child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                Positioned(top: 0, child: SizedBox(width: 224, height: 224, child: CustomPaint(painter: _HeartGauge(score / 100)))),
                Positioned(top: 32, child: ClipOval(child: const AssetImg('heart_pulse', width: 160, height: 160))),
                Positioned(
                  bottom: 0,
                  child: Pill(
                    color: AppColors.surfaceContainerLowest,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    shadow: Shadows.soft,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(badge, style: T.labelMd.c(badgeColor)),
                    ]),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: Sp.sm),
            Text(title, style: T.headlineMd, textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text('Heart Health Score $score / 100', style: T.labelMd.c(AppColors.primary)),
            const SizedBox(height: Sp.xs),
            Container(
              padding: const EdgeInsets.all(Sp.sm),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.base)),
              child: Text(summary, textAlign: TextAlign.center, style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Contributing Factors', style: T.headlineSm),
                Text('Self-reported student profile', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
            TagPill('$healthy / 3 Healthy', fg: AppColors.tertiary),
          ]),
        ),
        const SizedBox(height: Sp.sm),
        Row(children: [
          factor(Symbols.favorite, AppColors.primary, 'Pressure', d['bp'] ?? '—', bpLabel, bpLabel == 'Optimal'),
          const SizedBox(width: 10),
          factor(Symbols.diversity_1, AppColors.secondary, 'Genetics', famCount == 0 ? 'Clear' : '$famCount noted', famCount == 0 ? 'Low Risk' : 'Be aware', famCount == 0),
          const SizedBox(width: 10),
          factor(Symbols.directions_walk, AppColors.tertiary, 'Activity', d['avg_steps'] != null ? '~${Fmt.k(d['avg_steps'])} /day' : '${d['activity']} min/wk', actLabel,
              d['activity'] == '150+' || d['activity'] == '90-149'),
        ]),
      ]),
      VCard(
        color: AppColors.surfaceContainer,
        shadow: Shadows.tiny,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconCircle(Symbols.spa, size: 40, iconSize: 20, shadow: Shadows.tiny),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Understanding your university rhythm', style: T.headlineSm),
              const SizedBox(height: 4),
              Text('Clinical 10-year risk calculators are built for adults over 40. At university, heart vitality is shaped by daily pacing: restful sleep, mindful study breaks, balanced meals and moving without burnout.',
                  style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 4),
      PrimaryButton('Learn What This Means', leadingIcon: Symbols.auto_awesome, color: AppColors.onSurface, fg: AppColors.surfaceContainerLowest, height: 52, onTap: () => _explain(d, score)),
      Pressable(
        onTap: () => context.push('/professionals'),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: Sp.md),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(Rad.full), boxShadow: Shadows.tiny),
          child: Row(children: [
            const Icon(Symbols.support_agent, size: 20, color: AppColors.secondary),
            const SizedBox(width: 10),
            Expanded(child: Text('Talk to a Campus Wellness Counselor', style: T.labelMd, overflow: TextOverflow.ellipsis)),
            const Icon(Symbols.arrow_forward_ios, size: 16, color: AppColors.onSurfaceVariant),
          ]),
        ),
      ),
      Center(child: TextLinkButton('Retake heart check', leading: Symbols.refresh, color: AppColors.primary, onTap: () => setState(() => _editing = true))),
      Text('Checked ${DateFormat('d MMM yyyy').format(DateTime.parse(r['created_at']).toLocal())}. Private to you — university medical staff only see check-ins if you choose to share during an appointment.',
          textAlign: TextAlign.center, style: T.labelSm.c(AppColors.outline).lh(1.35)),
    ];
  }

  void _explain(Map<String, dynamic> d, int score) {
    final pts = Map<String, dynamic>.from(d['points'] ?? {});
    String tip(String k) => switch (k) {
          'bp' => 'Blood pressure below 120/80 is ideal. Less salt, regular activity and good sleep help keep it there.',
          'activity' => 'Aim for at least 150 minutes of moderate activity a week — brisk walking between classes counts.',
          'tobacco' => 'Avoiding smoking and vaping is one of the most powerful things you can do for your heart.',
          'diet' => 'Fill half your plate with vegetables and fruit; choose whole grains, pulses and fish.',
          'sleep' => '7–9 hours of sleep supports healthy blood pressure and metabolism.',
          _ => 'A healthy weight and waist size reduce strain on the heart.',
        };
    final names = {'bp': 'Blood pressure', 'activity': 'Physical activity', 'tobacco': 'Tobacco & vaping', 'diet': 'Fruit & vegetables', 'sleep': 'Sleep', 'bmi': 'Body weight (BMI)'};
    showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Your heart-health breakdown', style: T.headlineMd),
          const SizedBox(height: 4),
          Text('Score $score/100 • higher is better', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          for (final k in names.keys)
            if (pts[k] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [Expanded(child: Text(names[k]!, style: T.labelLg)), Text('${pts[k]}', style: T.labelLg.c(AppColors.primary))]),
                  const SizedBox(height: 6),
                  Bar(value: (pts[k] as num) / 100, color: (pts[k] as num) >= 80 ? AppColors.tertiaryContainer : ((pts[k] as num) >= 50 ? AppColors.primaryContainer : AppColors.secondary)),
                  const SizedBox(height: 4),
                  Text(tip(k), style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
          if ((d['family_count'] ?? 0) > 0)
            Text('Family history can raise lifetime risk, so regular blood pressure, sugar and cholesterol checks are worthwhile.', style: T.bodySm.c(AppColors.secondary)),
          const SizedBox(height: Sp.md),
          PrimaryButton('Read: Heart Health Starts at University', onTap: () {
            Navigator.pop(ctx);
            context.push('/library/article/heart-health-basics');
          }),
        ]));
  }
}

class _HeartGauge extends CustomPainter {
  _HeartGauge(this.v);
  final double v;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 12;
    final rect = Rect.fromCircle(center: c, radius: r);
    const start = -math.pi / 2;
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = const Color(0xFFEBE6F7));
    final value = v.clamp(0.02, 1.0);
    canvas.drawArc(rect, start, 2 * math.pi * value * 0.72, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round
      ..color = AppColors.tertiaryContainer);
    canvas.drawArc(rect, start + 2 * math.pi * 0.74, 2 * math.pi * 0.14, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = AppColors.secondaryFixed);
    canvas.drawArc(rect, start + 2 * math.pi * 0.9, 2 * math.pi * 0.08, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = AppColors.secondaryFixedDim);
  }

  @override
  bool shouldRepaint(covariant _HeartGauge old) => old.v != v;
}
