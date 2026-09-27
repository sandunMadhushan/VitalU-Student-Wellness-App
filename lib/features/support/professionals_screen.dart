import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

const _cats = [
  ('all', 'All Care'),
  ('mental', 'Mental Health'),
  ('nutrition', 'Nutritionists'),
  ('cardiology', 'Cardiologists'),
  ('sleep', 'Sleep Coaches'),
  ('peer', 'Peer Navigators'),
];

Future<void> callNumber(BuildContext context, String? phone) async {
  if (phone == null || phone.trim().isEmpty) {
    toast(context, 'This number hasn\'t been added yet — please use the booking request instead.');
    return;
  }
  final ok = await launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
  if (!ok && context.mounted) toast(context, 'Could not open the dialler on this device.', error: true);
}

class ProfessionalsScreen extends StatefulWidget {
  const ProfessionalsScreen({super.key});
  @override
  State<ProfessionalsScreen> createState() => _ProfessionalsScreenState();
}

class _ProfessionalsScreenState extends State<ProfessionalsScreen> {
  bool _loading = true;
  List<Rec> _pros = [];
  List<Rec> _appts = [];
  Rec? _clinic;
  String _cat = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Repo.professionals(), Repo.appointments(), Repo.emergencyContacts()]);
      _pros = r[0];
      _appts = r[1];
      _clinic = r[2].where((e) => e['icon'] == 'local_hospital').firstOrNull;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  bool get _clinicOpen {
    final n = DateTime.now();
    return n.weekday <= DateTime.friday && n.hour >= 8 && n.hour < 18;
  }

  Future<void> _request({Rec? pro, required String service, bool chat = false}) async {
    final note = TextEditingController();
    DateTime date = DateTime.now().add(const Duration(days: 1));
    String slot = 'Morning';
    var sending = false;
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(chat ? 'Start a conversation' : 'Request a visit', style: T.headlineMd),
            const SizedBox(height: 4),
            Text(pro == null ? service : '${pro['name']} • ${pro['specialty']}', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            if (!chat) ...[
              Text('Preferred day', style: T.labelMd),
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (int i = 0; i < 10; i++)
                    Builder(builder: (_) {
                      final d = DateUtils.dateOnly(DateTime.now()).add(Duration(days: i));
                      final sel = DateUtils.isSameDay(d, date);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Pressable(
                          onTap: () => set(() => date = d),
                          child: Container(
                            width: 56,
                            decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.base)),
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(DateFormat('EEE').format(d), style: T.labelSm.c(sel ? AppColors.onPrimary : AppColors.onSurfaceVariant)),
                              Text('${d.day}', style: T.headlineSm.c(sel ? AppColors.onPrimary : AppColors.onSurface)),
                            ]),
                          ),
                        ),
                      );
                    }),
                ]),
              ),
              const SizedBox(height: Sp.sm),
              Segmented(options: const ['Morning', 'Afternoon', 'Evening'], value: slot, onChanged: (v) => set(() => slot = v)),
              const SizedBox(height: Sp.md),
            ],
            VTextField(controller: note, hint: chat ? 'What would you like to talk about?' : 'Anything they should know? (optional)', maxLines: 3),
            const SizedBox(height: Sp.md),
            PrimaryButton(chat ? 'Send Message' : 'Send Request', leadingIcon: chat ? Symbols.send : Symbols.event, loading: sending, onTap: () async {
              if (chat && note.text.trim().isEmpty) {
                toast(ctx, 'Write a short message first');
                return;
              }
              set(() => sending = true);
              final hour = switch (slot) { 'Morning' => 9, 'Afternoon' => 14, _ => 17 };
              try {
                await Repo.requestAppointment(
                  professionalId: pro?['id'],
                  service: pro?['specialty'] ?? service,
                  kind: chat ? 'chat' : 'booking',
                  preferred: chat ? null : DateTime(date.year, date.month, date.day, hour),
                  message: note.text.trim().isEmpty ? null : note.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) toast(context, chat ? 'Message sent — expect a reply soon 💬' : 'Request sent — you\'ll get a confirmation soon 📅');
                _load();
              } catch (_) {
                set(() => sending = false);
                if (ctx.mounted) toast(ctx, 'Could not send. Please try again.', error: true);
              }
            }),
            const SizedBox(height: Sp.xs),
            const PrivacyNote('Private between you and the care team'),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final shown = _pros.where((p) => _cat == 'all' || p['category'] == _cat).toList();
    final roster = shown.where((p) => p['mode'] != 'chat').toList();
    final peers = shown.where((p) => p['mode'] == 'chat').toList();
    final upcoming = _appts.where((a) => a['status'] == 'requested' || a['status'] == 'confirmed').toList();

    return VPage(
      header: const TwoLineHeader(kicker: 'VitalU Sanctuary', title: 'Sanctuary Tools'),
      nav: NavTab.tools,
      onRefresh: _load,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TagPill('Confidential Student Care • Privacy Protected', icon: Symbols.verified_user, bg: AppColors.secondaryFixed.withValues(alpha: 0.5), fg: AppColors.onSecondaryFixedVariant, iconColor: AppColors.secondary),
          const SizedBox(height: Sp.sm),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Talk to a Professional', style: T.headlineMd),
                Text('Gentle support whenever life feels a little loud', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
            CircleButton(Symbols.help, bg: AppColors.primaryFixed, fg: AppColors.primary, size: 40, iconSize: 20, onTap: () => context.push('/help')),
          ]),
        ]),
        Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.lg),
            gradient: LinearGradient(colors: [AppColors.primaryFixed.withValues(alpha: 0.6), AppColors.secondaryFixed.withValues(alpha: 0.4)]),
            boxShadow: Shadows.card,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              TagPill('Free for Students', icon: Symbols.check_circle, bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixedVariant, iconColor: AppColors.tertiary),
              const Spacer(),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _clinicOpen ? AppColors.tertiary : AppColors.outline, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(_clinicOpen ? 'Open until 6:00 PM' : 'Opens weekdays 8:00 AM', style: T.labelSm),
            ]),
            const SizedBox(height: Sp.sm),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('University Health Centre', style: T.headlineSm),
                  const SizedBox(height: 2),
                  Text('On-campus clinic & same-day urgent student triage', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Symbols.location_on, size: 16, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Flexible(child: Text('University Health Centre • Main Campus', style: T.labelSm.c(AppColors.onSurfaceVariant).w(FontWeight.w500))),
                  ]),
                ]),
              ),
              const SizedBox(width: Sp.sm),
              const SizedBox(width: 84, height: 84, child: AssetImg('stethoscope_rose', radius: 20)),
            ]),
            const SizedBox(height: Sp.md),
            Row(children: [
              Expanded(child: PrimaryButton('Book Visit', leadingIcon: Symbols.calendar_add_on, height: 48, textStyle: T.labelMd.c(AppColors.onPrimary), onTap: () => _request(service: 'University Health Centre visit'))),
              const SizedBox(width: 8),
              Expanded(
                  child: SoftButton('Chat Nurse',
                      icon: Symbols.chat_bubble, height: 48, color: AppColors.surfaceContainerLowest, iconColor: AppColors.primary, style: T.labelMd, onTap: () => _request(service: 'Nurse chat', chat: true))),
              const SizedBox(width: 8),
              CircleButton(Symbols.call, size: 48, iconSize: 20, bg: AppColors.surfaceContainerLowest, fg: AppColors.secondary, shadow: Shadows.tiny, onTap: () => callNumber(context, _clinic?['phone'])),
            ]),
          ]),
        ),
        FullBleed(
          child: ChipRow(children: [
            for (final c in _cats)
              Pressable(
                onTap: () => setState(() => _cat = c.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: _cat == c.$1 ? AppColors.inverseSurface : AppColors.surfaceContainer, borderRadius: BorderRadius.circular(Rad.full)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(c.$2, style: T.labelMd.c(_cat == c.$1 ? AppColors.inverseOnSurface : AppColors.onSurfaceVariant)),
                    if (c.$1 == 'all') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.surfaceContainerLowest.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                        child: Text('${_pros.length}', style: T.labelSm.c(_cat == c.$1 ? AppColors.inverseOnSurface : AppColors.onSurfaceVariant)),
                      ),
                    ],
                  ]),
                ),
              ),
          ]),
        ),
        if (_loading) const Loading(),
        if (!_loading && shown.isEmpty) const EmptyState(icon: Symbols.person_search, title: 'No one listed here yet', text: 'Try another category or book the Health Centre.'),
        for (final p in roster) _proCard(p),
        for (final p in peers)
          VCard(
            shadow: Shadows.card,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Symbols.groups, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(child: Text(p['name'], style: T.headlineSm)),
              ]),
              const SizedBox(height: 4),
              TagPill(p['specialty'] ?? '', bg: AppColors.secondaryFixed.withValues(alpha: 0.5), fg: AppColors.onSecondaryFixedVariant),
              const SizedBox(height: Sp.sm),
              Row(children: [
                const Icon(Symbols.bolt, size: 18, color: AppColors.tertiary),
                const SizedBox(width: 6),
                Expanded(child: Text(p['availability'] ?? '', style: T.bodySm.c(AppColors.onSurfaceVariant))),
                PrimaryButton('Live Chat', leadingIcon: Symbols.forum, height: 44, expand: false, color: AppColors.inverseSurface, textStyle: T.labelMd.c(AppColors.inverseOnSurface), onTap: () => _request(pro: p, service: 'Peer chat', chat: true)),
              ]),
            ]),
          ),
        if (upcoming.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Your requests', style: T.headlineSm),
            const SizedBox(height: Sp.sm),
            for (final a in upcoming)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: VCard(
                  color: AppColors.surfaceContainerLow,
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    IconCircle(a['kind'] == 'chat' ? Symbols.chat : Symbols.event, size: 40, iconSize: 20),
                    const SizedBox(width: Sp.sm),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text((a['professionals'] as Map?)?['name'] ?? a['service'] ?? 'Care request', style: T.labelLg),
                        Text(
                            a['preferred_at'] != null
                                ? 'Preferred ${DateFormat('EEE d MMM, h a').format(DateTime.parse(a['preferred_at']).toLocal())}'
                                : 'Sent ${DateFormat('d MMM').format(DateTime.parse(a['created_at']).toLocal())}',
                            style: T.bodySm.c(AppColors.onSurfaceVariant)),
                      ]),
                    ),
                    TagPill(a['status'] == 'confirmed' ? 'Confirmed' : 'Requested',
                        bg: a['status'] == 'confirmed' ? AppColors.tertiaryFixed : AppColors.surfaceContainerHigh, fg: a['status'] == 'confirmed' ? AppColors.onTertiaryFixedVariant : AppColors.onSurfaceVariant),
                  ]),
                ),
              ),
          ]),
        VCard(
          color: AppColors.secondaryFixed.withValues(alpha: 0.35),
          border: Border.all(color: AppColors.secondaryFixed),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Symbols.emergency, color: AppColors.error),
              const SizedBox(width: 8),
              Text('24/7 Student Safety Net', style: T.headlineSm.c(AppColors.onSecondaryFixedVariant)),
            ]),
            const SizedBox(height: 6),
            Text('If you or someone around you is in immediate emotional or medical distress, you are never alone.', style: T.bodySm.c(AppColors.onSecondaryFixedVariant)),
            const SizedBox(height: Sp.sm),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _safety(Symbols.call, 'Call 1926 (Mental Health)', () => callNumber(context, '1926')),
              _safety(Symbols.support_agent, 'Call 1333 (CCCline)', () => callNumber(context, '1333')),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _safety(IconData icon, String label, VoidCallback onTap) => Pressable(
        onTap: onTap,
        child: Pill(
          color: AppColors.surfaceContainerLowest,
          shadow: Shadows.tiny,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: AppColors.error),
            const SizedBox(width: 6),
            Text(label, style: T.labelSm),
          ]),
        ),
      );

  Widget _proCard(Rec p) {
    final modeIcon = switch (p['mode']) {
      'virtual' => Symbols.videocam,
      'dropin' => Symbols.hourglass_bottom,
      _ => Symbols.location_on,
    };
    final name = p['credentials'] == null ? p['name'] : '${p['name']}, ${p['credentials']}';
    return VCard(
      shadow: Shadows.card,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(120), bottom: Radius.circular(24)),
          child: SizedBox(
            height: 240,
            child: Stack(fit: StackFit.expand, children: [
              p['photo_key'] != null
                  ? AssetImg(p['photo_key'], alignment: Alignment.topCenter)
                  : Container(color: AppColors.primaryFixed, child: const Icon(Symbols.person, size: 64, color: AppColors.primary)),
              Positioned(
                right: 14,
                bottom: 14,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: AppColors.tertiaryContainer, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: Sp.sm),
        Text(name, style: T.headlineSm),
        const SizedBox(height: 4),
        Align(alignment: Alignment.centerLeft, child: TagPill(p['specialty'] ?? '', bg: AppColors.secondaryFixed.withValues(alpha: 0.5), fg: AppColors.onSecondaryFixedVariant)),
        const SizedBox(height: Sp.sm),
        Row(children: [
          Icon(modeIcon, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(p['availability'] ?? '', style: T.bodySm.c(AppColors.onSurfaceVariant))),
          CircleButton(Symbols.chat, size: 40, iconSize: 18, bg: AppColors.primaryFixed, fg: AppColors.primary, onTap: () => _request(pro: p, service: p['specialty'] ?? 'Consultation', chat: true)),
          const SizedBox(width: 8),
          PrimaryButton('Book', leadingIcon: Symbols.event, height: 40, expand: false, textStyle: T.labelMd.c(AppColors.onPrimary), onTap: () => _request(pro: p, service: p['specialty'] ?? 'Consultation')),
        ]),
      ]),
    );
  }
}
