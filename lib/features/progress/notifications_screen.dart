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
        'Health' => n['category'] == 'care' || n['category'] == 'insight' || n['category'] == 'nourishment',
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
            Text('Quiet hours', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('Reminders are held until quiet hours end.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
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
    final unread = _items.any((n) => n['read_at'] == null);

    return VPage(
      header: TitleHeader('Notifications', actions: [
        IconButton(
          tooltip: 'Mark all as read',
          icon: const Icon(Symbols.done_all_rounded),
          onPressed: unread
              ? () async {
                  await Repo.markAllRead();
                  _load();
                }
              : null,
        ),
      ]),
      onRefresh: _load,
      children: [
        SizedBox(
          width: double.infinity,
          child: Segmented(options: const ['All', 'Milestones', 'Reminders', 'Health'], value: _filter, onChanged: (v) => setState(() => _filter = v)),
        ),
        if (_loading) const Loading(),
        if (!_loading && list.isEmpty) const EmptyState(icon: Symbols.notifications_rounded, title: 'No notifications', text: 'Reminders and milestones will show up here.'),
        if (today.isNotEmpty) ListGroup(header: 'Today', dividerIndent: 68, children: [for (final n in today) _row(n)]),
        if (earlier.isNotEmpty) ListGroup(header: 'Earlier', dividerIndent: 68, children: [for (final n in earlier) _row(n)]),
        ListGroup(children: [
          ListRow(icon: Symbols.do_not_disturb_on_rounded, color: AppColors.sleep, title: 'Quiet hours', subtitle: 'No reminders while you sleep or study', onTap: _quietHours),
        ]),
      ],
    );
  }

  Widget _row(Rec n) {
    final unread = n['read_at'] == null;
    final fg = switch (n['category'] as String) {
      'milestone' => AppColors.primary,
      'care' => AppColors.mind,
      'nourishment' => AppColors.nutrition,
      'reminder' => AppColors.water,
      _ => AppColors.heart,
    };
    return InkWell(
      onTap: () async {
        if (unread) await Repo.markRead(n['id']);
        if (n['route'] != null && mounted) {
          await context.push(n['route']);
        }
        _load();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 14, Sp.md, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconCircle(iconByName(n['icon']), size: 40, iconSize: 20, fg: fg, fill: 1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(n['title'], style: T.bodyLg.w(unread ? FontWeight.w600 : FontWeight.w400))),
                const SizedBox(width: 8),
                Text(_ago(DateTime.parse(n['scheduled_for']).toLocal()), style: T.labelSm.c(AppColors.onSurfaceVariant)),
              ]),
              if (n['body'] != null) ...[
                const SizedBox(height: 2),
                Text(n['body'], style: T.bodyMd.c(AppColors.onSurfaceVariant), maxLines: 3, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          SizedBox(
            width: 16,
            child: unread
                ? Align(alignment: Alignment.topRight, child: Container(margin: const EdgeInsets.only(top: 6), width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)))
                : null,
          ),
        ]),
      ),
    );
  }
}
