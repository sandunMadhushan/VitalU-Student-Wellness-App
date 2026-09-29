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

const _menstrual = _Phase('Menstrual', 'Menstrual • Rest & Replenish', Symbols.water_drop, 'Energy may dip — gentle movement, iron-rich meals and warm drinks can help.',
    'Protect Your Rest', 'Plan lighter study blocks, keep warm drinks nearby and include iron-rich foods like dhal, green leaves and fish to replenish.');
const _follicular = _Phase('Follicular', 'Follicular • Rising Energy', Symbols.eco, 'Energy is gradually rising. A great time to start new topics and build study momentum.',
    'Build Momentum', 'Rising oestrogen often supports motivation. Start new modules or tough readings now and schedule active study sessions.');
const _ovulation = _Phase('Ovulation', 'Ovulation • Peak Energy Window', Symbols.wb_twilight, 'Hormones are gently peaking. Ideal for group study sessions, presentation prep, and creative flow.',
    'Leverage Ovulatory Focus', 'Many people feel most social and energetic now. Tackle presentations or group work, and prepare warm herbal teas for the restful phase ahead.');
const _luteal = _Phase('Luteal', 'Luteal • Restful Rhythm', Symbols.bedtime, 'Your body is winding down. Prioritise sleep, regular meals and kinder study pacing.',
    'Slow & Steady', 'Cravings and mood shifts are common. Keep regular meals, reduce caffeine, and plan revision rather than new material.');

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
            Text('Period Flow & Sensations', style: T.headlineMd),
            const SizedBox(height: Sp.md),
            if (open) ...[
              VCard(
                color: AppColors.secondaryFixed.withValues(alpha: 0.5),
                child: Row(children: [
                  Icon(Symbols.water_drop, color: AppColors.secondary, fill: 1),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Period started ${DateFormat('d MMM').format(DateTime.parse(_cycles.first['start_date']))}. Has it ended?', style: T.bodyMd)),
                ]),
              ),
              const SizedBox(height: Sp.sm),
              SoftButton('Mark period as ended today', icon: Symbols.check_circle, iconColor: AppColors.tertiary, onTap: () async {
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
                  Icon(Symbols.calendar_today, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Expanded(child: Text(DateFormat('EEEE, d MMMM').format(start), style: T.labelLg)),
                  const Icon(Symbols.edit, size: 18),
                ]),
              ),
              const SizedBox(height: Sp.md),
              Text('Flow', style: T.labelLg),
            ],
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final f in const ['spotting', 'light', 'medium', 'heavy'])
                VChip(f[0].toUpperCase() + f.substring(1), selected: flow == f, selectedColor: AppColors.secondary, onTap: () => set(() => flow = f)),
            ]),
            const SizedBox(height: Sp.lg),
            PrimaryButton(open ? 'Save Flow' : 'Log Period Start', leadingIcon: Symbols.water_drop, color: AppColors.inverseSurface, fg: AppColors.inverseOnSurface, onTap: () async {
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
            for (final o in options) VChip(o, selected: _today?[field] == o, selectedColor: AppColors.secondary, onTap: () => Navigator.pop(ctx, o)),
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
            SwitchListTile(value: spotting, onChanged: (v) => set(() => spotting = v), title: Text('Spotting', style: T.labelLg), activeTrackColor: AppColors.secondary, contentPadding: EdgeInsets.zero),
            const SizedBox(height: Sp.sm),
            VTextField(controller: notes, hint: 'Notes (headache, bloating, skin, cravings…)', maxLines: 3),
            const SizedBox(height: Sp.sm),
            SoftButton('Log water intake', icon: Symbols.water_drop, iconColor: AppColors.primary, onTap: () {
              Navigator.pop(ctx);
              context.push('/tools/water');
            }),
            const SizedBox(height: Sp.md),
            PrimaryButton('Save', color: AppColors.secondary, onTap: () async {
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
          Text('Cycle History', style: T.headlineMd),
          const SizedBox(height: 4),
          Text('Average cycle: $_cycleLen days • Average period: $_periodLen days', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          if (starts.isEmpty) Text('No cycles logged yet.', style: T.bodyMd),
          for (int i = 0; i < starts.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VCard(
                color: AppColors.surfaceContainerLow,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Symbols.water_drop, color: AppColors.secondary, fill: 1, size: 20),
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
            Text('Your cycle lengths vary more than usual. Irregular cycles have many causes (stress, weight change, sleep), and can sometimes be associated with conditions such as PCOS. This is not a diagnosis — a doctor can help if it continues.',
                style: T.bodySm.c(AppColors.secondary)),
          ],
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: const MainHeader('Vitalu   Health Tools'),
      nav: NavTab.tools,
      onRefresh: _load,
      children: _loading ? [const Loading()] : _content(),
    );
  }

  List<Widget> _content() {
    final now = DateTime.now();
    final last = _cycles.isEmpty ? null : DateTime.parse(_cycles.first['start_date']);
    final day = last == null ? null : now.difference(DateTime(last.year, last.month, last.day)).inDays + 1;
    final phase = day == null ? null : _phaseFor(((day - 1) % _cycleLen) + 1);
    final next = last == null ? null : last.add(Duration(days: _cycleLen * (((day! - 1) ~/ _cycleLen) + 1)));
    final daysToNext = next?.difference(DateTime(now.year, now.month, now.day)).inDays;

    Widget chip(String field, String label, IconData icon, Color c, String? value, String placeholder, List<String> options) {
      final on = value != null;
      return Pressable(
        onTap: () => _pickSymptom(field, label, options),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: on ? AppColors.secondaryFixed : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(Rad.r2xl),
            boxShadow: on ? Shadows.tinted(AppColors.secondary, opacity: 0.1, blur: 16, y: 4, spread: 0) : Shadows.tiny,
          ),
          child: Row(children: [
            IconCircle(icon, size: 36, iconSize: 20, bg: on ? AppColors.surfaceContainerLowest : AppColors.surfaceContainer, fg: c, shadow: on ? Shadows.tiny : null),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: T.labelMd.c(on ? AppColors.onSecondaryFixedVariant : AppColors.onSurface), overflow: TextOverflow.ellipsis),
                Text(value ?? placeholder, style: T.bodySm.s(11).c(on ? AppColors.onSecondaryFixedVariant : AppColors.onSurfaceVariant).lh(1.2), overflow: TextOverflow.ellipsis),
              ]),
            ),
            Icon(on ? Symbols.check_circle : Symbols.radio_button_unchecked, size: 18, color: on ? AppColors.secondary : AppColors.outlineVariant),
          ]),
        ),
      );
    }

    return [
      Row(children: [
        CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainerLowest, fg: AppColors.onSurface, shadow: Shadows.soft, onTap: () => goBack(context, '/tools')),
        const Spacer(),
        TagPill('Private & Encrypted', icon: Symbols.lock, bg: AppColors.surfaceContainerLow, fg: AppColors.secondary),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TagPill('Cycle Rhythm • Natural Fluctuations', icon: Symbols.spa, upper: true, bg: AppColors.secondaryFixed, fg: AppColors.onSecondaryFixedVariant),
        const SizedBox(height: 6),
        Text('Cycle Sanctuary', style: T.headlineMd),
        const SizedBox(height: 2),
        Text('Gentle tracking aligned with your semester rhythm. No pressure, just intuitive bodily awareness.', style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.35)),
      ]),
      Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.surfaceContainerLowest, AppColors.surfaceContainerLow, AppColors.surfaceContainerHigh]),
          boxShadow: const [BoxShadow(color: Color(0x14984062), blurRadius: 36, offset: Offset(0, 16), spreadRadius: -10), BoxShadow(color: Color(0x0A2D2B38), blurRadius: 16, offset: Offset(0, 4))],
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(top: -48, right: -48, child: Glow(color: AppColors.secondaryFixed.withValues(alpha: 0.5), size: 176)),
          Positioned(bottom: -40, left: -40, child: Glow(color: AppColors.primaryFixed.withValues(alpha: 0.4), size: 160)),
          Column(children: [
            SizedBox(
              width: 256,
              height: 256,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(size: const Size(256, 256), painter: _CycleWheel(cycleLen: _cycleLen, periodLen: _periodLen, day: day == null ? null : ((day - 1) % _cycleLen) + 1)),
                Container(
                  width: 176,
                  height: 176,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9)),
                  child: ClipOval(child: const AssetImg('lotus_moon')),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            if (day == null) ...[
              Text('Start your cycle rhythm', style: T.headlineSm),
              const SizedBox(height: 6),
              Text('Log the first day of your last period to see phases and predictions.', textAlign: TextAlign.center, style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ] else ...[
              Text('Day ${((day - 1) % _cycleLen) + 1} of your cycle', style: T.headlineSm),
              const SizedBox(height: 4),
              TagPill(phase!.badge, icon: phase.icon, bg: AppColors.secondaryFixed, fg: AppColors.onSecondaryFixed),
              const SizedBox(height: 8),
              ConstrainedBox(constraints: const BoxConstraints(maxWidth: 270), child: Text(phase.text, textAlign: TextAlign.center, style: T.bodySm.c(AppColors.onSurfaceVariant))),
              const SizedBox(height: 12),
              Pill(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Symbols.calendar_clock, size: 15, color: AppColors.secondary),
                  const SizedBox(width: 6),
                  Text.rich(TextSpan(text: 'Next cycle predicted in ', children: [
                    TextSpan(text: '~$daysToNext days (${DateFormat('MMM d').format(next!)})', style: T.labelSm.c(AppColors.onSurface).semi),
                  ]), style: T.labelSm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
            ],
          ]),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Log Today's Rhythm", style: T.headlineSm),
              Text('How is your body feeling during class today?', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          CircleButton(Symbols.tune, size: 32, iconSize: 18, bg: AppColors.surfaceContainer, onTap: _moreLog),
        ]),
        const SizedBox(height: Sp.sm),
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            SizedBox(width: w, child: chip('cramps', 'Cramps', Symbols.hot_tub, AppColors.secondary, _today?['cramps'], 'Tap to log', const ['None', 'Gentle / Mild', 'Moderate', 'Strong'])),
            SizedBox(width: w, child: chip('mood', 'Mood', Symbols.filter_drama, AppColors.primary, _today?['mood'], 'Tap to log', const ['Calm & Reflective', 'Happy', 'Low', 'Irritable', 'Anxious'])),
            SizedBox(width: w, child: chip('energy', 'Energy', Symbols.bolt, AppColors.tertiary, _today?['energy'], 'Tap to log', const ['Low', 'Steady Pace', 'High'])),
            SizedBox(width: w, child: chip('sleep', 'Sleep', Symbols.bedtime, AppColors.secondary, _today?['sleep'], 'Tap to log', const ['Restful', 'Okay', 'Restless'])),
          ]);
        }),
        const SizedBox(height: Sp.sm),
        SoftButton('Log Spotting, Water or Notes', icon: Symbols.add_circle, fg: AppColors.onSurfaceVariant, height: 46, style: T.labelMd, onTap: _moreLog),
      ]),
      if (phase != null)
        Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceContainerLowest, AppColors.secondaryFixed.withValues(alpha: 0.3), AppColors.surfaceContainerLow]),
            boxShadow: const [BoxShadow(color: Color(0x0F984062), blurRadius: 28, offset: Offset(0, 12), spreadRadius: -8)],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(Symbols.school, size: 40, iconSize: 22, bg: AppColors.secondaryFixed, fg: AppColors.secondary, shadow: Shadows.tiny),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('SEMESTER SYNC INSIGHT', style: T.labelSm.s(10).c(AppColors.secondary).bold.tracking(1)),
                  const SizedBox(width: 6),
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.6), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${phase.name} phase', style: T.labelSm.s(11).c(AppColors.onSurfaceVariant)),
                ]),
                const SizedBox(height: 4),
                Text(phase.insightTitle, style: T.headlineSm.lh(1.2)),
                const SizedBox(height: 6),
                Text(phase.insight, style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
              ]),
            ),
          ]),
        ),
      if (_irregular)
        VCard(
          color: AppColors.secondaryFixed.withValues(alpha: 0.35),
          onTap: () => context.push('/library/article/pcos-awareness'),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.info, color: AppColors.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Your recent cycles have been irregular. This can happen with stress or routine changes, and is sometimes associated with conditions like PCOS. It is not a diagnosis — consider a check-up if it continues. Tap to learn more.',
                  style: T.bodySm.c(AppColors.onSecondaryFixedVariant)),
            ),
          ]),
        ),
      if (last != null)
        VCard(
          radius: 24,
          shadow: Shadows.soft,
          child: Column(children: [
            Row(children: [
              Icon(Symbols.date_range, color: AppColors.secondary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('${DateFormat('MMMM').format(last)} – ${DateFormat('MMMM').format(next!)}', style: T.headlineSm)),
              Text('$_cycleLen-Day Pattern', style: T.labelSm.c(AppColors.onSurfaceVariant)),
            ]),
            const SizedBox(height: Sp.sm),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _seg(_periodLen.toDouble(), AppColors.secondaryContainer, DateFormat('MMM d').format(last), phase == _menstrual),
              const SizedBox(width: 6),
              _seg(math.max(1, _cycleLen - 14 - 2 - _periodLen - 1).toDouble(), AppColors.primaryFixed, 'Follicular', phase == _follicular),
              const SizedBox(width: 6),
              _seg(5, AppColors.secondary, 'Ovulation', phase == _ovulation),
              const SizedBox(width: 6),
              _seg(12, AppColors.surfaceContainerHighest, '${DateFormat('MMM d').format(next)} • Next', phase == _luteal),
            ]),
          ]),
        ),
      PrimaryButton('Log Period Flow & Physical Sensations', leadingIcon: Symbols.water_drop, color: AppColors.inverseSurface, fg: AppColors.onPrimary, height: 52, onTap: _logPeriod),
      SoftButton('View Cycle History & Monthly Trends', icon: Symbols.insights, iconColor: AppColors.secondary, height: 48, style: T.labelMd, onTap: _history),
      const PrivacyNote('Cycle data is private to you. Never shared with or visible to university administrators.'),
    ];
  }

  Widget _seg(double flex, Color c, String label, bool current) => Expanded(
        flex: (flex * 10).round(),
        child: Column(children: [
          Container(
            height: current ? 10 : 8,
            decoration: BoxDecoration(
              color: current ? AppColors.secondary : c,
              borderRadius: BorderRadius.circular(8),
              border: current ? Border.all(color: AppColors.secondaryFixed, width: 2) : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(current ? 'Today' : label, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.labelSm.s(10).c(current ? AppColors.secondary : AppColors.onSurfaceVariant).w(current ? FontWeight.w700 : FontWeight.w500)),
        ]),
      );
}

class _CycleWheel extends CustomPainter {
  _CycleWheel({required this.cycleLen, required this.periodLen, required this.day});
  final int cycleLen;
  final int periodLen;
  final int? day;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 14;
    final rect = Rect.fromCircle(center: c, radius: r);
    const start = -math.pi / 2;
    double a(int d) => 2 * math.pi * d / cycleLen;
    Paint p(Color color, double w, {Shader? shader}) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = color
      ..shader = shader;

    canvas.drawCircle(c, r, p(const Color(0xFFEBE6F7), 12));
    final ov = cycleLen - 14;
    const gap = 0.05;
    // Menstrual
    canvas.drawArc(rect, start + gap, a(periodLen) - 2 * gap, false,
        p(AppColors.secondary, 12, shader: SweepGradient(colors: [AppColors.secondaryContainer, AppColors.secondary]).createShader(rect)));
    // Follicular
    canvas.drawArc(rect, start + a(periodLen) + gap, a(ov - 2 - periodLen - 1) - 2 * gap, false, p(AppColors.primaryFixedDim, 12));
    // Ovulation
    canvas.drawArc(rect, start + a(ov - 3) + gap, a(5) - 2 * gap, false,
        p(AppColors.secondaryFixedDim, 14, shader: SweepGradient(colors: [AppColors.secondaryFixedDim, AppColors.primaryFixedDim]).createShader(rect)));
    // Luteal
    canvas.drawArc(rect, start + a(ov + 2) + gap, a(cycleLen - ov - 2) - 2 * gap, false, p(AppColors.surfaceDim, 12));
    // Predicted dashed outer ring
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.secondary.withValues(alpha: 0.5);
    for (double t = 0; t < 2 * math.pi; t += 0.12) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r + 11), t, 0.05, false, dash);
    }
    if (day != null) {
      final ang = start + a(day!) - a(1) / 2;
      final pt = c + Offset(math.cos(ang), math.sin(ang)) * r;
      canvas.drawCircle(pt + const Offset(0, 2), 10, Paint()
        ..color = const Color(0x4D984062)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(pt, 9, Paint()..color = Colors.white);
      canvas.drawCircle(pt, 5, Paint()..color = AppColors.secondary);
    }
  }

  @override
  bool shouldRepaint(covariant _CycleWheel old) => old.day != day || old.cycleLen != cycleLen;
}
