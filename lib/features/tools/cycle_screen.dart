import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

class _Phase {
  const _Phase(this.name, this.badge, this.icon, this.text, this.insightTitle, this.insight);
  final String name;
  final String badge;
  final IconData icon;
  final String text;
  final String insightTitle;
  final String insight;
}

const _menstrual = _Phase('Menstrual', 'Menstrual', Symbols.water_drop_rounded, 'Energy may dip. Light movement, iron-rich meals and warm drinks can help.',
    'Protect your rest', 'Plan lighter study blocks, keep warm drinks nearby and include iron-rich foods like dhal, green leaves and fish to replenish.');
const _follicular = _Phase('Follicular', 'Follicular • Rising Energy', Symbols.eco_rounded, 'Energy is gradually rising. A great time to start new topics and build study momentum.',
    'Build momentum', 'Rising oestrogen often supports motivation. Start new modules or tough readings now and schedule active study sessions.');
const _ovulation = _Phase('Ovulation', 'Ovulation • Peak Energy Window', Symbols.wb_twilight_rounded, 'Hormones are gently peaking. Ideal for group study sessions, presentation prep, and creative flow.',
    'Use the energy', 'Many people feel most social and energetic now. Tackle presentations or group work, and prepare warm herbal teas for the restful phase ahead.');
const _luteal = _Phase('Luteal', 'Luteal • Restful Rhythm', Symbols.bedtime_rounded, 'Your body is winding down. Prioritise sleep, regular meals and kinder study pacing.',
    'Slow and steady', 'Cravings and mood shifts are common. Keep regular meals, reduce caffeine, and plan revision rather than new material.');

