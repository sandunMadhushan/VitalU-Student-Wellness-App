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
import '../assessments/assessment_data.dart';
import 'breathing.dart';

const moods = <(String, String, String)>[
  ('Centered', '🌱', 'Quiet mind'),
  ('Calm', '😌', 'Low cognitive strain'),
  ('Joyful', '🌼', 'Bright energy'),
  ('Tired', '😴', 'Needs gentle rest'),
  ('Stressed', '🌧️', 'Heavy study load'),
  ('Anxious', '🌀', 'Racing thoughts'),
];

(String, String, String) moodInfo(String? m) => moods.firstWhere((e) => e.$1 == m, orElse: () => moods.first);

Future<void> showMoodPicker(BuildContext context, {VoidCallback? onSaved}) async {
  String? picked;
  final note = TextEditingController();
  await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('How is your mind right now?', style: T.headlineMd),
          const SizedBox(height: 4),
          Text('A private reflection — no right or wrong answers.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final m in moods)
              VChip('${m.$2}  ${m.$1}', selected: picked == m.$1, selectedColor: AppColors.secondary, onTap: () => set(() => picked = m.$1)),
          ]),
          const SizedBox(height: Sp.md),
          VTextField(controller: note, hint: 'Add a gentle note (optional)', maxLines: 3),
          const SizedBox(height: Sp.md),
          PrimaryButton('Save Reflection', color: AppColors.secondary, onTap: picked == null
              ? null
              : () async {
                  await Repo.addMood(picked!, note: note.text.trim().isEmpty ? null : note.text.trim());
                  if (ctx.mounted) Navigator.pop(ctx);
                  onSaved?.call();
                }),
        ]);
      }));
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  int _water = 0;
  int _steps = 0;
  int _activeMinutes = 0;
  int _mealsToday = 0;
  int _diversityToday = 0;
  Rec? _sleep;
  Rec? _mood;
  Rec? _openWindow;
  Rec? _nextWindow;
  Rec? _assessment;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final today = isoDate(now);
      final results = await Future.wait([
        Repo.waterTotal(now),
        Repo.activityTotals(now),
        Repo.sleepLatest(),
        Repo.moodLatest(),
        Repo.currentAndNextWindow(),
        Repo.mealsOn(now),
        Repo.diversityBetween(weekStart(now), now),
      ]);
      _water = results[0] as int;
      final act = results[1] as Rec;
      _steps = act['steps'] as int;
      _activeMinutes = act['minutes'] as int;
      final s = results[2] as Rec?;
      _sleep = (s != null && DateTime.now().difference(DateTime.parse(s['sleep_date'])).inDays <= 1) ? s : null;
      final m = results[3] as Rec?;
      _mood = (m != null && DateTime.now().difference(DateTime.parse(m['logged_at']).toLocal()).inHours < 24) ? m : null;
      final (open, next) = results[4] as (Rec?, Rec?);
      _openWindow = open;
      _nextWindow = next;
      _assessment = open == null ? null : await Repo.assessmentFor(open['id']);
      _mealsToday = (results[5] as List).length;
      _diversityToday = (results[6] as List).where((r) => r['log_date'] == today).map((r) => r['food_group']).toSet().length;
      await AppState.instance.refreshUnread();
    } catch (e) {
      debugPrint('home load: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  bool get _windowActive => _openWindow != null && _assessment?['status'] != 'completed';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) => VPage(
        header: const MainHeader('Home'),
        nav: NavTab.home,
        onRefresh: _load,
        spacing: _windowActive ? 24 : Sp.md,
        children: _loading ? [const Loading()] : (_windowActive ? _windowChildren() : _defaultChildren()),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  Widget _greetingRow({required String emoji, required String subtitle, bool badgeAvatar = true}) {
    final p = AppState.instance.profile;
    return Row(children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: Shadows.tinted(AppColors.primary, opacity: 0.15, blur: 16, y: 4, spread: -4)),
          child: Avatar(size: 48, ring: false),
        ),
        if (badgeAvatar)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(color: AppColors.tertiaryFixed, shape: BoxShape.circle, boxShadow: Shadows.tiny),
              child: Icon(Symbols.spa, size: 10, color: AppColors.onTertiaryFixed),
            ),
          ),
      ]),
      const SizedBox(width: Sp.sm),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text('$_greeting, ${p?.firstName ?? ''}', style: T.headlineSm, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 6),
            Text(emoji, style: const TextStyle(fontSize: 16)),
          ]),
          Text(subtitle, style: T.bodySm.c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
        ]),
      ),
      CircleButton(Symbols.notifications,
          bg: AppColors.surfaceContainerLowest, iconSize: 22, shadow: Shadows.soft, badge: AppState.instance.unreadCount > 0, onTap: () async {
        await context.push('/notifications');
        _load();
      }),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Default dashboard
  // ---------------------------------------------------------------------------
  List<Widget> _defaultChildren() {
    final p = AppState.instance.profile;
    final waterGoal = p?.waterGoalMl ?? 2500;
    final stepGoal = p?.stepGoal ?? 8000;
    final sleepGoalMin = ((p?.sleepGoalHours ?? 8) * 60).round();
    final sleepMin = _sleep == null ? 0 : Repo.sleepMinutes(_sleep!);
    final mood = _mood == null ? null : moodInfo(_mood!['mood']);
    final next = _openWindow ?? _nextWindow;
    final bmi = p?.bmi;
    final whr = p?.whr;

    return [
      Padding(padding: const EdgeInsets.only(top: 4), child: _greetingRow(emoji: '✨', subtitle: 'Ready for a balanced day?')),
      Row(children: [
        Expanded(child: Text('My Health Metrics', style: T.headlineSm)),
        Text(p?.measuredAt == null ? 'Not yet updated' : 'Updated ${DateFormat('d MMM').format(p!.measuredAt!.toLocal())}', style: T.labelSm.c(AppColors.onSurfaceVariant)),
      ]),
      Row(children: [
        _bmiStat(bmi, () => _go('/tools/bmi')),
        const SizedBox(width: 10),
        _stat(Symbols.accessibility_new, AppColors.primaryFixed.withValues(alpha: 0.6), AppColors.primary, whr?.toStringAsFixed(2) ?? '—', 'WHR Ratio',
            whr == null ? 0 : ((whr - 0.6) / 0.5).clamp(0, 1), () => _go('/tools/whr')),
      ]),
      Text("Today's Health Goals", style: T.headlineSm),
      Row(children: [
        _goalTile(Symbols.water_drop, AppColors.primaryFixed, AppColors.primary, '${(_water / 250).round()}/${(waterGoal / 250).round()}', 'Water (glasses)'),
        const SizedBox(width: Sp.xs),
        _goalTile(Symbols.restaurant, AppColors.secondaryFixed, AppColors.secondary, '$_mealsToday', 'Meals logged'),
        const SizedBox(width: Sp.xs),
        _goalTile(Symbols.nutrition, AppColors.tertiaryFixed, AppColors.tertiary, '$_diversityToday/8', 'Diet diversity'),
      ]),
      Row(children: [
        _goalTile(Symbols.directions_walk, AppColors.butterWash, AppColors.butterAccent, Fmt.thousands(_steps), 'Activity (steps)'),
        const SizedBox(width: Sp.xs),
        _goalTile(Symbols.bedtime, AppColors.primaryFixed, AppColors.primary, _sleep == null ? '—' : Fmt.hm(sleepMin), 'Sleep'),
      ]),
      Row(children: [
        Expanded(child: _quickAction(Symbols.restaurant, 'Log a Meal', AppColors.surfaceContainerLow, AppColors.tertiary, AppColors.onSurface, () => _go('/diet/log'))),
        const SizedBox(width: Sp.sm),
        Expanded(child: _quickAction(Symbols.ecg_heart, 'Health Tools', AppColors.primaryFixed, AppColors.primary, AppColors.onPrimaryFixed, () => context.go('/tools'))),
      ]),
      VCard(
        color: AppColors.surfaceContainerLow,
        clip: true,
        shadow: Shadows.tinted(AppColors.primary, opacity: 0.06, blur: 28, y: 12, spread: -8),
        onTap: () => _go('/assessments'),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(right: -44, bottom: -44, child: Glow(color: AppColors.primaryFixedDim.withValues(alpha: 0.2))),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(Symbols.calendar_today, shadow: Shadows.tiny),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  Text('CAMPUS SYNC', style: T.labelSm.c(AppColors.primary).bold.tracking(1)),
                  Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, shape: BoxShape.circle)),
                  Text(_assessment?['status'] == 'completed' ? 'Completed this term' : 'All forms ready', style: T.bodySm.c(AppColors.tertiary).medium),
                ]),
                const SizedBox(height: 2),
                Text(
                  next == null ? 'No assessment scheduled yet' : 'Next University Health Assessment: ${DateFormat('MMM yyyy').format(DateTime.parse(next['opens_at']).toLocal())}',
                  style: T.headlineSm.tracking(-0.2).lh(1.3),
                ),
                const SizedBox(height: 4),
                Text('Periodic student wellness check-in • ~5 minutes', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ]),
      ),
      SectionHeader("Today's Rhythm",
          subtitle: 'Listen to your body • no streak stress', trailing: Text('Balanced pace', style: T.labelMd.c(AppColors.primary).medium)),
      Row(children: [
        Expanded(
          child: _rhythmCard(
            icon: Symbols.water_drop,
            iconFill: 1,
            iconColor: AppColors.primary,
            label: 'Water',
            ringValue: _water / waterGoal,
            ringColor: AppColors.primaryContainer,
            ringCenter: '${(_water / waterGoal * 100).clamp(0, 999).round()}%',
            main: Fmt.litres(_water),
            mainSuffix: ' / ${Fmt.litres(waterGoal)}L',
            sub: 'Study fuel',
            foot: 'Stay hydrated during study',
            onTap: () => _go('/tools/water'),
          ),
        ),
        const SizedBox(width: Sp.sm),
        Expanded(
          child: _rhythmCard(
            icon: Symbols.directions_walk,
            iconColor: AppColors.tertiary,
            label: 'Movement',
            ringValue: _steps / stepGoal,
            ringColor: AppColors.tertiaryContainer,
            ringCenter: '${(_steps / stepGoal * 100).clamp(0, 999).round()}%',
            main: Fmt.thousands(_steps),
            sub: '${Fmt.k(stepGoal)} goal',
            foot: 'Campus strolls count',
            onTap: () => _go('/tools/activity'),
          ),
        ),
      ]),
      Row(children: [
        Expanded(
          child: _rhythmCard(
            icon: Symbols.bedtime,
            iconFill: 1,
            iconColor: AppColors.primary,
            label: 'Sleep',
            ringValue: sleepMin / sleepGoalMin,
            ringColor: AppColors.primary,
            ringCenter: _sleep == null ? '—' : '${(sleepMin / sleepGoalMin * 100).clamp(0, 999).round()}%',
            main: _sleep == null ? 'Log sleep' : Fmt.hm(sleepMin).replaceAll(' 0', ' '),
            sub: _sleep == null ? 'Tap to add' : (sleepMin >= sleepGoalMin * 0.9 ? 'Restful' : 'Light rest'),
            foot: _sleep == null ? 'How did you sleep?' : 'Deep restorative recovery',
            onTap: () => _go('/tools/sleep'),
          ),
        ),
        const SizedBox(width: Sp.sm),
        Expanded(
          child: _rhythmCard(
            icon: Symbols.favorite,
            iconFill: 1,
            iconColor: AppColors.secondary,
            iconBg: AppColors.secondaryFixed,
            label: 'Mood',
            ringValue: mood == null ? 0 : 0.92,
            ringColor: AppColors.secondaryContainer,
            ringCenterWidget: Text(mood?.$2 ?? '🌱', style: const TextStyle(fontSize: 16)),
            main: mood?.$1 ?? 'Check in',
            sub: mood?.$3 ?? 'Tap to reflect',
            subColor: AppColors.secondary,
            foot: _mood?['note'] as String? ?? 'A gentle moment for you',
            onTap: () => showMoodPicker(context, onSaved: _load),
          ),
        ),
      ]),
      VCard(
        color: AppColors.surfaceContainerLow,
        shadow: Shadows.soft,
        child: Row(children: [
          IconCircle(Symbols.self_improvement, size: 40, bg: AppColors.secondaryFixed, fg: AppColors.secondary),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Campus is a marathon, not a sprint', style: T.headlineSm.s(15).lh(1.35)),
              const SizedBox(height: 2),
              Text('Remember to stretch between lectures and take gentle sips of fresh air.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
      _helpRow(),
    ];
  }

  Widget _helpRow() => VCard(
        color: AppColors.errorContainer.withValues(alpha: 0.55),
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 14),
        onTap: () => _go('/help'),
        child: Row(children: [
          IconCircle(Symbols.emergency, size: 36, iconSize: 19, fg: AppColors.error),
          const SizedBox(width: Sp.sm),
          Expanded(child: Text('Need help now? Emergency & support lines', style: T.labelLg.c(AppColors.onErrorContainer))),
          Icon(Symbols.chevron_right, color: AppColors.onErrorContainer),
        ]),
      );

  Widget _stat(IconData icon, Color bg, Color fg, String value, String label, double bar, VoidCallback onTap) => Expanded(
        child: VCard(
          padding: const EdgeInsets.all(14),
          shadow: Shadows.soft,
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(icon, size: 28, iconSize: 16, bg: bg, fg: fg),
            const SizedBox(height: 8),
            Text(value, style: T.headlineMd.lh(1)),
            const SizedBox(height: 4),
            Text(label, style: T.labelSm.s(11).c(AppColors.onSurfaceVariant)),
            const SizedBox(height: 10),
            Bar(value: bar, height: 6, color: fg, track: AppColors.surfaceContainer),
          ]),
        ),
      );

  /// BMI tile with a status-coloured icon (underweight/normal/overweight/obese)
  /// instead of a body photo.
  Widget _bmiStat(double? bmi, VoidCallback onTap) {
    final (icon, bg, fg) = switch (bmi == null ? null : Calc.bmiCategory(bmi)) {
      null => (Symbols.scale, AppColors.surfaceContainerHigh, AppColors.onSurfaceVariant),
      'Underweight' => (Symbols.trending_down, AppColors.skyWash, AppColors.skyAccent),
      'Normal Weight' => (Symbols.check_circle, AppColors.tertiaryFixed, AppColors.tertiary),
      'Overweight' => (Symbols.trending_up, AppColors.butterWash, AppColors.butterAccent),
      _ => (Symbols.priority_high, AppColors.errorContainer, AppColors.error),
    };
    return _stat(icon, bg, fg, bmi?.toStringAsFixed(1) ?? '—', 'BMI Range', bmi == null ? 0 : ((bmi - 15) / 20).clamp(0, 1), onTap);
  }

  Widget _goalTile(IconData icon, Color bg, Color fg, String value, String label) => Expanded(
        child: VCard(
          color: AppColors.surfaceContainerLowest,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          shadow: Shadows.tiny,
          child: Column(children: [
            IconCircle(icon, size: 32, iconSize: 16, bg: bg, fg: fg, fill: 1),
            const SizedBox(height: 6),
            Text(value, style: T.labelLg.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label, style: T.labelSm.s(10).c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ]),
        ),
      );

  Widget _quickAction(IconData icon, String label, Color bg, Color iconColor, Color fg, VoidCallback onTap) => Pressable(
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.full), boxShadow: Shadows.tinted(iconColor, opacity: 0.1, blur: 20, y: 8)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconCircle(icon, size: 32, iconSize: 18, fg: iconColor, shadow: Shadows.tiny),
            const SizedBox(width: 8),
            Flexible(child: Text(label, style: T.labelLg.c(fg).tracking(-0.2), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );

  Widget _rhythmCard({
    required IconData icon,
    double iconFill = 0,
    required Color iconColor,
    Color? iconBg,
    required String label,
    required double ringValue,
    required Color ringColor,
    String? ringCenter,
    Widget? ringCenterWidget,
    required String main,
    String? mainSuffix,
    required String sub,
    Color? subColor,
    required String foot,
    VoidCallback? onTap,
  }) {
    final iconBg0 = iconBg ?? AppColors.surfaceContainerLow;
    return VCard(
      shadow: Shadows.soft,
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconCircle(icon, size: 36, iconSize: 20, bg: iconBg0, fg: iconColor, fill: iconFill),
          const Spacer(),
          Text(label, style: T.labelSm.c(AppColors.onSurfaceVariant)),
        ]),
        const SizedBox(height: Sp.sm),
        Row(children: [
          Ring(value: ringValue, color: ringColor, child: ringCenterWidget ?? Text(ringCenter ?? '', style: T.labelSm.bold)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(
                TextSpan(text: main, children: [if (mainSuffix != null) TextSpan(text: mainSuffix, style: T.bodySm.c(AppColors.onSurfaceVariant))]),
                style: T.labelLg.lh(1.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(sub, style: T.labelSm.c(subColor ?? AppColors.outline), overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
        const SizedBox(height: Sp.sm),
        Text(foot, style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  // ---------------------------------------------------------------------------
  // Assessment-window-open dashboard
  // ---------------------------------------------------------------------------
  List<Widget> _windowChildren() {
    final w = _openWindow!;
    final p = AppState.instance.profile;
    final opens = DateTime.parse(w['opens_at']).toLocal();
    final closes = DateTime.parse(w['closes_at']).toLocal();
    final answered = (_assessment?['answers'] as Map?)?.length ?? 0;
    final progress = answered / assessmentQuestions.length;
    final started = _assessment != null;
    final waterGoal = p?.waterGoalMl ?? 2500;
    final sleepMin = _sleep == null ? null : Repo.sleepMinutes(_sleep!);
    final mood = _mood == null ? null : moodInfo(_mood!['mood']);

    Widget check(String label, IconData icon, Color iconColor, double fill, Widget body, VoidCallback onTap) => Expanded(
          child: VCard(
            color: AppColors.surfaceContainerLow,
            shadow: Shadows.tiny,
            onTap: onTap,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(label, style: T.labelMd.c(AppColors.onSurfaceVariant))),
                IconCircle(icon, size: 32, iconSize: 18, fg: iconColor, fill: fill, shadow: Shadows.tiny),
              ]),
              const SizedBox(height: 8),
              body,
            ]),
          ),
        );

    return [
      Padding(padding: const EdgeInsets.only(top: 4), child: _greetingRow(emoji: '👋', subtitle: 'Welcome to your sanctuary', badgeAvatar: false)),
      Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.secondaryFixed, AppColors.surfaceContainerLow, AppColors.primaryFixed]),
          boxShadow: Shadows.card,
        ),
        padding: const EdgeInsets.all(Sp.md),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(right: -52, bottom: -52, child: Glow(color: AppColors.secondaryFixedDim.withValues(alpha: 0.3), size: 176)),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Flexible(
                child: Pill(
                  color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
                  shadow: Shadows.tiny,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.secondary, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Flexible(child: Text('Campus Milestone • Active Window', style: T.labelSm.c(AppColors.onSecondaryFixedVariant), overflow: TextOverflow.ellipsis)),
                  ]),
                ),
              ),
              const Spacer(),
              TagPill('${w['estimated_minutes'] ?? 5} mins', icon: Symbols.schedule, bg: AppColors.surfaceContainerLowest.withValues(alpha: 0.7)),
            ]),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(16), boxShadow: Shadows.tiny),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(begin: Alignment.bottomLeft, end: Alignment.topRight, colors: [AppColors.secondaryFixed, AppColors.primaryFixed.withValues(alpha: 0.4)]),
                  ),
                  child: Icon(Symbols.assignment_turned_in, color: AppColors.secondary, size: 34, fill: 1),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Your Health Assessment is Now Open', style: T.headlineSm.c(AppColors.onSecondaryFixed).lh(1.35)),
                  const SizedBox(height: 2),
                  Text('Faculty window: ${DateFormat('d').format(opens)}–${DateFormat('d MMMM').format(closes)} • ${w['term']}',
                      style: T.labelSm.c(AppColors.onSecondaryFixedVariant.withValues(alpha: 0.9))),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Text('A gentle 5-minute periodic reflection to understand your current energy, stress, and nutrition. Confidential & privacy protected.',
                style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLowest.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16), boxShadow: Shadows.tiny),
              child: Column(children: [
                Row(children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: started ? AppColors.primary : AppColors.outlineVariant, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(started ? 'In progress' : 'Not yet started', style: T.labelSm.c(AppColors.onSurfaceVariant)),
                  const Spacer(),
                  Text('${(progress * 100).round()}% Completed', style: T.labelSm.c(AppColors.primary)),
                ]),
                const SizedBox(height: 6),
                Bar(value: progress, height: 8, track: AppColors.surfaceContainerHighest),
              ]),
            ),
            const SizedBox(height: 16),
            PrimaryButton(started ? 'Continue Assessment' : 'Start Assessment', icon: Symbols.arrow_forward, height: 52, onTap: () => _go('/assessments/run')),
            const SizedBox(height: 4),
            Center(
              child: TextLinkButton('Remind me tonight', onTap: () async {
                final now = DateTime.now();
                var at = DateTime(now.year, now.month, now.day, 20);
                if (at.isBefore(now)) at = now.add(const Duration(hours: 1));
                await Repo.schedule(
                  title: 'Health Assessment Window',
                  body: 'Your ${w['term']} assessment is open. Take 5 gentle minutes whenever you feel ready.',
                  category: 'milestone',
                  label: 'Campus Milestone',
                  icon: 'event_upcoming',
                  route: '/assessments/run',
                  at: at,
                );
                if (mounted) toast(context, "We'll remind you at ${DateFormat('h:mm a').format(at)} 🌙");
              }),
            ),
          ]),
        ]),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("Today's Gentle Check-in", style: T.headlineSm),
        Text('How your body feels right now', style: T.bodySm.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: 14),
        Row(children: [
          check('Hydration', Symbols.water_drop, AppColors.primary, 1, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${Fmt.litres(_water)} / ${Fmt.litres(waterGoal)} L', style: T.headlineSm),
            const SizedBox(height: 6),
            Bar(value: _water / waterGoal, height: 6, color: AppColors.primaryContainer, track: AppColors.surfaceContainerHighest),
          ]), () => _go('/tools/water')),
          const SizedBox(width: 12),
          check('Rest', Symbols.bedtime, AppColors.primary, 1, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sleepMin == null ? '—' : Fmt.hm(sleepMin), style: T.headlineSm),
            const SizedBox(height: 2),
            _dotLabel(sleepMin == null ? 'Tap to log sleep' : 'Restful recovery'),
          ]), () => _go('/tools/sleep')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          check('Movement', Symbols.directions_walk, AppColors.secondary, 0, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$_activeMinutes mins', style: T.headlineSm),
            const SizedBox(height: 2),
            Text('Gentle campus pace', style: T.labelSm.c(AppColors.onSurfaceVariant)),
          ]), () => _go('/tools/activity')),
          const SizedBox(width: 12),
          check('Mind State', Symbols.spa, AppColors.tertiary, 1, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mood?.$1 ?? 'Check in', style: T.headlineSm),
            const SizedBox(height: 2),
            Text(mood?.$3 ?? 'Tap to reflect', style: T.labelSm.c(AppColors.tertiaryContainer)),
          ]), () => showMoodPicker(context, onSaved: _load)),
        ]),
      ]),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Calm Shortcuts', style: T.labelLg),
          const Spacer(),
          GestureDetector(onTap: () => context.go('/tools'), child: Text('View all', style: T.labelSm.c(AppColors.primary))),
        ]),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(children: [
            _shortcut(Symbols.air, AppColors.primary, 'Quick Breathwork', () => showBreathing(context, cta: 'Done')),
            const SizedBox(width: 8),
            _shortcut(Symbols.restaurant, AppColors.secondary, 'Log Meal', () => _go('/diet/log')),
            const SizedBox(width: 8),
            _shortcut(Symbols.support_agent, AppColors.tertiary, 'Campus Support', () => _go('/professionals')),
            const SizedBox(width: 8),
            _shortcut(Symbols.emergency, AppColors.error, 'Need Help Now', () => _go('/help')),
          ]),
        ),
      ]),
    ];
  }

  Widget _dotLabel(String t) => Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Flexible(child: Text(t, style: T.labelSm.c(AppColors.tertiaryContainer), overflow: TextOverflow.ellipsis)),
      ]);

  Widget _shortcut(IconData icon, Color color, String label, VoidCallback onTap) => Pressable(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.full), boxShadow: Shadows.tiny),
          child: Row(children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: T.labelMd),
          ]),
        ),
      );

  Future<void> _go(String path) async {
    await context.push(path);
    if (mounted) _load();
  }
}
