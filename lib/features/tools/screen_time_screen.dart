import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/device_usage.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/charts.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'tool_widgets.dart';

/// WHO/AAP-style guidance used for the comparison line: under 2 hours of
/// leisure screen time a day is considered a healthy ceiling for most people.
const _healthyCapMin = 120;

class ScreenTimeScreen extends StatefulWidget {
  const ScreenTimeScreen({super.key});
  @override
  State<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends State<ScreenTimeScreen> {
  bool _loading = true;
  bool _readingDevice = false;
  int _today = 0;
  Map<String, int> _week = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final ws = weekStart(now);
      _today = await Repo.screenTimeOn(now);
      _week = await Repo.screenTimeByDay(ws, ws.add(const Duration(days: 6)));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _logToday() async {
    int hours = _today ~/ 60, minutes = _today % 60;
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Screen time today', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('Total time on phone, laptop and TV outside lectures or coursework.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.lg),
            Center(child: MetricValue('${hours}h ${minutes}m', size: 36)),
            const SizedBox(height: Sp.sm),
            Row(children: [
              Expanded(
                child: Column(children: [
                  Text('Hours', style: T.labelMd.c(AppColors.onSurfaceVariant)),
                  VSlider(value: hours.toDouble(), min: 0, max: 16, divisions: 16, color: AppColors.mind, onChanged: (v) => set(() => hours = v.round())),
                ]),
              ),
              Expanded(
                child: Column(children: [
                  Text('Minutes', style: T.labelMd.c(AppColors.onSurfaceVariant)),
                  VSlider(value: minutes.toDouble(), min: 0, max: 55, divisions: 11, color: AppColors.mind, onChanged: (v) => set(() => minutes = v.round())),
                ]),
              ),
            ]),
            const SizedBox(height: Sp.md),
            PrimaryButton('Save', onTap: () async {
              await Repo.setScreenTime(DateTime.now(), hours * 60 + minutes);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }),
          ]);
        }));
  }

  Future<void> _readFromDevice() async {
    if (!DeviceUsage.supported) {
      return showInfoSheet(
        context,
        title: "Can't read this from your phone",
        icon: Symbols.info_rounded,
        paragraphs: const [
          "Automatic screen time is only available on Android right now, where the operating system keeps a usage log VitalU can read with your permission.",
          "iPhone's own Screen Time data isn't accessible to regular apps like VitalU — only Apple grants that to specialised parental-control apps. You can still check Settings > Screen Time on your iPhone and log the total below.",
        ],
      );
    }
    setState(() => _readingDevice = true);
    try {
      final minutes = await DeviceUsage.readTodayMinutes();
      if (minutes == null) {
        if (mounted) {
          toast(context, "Grant VitalU access under Usage access settings, then tap this again.", error: true);
        }
        return;
      }
      await Repo.setScreenTime(DateTime.now(), minutes);
      await _load();
      if (mounted) toast(context, 'Read ${minutes ~/ 60}h ${minutes % 60}m from your device.');
    } finally {
      if (mounted) setState(() => _readingDevice = false);
    }
  }

  (String, Color, String) get _summary {
    if (_today <= _healthyCapMin) {
      return ('Within a healthy range', AppColors.tertiary, 'Nice balance. Keep taking breaks and look away from the screen every 20 minutes.');
    }
    if (_today <= _healthyCapMin * 2) {
      return ('A little high today', AppColors.warning, 'Try replacing one short scrolling session with a walk, a chat or a breathing break.');
    }
    return ('Quite high today', AppColors.error, 'Long stretches of screen time strain your eyes, posture and sleep. Build in regular breaks and an earlier wind-down.');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ws = weekStart(now);
    final days = [for (int i = 0; i < 7; i++) ws.add(Duration(days: i))];
    final loggedDays = days.where((d) => !d.isAfter(now) && (_week[isoDate(d)] != null)).toList();
    final avg = loggedDays.isEmpty ? 0 : (loggedDays.map((d) => _week[isoDate(d)] ?? 0).reduce((a, b) => a + b) / loggedDays.length).round();
    final (title, color, tip) = _summary;
    final diff = _today - _healthyCapMin;

    return VPage(
      header: TitleHeader('Screen time', onLeading: () => goBack(context, '/tools')),
      onRefresh: _load,
      children: _loading
          ? [const Loading()]
          : [
              const ToolSubBar(label: 'Private self-check'),
              VCard(
                child: Column(children: [
                  Ring(value: (_today / (_healthyCapMin * 2)).clamp(0, 1), size: 112, stroke: 12, color: color, child: MetricValue('${_today ~/ 60}h ${_today % 60}m', size: 20)),
                  const SizedBox(height: Sp.md),
                  CategoryLabel(title, icon: Symbols.hourglass_bottom_rounded, color: color),
                  const SizedBox(height: 8),
                  Text(tip, textAlign: TextAlign.center, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Text(
                    diff == 0 ? 'Right at the ${_healthyCapMin ~/ 60}h guideline for leisure screen time.' : (diff > 0 ? '${diff}m over the ${_healthyCapMin ~/ 60}h guideline.' : '${-diff}m under the ${_healthyCapMin ~/ 60}h guideline.'),
                    style: T.bodySm.c(AppColors.onSurfaceVariant),
                  ),
                ]),
              ),
              PrimaryButton('Log today\'s screen time', leadingIcon: Symbols.edit_rounded, onTap: _logToday),
              ListGroup(children: [
                ListRow(
                  icon: Symbols.sync_rounded,
                  color: AppColors.mind,
                  title: 'Read from device',
                  subtitle: DeviceUsage.supported ? "Fill in today's total from your phone's usage data" : 'Only available on Android',
                  trailing: _readingDevice ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                  chevron: !_readingDevice,
                  onTap: _readingDevice ? null : _readFromDevice,
                ),
              ]),
              const SectionHeader('This week'),
              VCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  MetricValue(Fmt.hm(avg), unit: 'a day on average', size: 24),
                  const SizedBox(height: Sp.md),
                  BarChart(
                    values: [for (final d in days) d.isAfter(now) ? 0 : (_week[isoDate(d)] ?? 0).toDouble()],
                    labels: [for (final d in days) DateFormat('E').format(d).substring(0, 1)],
                    color: AppColors.mind,
                    goal: _healthyCapMin.toDouble(),
                    highlightLast: false,
                    height: 140,
                  ),
                ]),
              ),
              ListGroup(header: 'Ease the strain', children: [
                ListRow(icon: Symbols.visibility_rounded, color: AppColors.mind, title: '20-20-20 rule', subtitle: 'Every 20 minutes, look at something 20 feet away for 20 seconds'),
                ListRow(icon: Symbols.bedtime_rounded, color: AppColors.sleep, title: 'Screens off before bed', subtitle: 'Stop scrolling 30–60 minutes before sleep'),
                ListRow(icon: Symbols.air_rounded, color: AppColors.activity, title: 'Swap a scroll for a stretch', subtitle: 'Stand, stretch or walk between study blocks'),
              ]),
              const PrivacyNote('A wellness tracker, not a diagnosis. If screen use is affecting your sleep, studies or mood, a campus counsellor can help.'),
            ],
    );
  }
}
