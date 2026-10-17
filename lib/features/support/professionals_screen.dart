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
  ('all', 'All'),
  ('medical', 'Doctors'),
  ('std', 'Sexual health'),
  ('nursing', 'Nursing'),
  ('mental', 'Mental health'),
  ('nutrition', 'Nutrition'),
  ('physio', 'Physiotherapy'),
];

/// The University Health Centre, open 24 hours.
const healthCentrePhone = '0812392022';

/// The consultation services, by designation. Names and direct numbers are
/// added in the database (`professionals`) as they are confirmed.
const consultationRoles = <Map<String, dynamic>>[
  {'name': 'Chief Medical Officer', 'specialty': 'Leads the University Health Centre. Medical concerns, referrals and certificates.', 'category': 'medical', 'availability': 'University Health Centre', 'mode': 'campus', 'phone': healthCentrePhone},
  {'name': 'Medical Doctors', 'specialty': 'Illness, injuries, check-ups and follow-up care.', 'category': 'medical', 'availability': 'University Health Centre · open 24/7', 'mode': 'campus', 'phone': healthCentrePhone},
  {'name': 'Medical Doctor, STD Division', 'specialty': 'Confidential sexual health advice, testing and treatment.', 'category': 'std', 'availability': 'STD Clinic, National Hospital Kandy', 'mode': 'campus'},
  {'name': 'Head Nurse', 'specialty': 'Nursing care, dressings, vaccinations and first aid.', 'category': 'nursing', 'availability': 'University Health Centre · open 24/7', 'mode': 'campus', 'phone': healthCentrePhone},
  {'name': 'Psychologist', 'specialty': 'Assessment and therapy for stress, anxiety and low mood.', 'category': 'mental', 'availability': 'By appointment', 'mode': 'campus'},
  {'name': 'Counsellor', 'specialty': 'A confidential space to talk through personal and study worries.', 'category': 'mental', 'availability': 'By appointment or drop-in', 'mode': 'campus'},
  {'name': 'Nutritionist', 'specialty': 'Healthy eating, weight goals and budget-friendly meal planning.', 'category': 'nutrition', 'availability': 'By appointment', 'mode': 'campus'},
  {'name': 'Dietitian', 'specialty': 'Diets for conditions such as diabetes, PCOS, anaemia or high cholesterol.', 'category': 'nutrition', 'availability': 'By appointment', 'mode': 'campus'},
  {'name': 'Physiotherapist', 'specialty': 'Sports injuries, back and neck pain, posture and rehabilitation.', 'category': 'physio', 'availability': 'By appointment', 'mode': 'campus'},
];

