import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'professionals_screen.dart';

/// Fallback list in case the device is offline, Sri Lankan national lines.
const _fallback = <Rec>[
  {'title': 'Emergency Ambulance', 'badge': 'Highest Priority', 'description': '1990 Suwa Seriya • Free national pre-hospital ambulance', 'phone': '1990', 'action_label': 'Tap to Call', 'icon': 'call', 'tone': 'error'},
  {'title': 'National Mental Health Helpline', 'badge': 'Toll-Free', 'description': 'Confidential emotional support 24/7 • NIMH Sri Lanka', 'phone': '1926', 'action_label': 'Call 1926', 'icon': 'volunteer_activism', 'tone': 'secondary'},
  {'title': 'CCCline Crisis Support', 'badge': 'Confidential', 'description': 'Talk to a trained listener when things feel heavy', 'phone': '1333', 'action_label': 'Call 1333', 'icon': 'chat', 'tone': 'tertiary'},
];

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  List<Rec> _contacts = _fallback;

  @override
  void initState() {
    super.initState();
    Repo.emergencyContacts().then((v) {
      if (mounted && v.isNotEmpty) setState(() => _contacts = v);
    }).catchError((_) {});
  }

  Future<void> _act(Rec c) async {
    final sms = c['sms'] as String?;
    if (sms != null && sms.isNotEmpty && (c['phone'] == null || (c['phone'] as String).isEmpty)) {
      final ok = await launchUrl(Uri(scheme: 'sms', path: sms, queryParameters: c['sms_body'] == null ? null : {'body': c['sms_body']}));
      if (!ok && mounted) toast(context, 'Could not open messages on this device.', error: true);
      return;
    }
    await callNumber(context, c['phone']);
  }

  @override
  Widget build(BuildContext context) {
    final hero = _contacts.where((c) => c['tone'] == 'error').firstOrNull ?? _contacts.first;
    final rest = _contacts.where((c) => c != hero).toList();

    return VPage(
      header: const TitleHeader('Get help now'),
      children: [
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Symbols.emergency_rounded, size: 20, color: AppColors.error, fill: 1),
              const SizedBox(width: 8),
              Expanded(child: Text(hero['title'] ?? 'Emergency', style: T.labelLg.semi.c(AppColors.error))),
              Text('24/7', style: T.labelMd.c(AppColors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 8),
            Text('${hero['phone']}', style: T.metric(44)),
            if (hero['description'] != null) Text(hero['description'], style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            PrimaryButton('Call ${hero['phone']}', leadingIcon: Symbols.call_rounded, color: AppColors.error, fg: AppColors.onError, onTap: () => _act(hero)),
          ]),
        ),
        if (rest.isNotEmpty)
          ListGroup(header: 'Support lines', dividerIndent: 68, children: [for (final c in rest) _row(c)]),
        VCard(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.favorite_rounded, size: 22, color: AppColors.heart, fill: 1),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("You don't have to handle this alone", style: T.headlineSm),
                const SizedBox(height: 4),
                Text('Responders and university counsellors are trained to listen without judgement. Calls are confidential.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        const PrivacyNote("Calls go through your phone's dialler. VitalU never records who you call."),
      ],
    );
  }

  Widget _row(Rec c) {
    final phone = (c['phone'] as String?) ?? '';
    final fg = switch (c['tone']) {
      'secondary' => AppColors.mind,
      'tertiary' => AppColors.water,
      _ => AppColors.primary,
    };
    return InkWell(
      onTap: () => _act(c),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 12, 8, 12),
        child: Row(children: [
          IconCircle(iconByName(c['icon']), size: 40, iconSize: 20, fg: fg, fill: 1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['title'] ?? '', style: T.bodyLg),
              if (c['description'] != null) Text(c['description'], style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: phone.isEmpty && c['sms'] == null ? null : () => _act(c),
            icon: const Icon(Symbols.call_rounded, size: 18),
            label: Text(phone.isEmpty ? 'Text' : phone, style: T.labelLg.tnum),
          ),
        ]),
      ),
    );
  }
}