class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});
  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  bool _loading = true;
  List<Rec> _cycles = [];
  Rec? _today;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _cycles = await Repo.cycles();
      _today = await Repo.dailyLog(DateTime.now());
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<int> get _lengths {
    final starts = _cycles.map((c) => DateTime.parse(c['start_date'])).toList()..sort();
    return [for (int i = 1; i < starts.length; i++) starts[i].difference(starts[i - 1]).inDays];
  }

  int get _cycleLen {
    final l = _lengths.where((d) => d >= 18 && d <= 60).toList();
    if (l.isEmpty) return 28;
    return (l.reduce((a, b) => a + b) / l.length).round().clamp(21, 45);
  }

  int get _periodLen {
    final withEnd = _cycles.where((c) => c['end_date'] != null).toList();
    if (withEnd.isEmpty) return 5;
    final avg = withEnd.map((c) => DateTime.parse(c['end_date']).difference(DateTime.parse(c['start_date'])).inDays + 1).reduce((a, b) => a + b) / withEnd.length;
    return avg.round().clamp(2, 10);
  }

  bool get _irregular {
    final l = _lengths;
    if (l.length < 2) return false;
    final mx = l.reduce(math.max), mn = l.reduce(math.min);
    return l.any((d) => d > 35 || d < 21) || (mx - mn) > 7;
  }

  _Phase _phaseFor(int day) {
    final ov = _cycleLen - 14;
    if (day <= _periodLen) return _menstrual;
    if (day < ov - 2) return _follicular;
    if (day <= ov + 2) return _ovulation;
    return _luteal;
  }

  Future<void> _logPeriod() async {
    DateTime start = DateTime.now();
    String flow = _today?['flow'] ?? 'medium';
    final open = _cycles.isNotEmpty && _cycles.first['end_date'] == null && DateTime.now().difference(DateTime.parse(_cycles.first['start_date'])).inDays < 12;
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Log period', style: T.headlineMd),
            const SizedBox(height: Sp.md),
            if (open) ...[
              VCard(
                color: AppColors.surfaceContainer,
                child: Row(children: [
                  Icon(Symbols.water_drop_rounded, color: AppColors.cycle, fill: 1),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Period started ${DateFormat('d MMM').format(DateTime.parse(_cycles.first['start_date']))}. Has it ended?', style: T.bodyMd)),
                ]),
              ),
              const SizedBox(height: Sp.sm),
              SoftButton('Mark as ended today', icon: Symbols.check_circle_rounded, onTap: () async {
                await Repo.endCycle(_cycles.first['id'], DateTime.now());
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              }),
              const SizedBox(height: Sp.md),
              Text('Today\'s flow', style: T.labelLg),
            ] else ...[
              Text('Period start date', style: T.labelLg),
              const SizedBox(height: 8),
              VCard(
                color: AppColors.surfaceContainerLow,
                onTap: () async {
                  final d = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime.now().subtract(const Duration(days: 120)), lastDate: DateTime.now());
                  if (d != null) set(() => start = d);
                },
                child: Row(children: [
                  Icon(Symbols.calendar_today_rounded, color: AppColors.cycle),
                  const SizedBox(width: 10),
                  Expanded(child: Text(DateFormat('EEEE, d MMMM').format(start), style: T.labelLg)),
                  const Icon(Symbols.edit_rounded, size: 18),
                ]),
              ),
              const SizedBox(height: Sp.md),
              Text('Flow', style: T.labelLg),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final f in const ['spotting', 'light', 'medium', 'heavy'])
                VChip(f[0].toUpperCase() + f.substring(1), selected: flow == f, selectedColor: AppColors.cycle, onTap: () => set(() => flow = f)),
            ]),
            const SizedBox(height: Sp.lg),
            PrimaryButton(open ? 'Save' : 'Log period start', onTap: () async {
              if (!open) await Repo.addCycleStart(start);
              await Repo.upsertDailyLog(open ? DateTime.now() : start, {'flow': flow});
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]);
        }));
  }

  Future<void> _pickSymptom(String field, String title, List<String> options) async {
    final v = await showVSheet<String>(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: T.headlineMd),
          const SizedBox(height: Sp.md),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in options) VChip(o, selected: _today?[field] == o, selectedColor: AppColors.cycle, onTap: () => Navigator.pop(ctx, o)),
          ]),
          const SizedBox(height: Sp.md),
          if (_today?[field] != null) TextLinkButton('Clear', onTap: () => Navigator.pop(ctx, '')),
        ]));
    if (v == null) return;
    await Repo.upsertDailyLog(DateTime.now(), {field: v.isEmpty ? null : v});
    _load();
  }

  Future<void> _moreLog() async {
    bool spotting = _today?['spotting'] == true;
    final notes = TextEditingController(text: _today?['notes'] ?? '');
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('More for today', style: T.headlineMd),
            const SizedBox(height: Sp.sm),
            SwitchListTile(value: spotting, onChanged: (v) => set(() => spotting = v), title: Text('Spotting', style: T.labelLg), contentPadding: EdgeInsets.zero),
            const SizedBox(height: Sp.sm),
            VTextField(controller: notes, hint: 'Notes (headache, bloating, skin, cravings…)', maxLines: 3),
            const SizedBox(height: Sp.sm),
            SoftButton('Log water', icon: Symbols.water_drop_rounded, onTap: () {
              Navigator.pop(ctx);
              context.push('/tools/water');
            }),
            const SizedBox(height: Sp.md),
            PrimaryButton('Save', onTap: () async {
              await Repo.upsertDailyLog(DateTime.now(), {'spotting': spotting, 'notes': notes.text.trim().isEmpty ? null : notes.text.trim()});
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]);
        }));
  }

  void _history() {
    final starts = _cycles.map((c) => c).toList();
    showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Cycle history', style: T.headlineMd),
          const SizedBox(height: 4),
          Text('Average cycle $_cycleLen days · average period $_periodLen days', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          if (starts.isEmpty) Text('No cycles logged yet.', style: T.bodyMd),
          for (int i = 0; i < starts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VCard(
                color: AppColors.surfaceContainerLow,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Symbols.water_drop_rounded, color: AppColors.cycle, fill: 1, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(DateFormat('d MMM yyyy').format(DateTime.parse(starts[i]['start_date'])), style: T.labelLg)),
                  Text(
                    i + 1 < starts.length ? '${DateTime.parse(starts[i]['start_date']).difference(DateTime.parse(starts[i + 1]['start_date'])).inDays}-day cycle' : 'First logged',
                    style: T.labelSm.c(AppColors.onSurfaceVariant),
                  ),
                ]),
              ),
            ),
          if (_irregular) ...[
            const SizedBox(height: Sp.sm),
            Text('Your cycle lengths vary more than usual. Irregular cycles have many causes (stress, weight change, sleep), and can sometimes be associated with conditions such as PCOS. This is not a diagnosis; a doctor can help if it continues.',
                style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ],
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: TitleHeader('Cycle', onLeading: () => goBack(context, '/tools')),
      onRefresh: _load,
      children: _loading ? [const Loading()] : _content(),
    );
  }

  List<Widget> _content() {
    final now = DateTime.now();
    final last = _cycles.isEmpty ? null : DateTime.parse(_cycles.first['start_date']);
    final day = last == null ? null : now.difference(DateTime(last.year, last.month, last.day)).inDays + 1;
    final cycleDay = day == null ? null : ((day - 1) % _cycleLen) + 1;
    final phase = cycleDay == null ? null : _phaseFor(cycleDay);
    final next = last == null ? null : last.add(Duration(days: _cycleLen * (((day! - 1) ~/ _cycleLen) + 1)));
    final daysToNext = next?.difference(DateTime(now.year, now.month, now.day)).inDays;
    final c = AppColors.cycle;

    ListRow symptom(String field, String label, IconData icon, List<String> options) => ListRow(
          icon: icon,
          color: c,
          title: label,
          value: _today?[field] ?? 'Log',
          onTap: () => _pickSymptom(field, label, options),
        );

    return [
      VCard(
        child: Column(children: [
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(alignment: Alignment.center, children: [
              CustomPaint(size: const Size(200, 200), painter: _CycleWheel(cycleLen: _cycleLen, periodLen: _periodLen, day: cycleDay)),
              Column(mainAxisSize: MainAxisSize.min, children: [
                if (cycleDay == null)
                  Icon(Symbols.menstrual_health_rounded, size: 36, color: c)
                else ...[
                  Text('Day', style: T.labelMd.c(AppColors.onSurfaceVariant)),
                  Text('$cycleDay', style: T.metric(44)),
                  Text(phase!.name, style: T.labelMd.c(c)),
                ],
              ]),
            ]),
          ),
          const SizedBox(height: Sp.md),
          if (cycleDay == null) ...[
            Text('Start tracking', style: T.headlineSm),
            const SizedBox(height: 4),
            Text('Log the first day of your last period to see phases and predictions.', textAlign: TextAlign.center, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          ] else
            Text.rich(
              TextSpan(text: 'Next period in about ', children: [TextSpan(text: '$daysToNext days', style: T.bodyLg.semi), TextSpan(text: ' · ${DateFormat('d MMM').format(next!)}')]),
              textAlign: TextAlign.center,
              style: T.bodyLg.c(AppColors.onSurfaceVariant),
            ),
          const SizedBox(height: Sp.md),
          Wrap(spacing: 14, runSpacing: 6, alignment: WrapAlignment.center, children: [
            _legend('Period', c),
            _legend('Follicular', c.withValues(alpha: 0.35)),
            _legend('Fertile', AppColors.mind),
            _legend('Luteal', AppColors.surfaceContainerHighest),
          ]),
        ]),
      ),
      PrimaryButton('Log period', leadingIcon: Symbols.water_drop_rounded, onTap: _logPeriod),
      if (phase != null)
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CategoryLabel('${phase.name} phase', icon: phase.icon, color: c),
            const SizedBox(height: 8),
            Text(phase.insightTitle, style: T.headlineSm),
            const SizedBox(height: 4),
            Text(phase.insight, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          ]),
        ),
      if (_irregular)
        VCard(
          color: AppColors.warningContainer,
          onTap: () => context.push('/library/article/pcos-awareness'),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.info_rounded, color: AppColors.warning, fill: 1),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Your recent cycles have varied a lot. This can happen with stress or routine changes, and is sometimes linked to conditions like PCOS. It is not a diagnosis; consider a check-up if it continues.',
                  style: T.bodyMd.c(AppColors.onSurface)),
            ),
          ]),
        ),
      const SectionHeader('Today'),
      ListGroup(children: [
        symptom('cramps', 'Cramps', Symbols.healing_rounded, const ['None', 'Mild', 'Moderate', 'Strong']),
        symptom('mood', 'Mood', Symbols.mood_rounded, const ['Calm', 'Happy', 'Low', 'Irritable', 'Anxious']),
        symptom('energy', 'Energy', Symbols.bolt_rounded, const ['Low', 'Steady', 'High']),
        symptom('sleep', 'Sleep', Symbols.bedtime_rounded, const ['Restful', 'Okay', 'Restless']),
        ListRow(icon: Symbols.edit_note_rounded, color: c, title: 'Spotting and notes', onTap: _moreLog),
      ]),
      ListGroup(children: [
        ListRow(icon: Symbols.history_rounded, color: c, title: 'History', value: _lengths.isEmpty ? null : '$_cycleLen-day average', onTap: _history),
      ]),
      const PrivacyNote('Cycle data is private to you.'),
    ];
  }

  Widget _legend(String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: T.bodySm.c(AppColors.onSurfaceVariant)),
      ]);
}