Future<void> callNumber(BuildContext context, String? phone) async {
  if (phone == null || phone.trim().isEmpty) {
    toast(context, "This number isn't listed yet. Send a booking request instead.");
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
      // Until the directory is updated in the database, show the designations.
      if (!_pros.any((p) => const {'medical', 'std', 'nursing', 'physio'}.contains(p['category']))) _pros = consultationRoles;
      _appts = r[1];
      _clinic = r[2].where((e) => e['icon'] == 'local_hospital').firstOrNull;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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
            Text(pro == null ? service : '${pro['name']} · ${pro['specialty']}', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            if (!chat) ...[
              Text('Preferred day', style: T.labelLg.semi),
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
                            decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(Rad.base)),
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
            PrimaryButton(chat ? 'Send message' : 'Send request', loading: sending, onTap: () async {
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
                if (mounted) toast(context, chat ? 'Message sent. Expect a reply soon.' : "Request sent. You'll get a confirmation soon.");
                _load();
              } catch (_) {
                set(() => sending = false);
                if (ctx.mounted) toast(ctx, 'Could not send. Please try again.', error: true);
              }
            }),
            const SizedBox(height: Sp.xs),
            const PrivacyNote('Private between you and the care team.'),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final shown = _pros.where((p) => _cat == 'all' || p['category'] == _cat).toList();
    final upcoming = _appts.where((a) => a['status'] == 'requested' || a['status'] == 'confirmed').toList();

    return VPage(
      header: const TitleHeader('Talk to a professional'),
      onRefresh: _load,
      children: [
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconCircle(Symbols.local_hospital_rounded, size: 44, iconSize: 22, fg: AppColors.heart, fill: 1),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('University Health Centre', style: T.headlineSm),
                  const SizedBox(height: 2),
                  Text('Main campus · free for students', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('Open 24/7 · 081 239 2022', style: T.labelMd.c(AppColors.tertiary)),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: Sp.md),
            Row(children: [
              Expanded(child: FilledButton(onPressed: () => _request(service: 'University Health Centre visit'), child: const Text('Book a visit'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: () => _request(service: 'Nurse chat', chat: true), child: const Text('Message'))),
              const SizedBox(width: 8),
              IconButton.filledTonal(tooltip: 'Call the health centre', style: IconButton.styleFrom(minimumSize: const Size(52, 52)), icon: const Icon(Symbols.call_rounded), onPressed: () => callNumber(context, (_clinic?['phone'] as String?)?.isNotEmpty == true ? _clinic!['phone'] : healthCentrePhone)),
            ]),
          ]),
        ),
        FullBleed(
          child: ChipRow(children: [
            for (final c in _cats) VChip(c.$2, selected: _cat == c.$1, onTap: () => setState(() => _cat = c.$1)),
          ]),
        ),
        if (_loading) const Loading(),
        if (!_loading && shown.isEmpty) const EmptyState(icon: Symbols.person_search_rounded, title: 'No one listed here yet', text: 'Try another category or book the health centre.'),
        Text('Names and direct contacts for each service will be added soon.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
        for (final p in shown) _proCard(p),
        if (upcoming.isNotEmpty)
          ListGroup(header: 'Your requests', children: [
            for (final a in upcoming)
              ListRow(
                icon: a['kind'] == 'chat' ? Symbols.chat_rounded : Symbols.event_rounded,
                color: AppColors.primary,
                title: (a['professionals'] as Map?)?['name'] ?? a['service'] ?? 'Care request',
                subtitle: a['preferred_at'] != null
                    ? 'Preferred ${DateFormat('EEE d MMM, h a').format(DateTime.parse(a['preferred_at']).toLocal())}'
                    : 'Sent ${DateFormat('d MMM').format(DateTime.parse(a['created_at']).toLocal())}',
                trailing: TagPill(a['status'] == 'confirmed' ? 'Confirmed' : 'Pending',
                    bg: a['status'] == 'confirmed' ? AppColors.tint(AppColors.tertiary) : AppColors.surfaceContainerHigh, fg: a['status'] == 'confirmed' ? AppColors.tertiary : AppColors.onSurfaceVariant),
              ),
          ]),
        ListGroup(children: [
          ListRow(icon: Symbols.emergency_rounded, destructive: true, title: 'Need help right now?', subtitle: 'Emergency and crisis lines, 24/7', onTap: () => context.push('/help')),
        ]),
      ],
    );
  }

  Widget _proCard(Rec p) {
    final chatOnly = p['mode'] == 'chat';
    final modeIcon = switch (p['mode']) {
      'virtual' => Symbols.videocam_rounded,
      'dropin' => Symbols.door_open_rounded,
      'chat' => Symbols.forum_rounded,
      _ => Symbols.location_on_rounded,
    };
    final name = p['credentials'] == null ? p['name'] as String : '${p['name']}, ${p['credentials']}';
    final (roleIcon, c) = switch (p['category']) {
      'mental' => (Symbols.psychology_rounded, AppColors.mind),
      'nutrition' => (Symbols.restaurant_rounded, AppColors.nutrition),
      'std' => (Symbols.health_and_safety_rounded, AppColors.cycle),
      'nursing' => (Symbols.vaccines_rounded, AppColors.water),
      'physio' => (Symbols.physical_therapy_rounded, AppColors.activity),
      'cardiology' => (Symbols.cardiology_rounded, AppColors.heart),
      _ => (Symbols.stethoscope_rounded, AppColors.primary),
    };
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.tint(c), shape: BoxShape.circle),
            child: Icon(chatOnly ? Symbols.groups_rounded : roleIcon, color: c, fill: 1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: T.labelLg.semi),
              Text(p['specialty'] ?? '', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
              if (p['availability'] != null) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(modeIcon, size: 16, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(p['availability'], style: T.bodySm.c(AppColors.onSurfaceVariant))),
                ]),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: Sp.md),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => _request(pro: p, service: chatOnly ? 'Peer chat' : (p['specialty'] ?? 'Consultation'), chat: true),
              icon: const Icon(Symbols.chat_rounded, size: 18),
              label: const Text('Message'),
            ),
          ),
          if ((p['phone'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(width: 8),
            IconButton.filledTonal(tooltip: 'Call', style: IconButton.styleFrom(minimumSize: const Size(44, 44)), icon: const Icon(Symbols.call_rounded, size: 20), onPressed: () => callNumber(context, p['phone'])),
          ],
          if (!chatOnly) ...[
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => _request(pro: p, service: p['specialty'] ?? 'Consultation'),
                icon: const Icon(Symbols.event_rounded, size: 18),
                label: const Text('Book'),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}
