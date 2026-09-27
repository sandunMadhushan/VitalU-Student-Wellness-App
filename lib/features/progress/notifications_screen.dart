import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<Rec> _items = [];
  String _filter = 'All';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _items = await Repo.notifications();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24 && t.day == DateTime.now().day) return '${d.inHours}h ago';
    if (d.inDays < 2) return 'Yesterday';
    return DateFormat('MMM d').format(t);
  }

  bool _match(Rec n) => switch (_filter) {
        'Milestones' => n['category'] == 'milestone',
        'Reminders' => n['category'] == 'reminder',
        'Care & Health' => n['category'] == 'care' || n['category'] == 'insight' || n['category'] == 'nourishment',
        _ => true,
      };

  Future<void> _quietHours() async {
    final p = AppState.instance.profile;
    TimeOfDay parse(String? s, TimeOfDay d) {
      if (s == null) return d;
      final x = s.split(':');
      return TimeOfDay(hour: int.parse(x[0]), minute: int.parse(x[1]));
    }

    var start = parse(p?.quietStart, const TimeOfDay(hour: 22, minute: 0));
    var end = parse(p?.quietEnd, const TimeOfDay(hour: 7, minute: 0));
    String f(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          Widget tile(String label, TimeOfDay t, ValueChanged<TimeOfDay> onPick) => Expanded(
                child: VCard(
                  color: AppColors.surfaceContainerLow,
                  onTap: () async {
                    final v = await showTimePicker(context: ctx, initialTime: t);
                    if (v != null) set(() => onPick(v));
                  },
                  child: Column(children: [Text(label, style: T.labelSm.c(AppColors.onSurfaceVariant)), const SizedBox(height: 4), Text(t.format(ctx), style: T.headlineSm)]),
                ),
              );
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Quiet Hours', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('VitalU will hold gentle reminders during these hours.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            Row(children: [tile('From', start, (v) => start = v), const SizedBox(width: Sp.sm), tile('Until', end, (v) => end = v)]),
            const SizedBox(height: Sp.md),
            PrimaryButton('Save', onTap: () async {
              await AppState.instance.updateProfile({'quiet_hours_start': f(start), 'quiet_hours_end': f(end)});
              if (ctx.mounted) Navigator.pop(ctx);
            }),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final list = _items.where(_match).toList();
    final today = list.where((n) => isoDate(DateTime.parse(n['scheduled_for']).toLocal()) == isoDate(DateTime.now())).toList();
    final earlier = list.where((n) => !today.contains(n)).toList();
    final unreadToday = today.where((n) => n['read_at'] == null).length;

    return VPage(
      header: const MainHeader('Vitalu   Your Progress & Trends'),
      nav: NavTab.progress,
      onRefresh: _load,
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainer, fg: AppColors.onSurface, shadow: Shadows.tiny, onTap: () => goBack(context)),
          Expanded(
            child: Column(children: [
              Text('Notifications', style: T.headlineSm),
              Text('Gentle updates & milestones', style: T.labelSm.c(AppColors.onSurfaceVariant).w(FontWeight.w400)),
            ]),
          ),
          CircleButton(Symbols.done_all, size: 40, iconSize: 20, bg: AppColors.surfaceContainer, shadow: Shadows.tiny, onTap: () async {
            await Repo.markAllRead();
            _load();
          }),
        ]),
        VCard(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.surfaceContainerLowest, AppColors.surfaceContainerLow, AppColors.secondaryFixed.withValues(alpha: 0.3)]),
          shadow: Shadows.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(alignment: Alignment.center, children: [
                  Glow(color: AppColors.primaryFixed.withValues(alpha: 0.4), size: 72),
                  const AssetImg('bell', width: 80, height: 80, radius: 40),
                ]),
              ),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TagPill('Peace of Mind', icon: Symbols.spa, bg: AppColors.surfaceContainerLowest.withValues(alpha: 0.8), fg: AppColors.primary),
                  const SizedBox(height: 4),
                  Text('Mindful Reminders', style: T.headlineSm.lh(1.2)),
                  Text('Only what matters for your self-care rhythm. No urgency or stress.', style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ]),
            const SizedBox(height: Sp.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in const ['All', 'Milestones', 'Reminders', 'Care & Health']) ...[
                  VChip(f, selected: _filter == f, selectedColor: AppColors.inverseSurface, selectedFg: AppColors.inverseOnSurface, height: 36, onTap: () => setState(() => _filter = f)),
                  const SizedBox(width: 6),
                ],
              ]),
            ),
          ]),
        ),
        if (_loading) const Loading(),
        if (!_loading && list.isEmpty) const EmptyState(icon: Symbols.notifications, title: 'All quiet here', text: 'Gentle reminders and milestones will appear here.'),
        if (today.isNotEmpty) ...[
          _sectionTitle('Today', unreadToday > 0 ? '$unreadToday new' : null),
          for (final n in today) _card(n),
        ],
        if (earlier.isNotEmpty) ...[
          _sectionTitle('Earlier', null),
          for (final n in earlier) _card(n),
        ],
        Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.lg),
            gradient: const LinearGradient(colors: [AppColors.surfaceContainerLow, AppColors.surfaceContainer]),
            boxShadow: Shadows.tiny,
          ),
          child: Row(children: [
            IconCircle(Symbols.notifications_paused, size: 40, iconSize: 20, shadow: Shadows.tiny),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Manage quiet hours', style: T.labelMd),
                Text('Tailor frequency to study schedules', style: T.bodySm.c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
              ]),
            ),
            Pressable(
              onTap: _quietHours,
              child: Pill(
                color: AppColors.surfaceContainerLowest,
                shadow: Shadows.tiny,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Adjust', style: T.labelMd.c(AppColors.primary)),
                  const Icon(Symbols.chevron_right, size: 16, color: AppColors.primary),
                ]),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t, String? trailing) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(children: [
          Expanded(child: Text(t.toUpperCase(), style: T.labelMd.c(AppColors.onSurfaceVariant).tracking(1))),
          if (trailing != null) Text(trailing, style: T.labelSm.c(AppColors.primary)),
        ]),
      );

  Widget _card(Rec n) {
    final unread = n['read_at'] == null;
    final cat = n['category'] as String;
    final (bg, fg) = switch (cat) {
      'milestone' => (AppColors.tertiaryFixed.withValues(alpha: 0.5), AppColors.tertiary),
      'care' => (AppColors.secondaryFixed, AppColors.secondary),
      'nourishment' => (AppColors.tertiaryFixed, AppColors.tertiary),
      _ => (AppColors.primaryFixed, AppColors.primary),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.sm),
      child: VCard(
        color: unread ? AppColors.surfaceContainerLowest : AppColors.surfaceContainerLow.withValues(alpha: 0.7),
        shadow: unread ? Shadows.card : Shadows.tiny,
        onTap: () async {
          if (unread) await Repo.markRead(n['id']);
          if (n['route'] != null && mounted) {
            await context.push(n['route']);
          }
          _load();
        },
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(color: unread ? fg : Colors.transparent, shape: BoxShape.circle, boxShadow: unread ? [BoxShadow(color: fg.withValues(alpha: 0.6), blurRadius: 8)] : null),
          ),
          const SizedBox(width: Sp.sm),
          IconCircle(iconByName(n['icon']), size: 44, bg: unread ? bg : AppColors.surfaceContainerHighest, fg: fg, shadow: Shadows.tiny),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: TagPill(n['label'] ?? cat[0].toUpperCase() + cat.substring(1), bg: unread ? bg.withValues(alpha: 0.6) : AppColors.surfaceContainerHighest, fg: unread ? fg : AppColors.onSurfaceVariant)),
                const Spacer(),
                Text(_ago(DateTime.parse(n['scheduled_for']).toLocal()), style: T.labelSm.c(AppColors.outline)),
              ]),
              const SizedBox(height: 4),
              Text(n['title'], style: T.headlineSm.s(16).lh(1.3)),
              if (n['body'] != null) ...[const SizedBox(height: 4), Text(n['body'], style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6))],
            ]),
          ),
        ]),
      ),
    );
  }
}