class _CycleWheel extends CustomPainter {
  _CycleWheel({required this.cycleLen, required this.periodLen, required this.day});
  final int cycleLen;
  final int periodLen;
  final int? day;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const w = 14.0;
    final r = size.width / 2 - w;
    final rect = Rect.fromCircle(center: c, radius: r);
    const start = -math.pi / 2;
    double a(int d) => 2 * math.pi * d / cycleLen;
    Paint p(Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.butt
      ..color = color;
    const gap = 0.03;
    final ov = cycleLen - 14;
    canvas.drawArc(rect, start + gap, a(periodLen) - 2 * gap, false, p(AppColors.cycle));
    canvas.drawArc(rect, start + a(periodLen) + gap, a(ov - 3 - periodLen) - 2 * gap, false, p(AppColors.cycle.withValues(alpha: 0.35)));
    canvas.drawArc(rect, start + a(ov - 3) + gap, a(5) - 2 * gap, false, p(AppColors.mind));
    canvas.drawArc(rect, start + a(ov + 2) + gap, a(cycleLen - ov - 2) - 2 * gap, false, p(AppColors.surfaceContainerHighest));
    if (day != null) {
      final ang = start + a(day!) - a(1) / 2;
      final pt = c + Offset(math.cos(ang), math.sin(ang)) * r;
      canvas.drawCircle(pt, w / 2 + 4, Paint()..color = AppColors.surfaceContainerLowest);
      canvas.drawCircle(pt, w / 2 + 1, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.onSurface);
    }
  }

  @override
  bool shouldRepaint(covariant _CycleWheel old) => old.day != day || old.cycleLen != cycleLen;
}
