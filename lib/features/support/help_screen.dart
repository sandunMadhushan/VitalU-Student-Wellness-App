import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'professionals_screen.dart';

/// Fallback list in case the device is offline — Sri Lankan national lines.
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
      header: const ConfidentialHeader(),
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, size: 52, bg: AppColors.surfaceContainerLowest, fg: AppColors.onSurface, shadow: Shadows.card, onTap: () => goBack(context)),
          const SizedBox(width: Sp.sm),
          Expanded(child: Text('Need Help Now?', style: T.headlineSm.s(20))),
          Pill(
            color: AppColors.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('24/7 Active', style: T.labelSm),
            ]),
          ),
        ]),
        Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.lg),
            gradient: const LinearGradient(colors: [AppColors.secondaryFixed, AppColors.surfaceContainerLow]),
            boxShadow: Shadows.soft,
          ),
          child: Row(children: [
            const SizedBox(width: 120, height: 120, child: AssetImg('campus_safety', radius: 24)),
            const SizedBox(width: Sp.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TagPill('Immediate Care & Safety', icon: Symbols.verified_user, bg: AppColors.surfaceContainerLowest, fg: AppColors.secondary, iconColor: AppColors.secondary),
                const SizedBox(height: 6),
                Text('Verified help is ready.', style: T.headlineSm.s(20)),
                const SizedBox(height: 2),
                Text('Medical assistance, mental wellness, or urgent support anytime you need.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
        Pressable(
          onTap: () => _act(hero),
          child: Container(
            padding: const EdgeInsets.all(Sp.md + 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Rad.lg),
              gradient: const LinearGradient(colors: [Color(0xFF9B3E63), AppColors.pinkAccent]),
              boxShadow: Shadows.tinted(AppColors.secondary, opacity: 0.35, blur: 28, y: 12),
            ),
            child: Row(children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Symbols.call, size: 30, color: AppColors.secondary),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text((hero['badge'] ?? 'Highest Priority').toString().toUpperCase(), style: T.labelSm.c(Colors.white.withValues(alpha: 0.85)).tracking(0.6)),
                  Text('Call ${hero['phone']}', style: T.headlineMd.c(Colors.white), overflow: TextOverflow.ellipsis),
                  Text(hero['title'] ?? '', style: T.bodySm.c(Colors.white.withValues(alpha: 0.9)), overflow: TextOverflow.ellipsis),
                ]),
              ),
              Pill(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(hero['action_label'] ?? 'Tap to Call', style: T.labelMd.c(AppColors.secondary)),
                  const SizedBox(width: 4),
                  const Icon(Symbols.arrow_forward, size: 16, color: AppColors.secondary),
                ]),
              ),
            ]),
          ),
        ),
        for (final c in rest) _card(c),
        VCard(
          shadow: Shadows.card,
          padding: const EdgeInsets.all(Sp.lg),
          child: Column(children: [
            const IconCircle(Symbols.favorite, size: 40, iconSize: 20, bg: AppColors.secondaryFixed, fg: AppColors.secondary),
            const SizedBox(height: Sp.sm),
            Text('You are not alone.', style: T.headlineSm.s(20)),
            const SizedBox(height: 6),
            Text('Taking this moment is brave. Responders and campus counsellors are gentle, discreet, and here unconditionally.',
                textAlign: TextAlign.center, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          ]),
        ),
        const PrivacyNote('Calls go straight through your phone\'s dialler. VitalU never records who you call or when.', icon: Symbols.shield, center: false),
      ],
    );
  }

  Widget _card(Rec c) {
    final phone = (c['phone'] as String?) ?? '';
    final (iconBg, iconFg, btnBg, btnFg, badgeBg) = switch (c['tone']) {
      'secondary' => (AppColors.primaryFixed, AppColors.primary, AppColors.primary, AppColors.onPrimary, AppColors.tertiaryFixed.withValues(alpha: 0.5)),
      'tertiary' => (AppColors.surfaceContainerHigh, AppColors.onSurfaceVariant, AppColors.inverseSurface, AppColors.inverseOnSurface, AppColors.surfaceContainerHigh),
      _ => (AppColors.secondaryFixed, AppColors.secondary, AppColors.secondaryFixed, AppColors.onSecondaryFixedVariant, AppColors.surfaceContainerHigh),
    };
    return VCard(
      color: AppColors.surfaceContainerLow,
      shadow: Shadows.soft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconCircle(iconByName(c['icon']), size: 52, bg: iconBg, fg: iconFg),
          const SizedBox(width: Sp.md - 4),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Text(c['title'] ?? '', style: T.headlineSm.s(20).lh(1.3))),
                if (c['badge'] != null) ...[const SizedBox(width: 6), TagPill(c['badge'], bg: badgeBg, fg: AppColors.onSurfaceVariant)],
              ]),
              const SizedBox(height: 4),
              Text(c['description'] ?? '', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
        ]),
        const SizedBox(height: Sp.md),
        Row(children: [
          Expanded(child: Text(phone.isEmpty ? 'Number to be added' : phone, style: T.bodyMd.c(AppColors.onSurfaceVariant))),
          PrimaryButton(c['action_label'] ?? 'Call Now',
              leadingIcon: Symbols.call, height: 48, expand: false, color: btnBg, fg: btnFg, textStyle: T.labelLg.c(btnFg), onTap: () => _act(c)),
        ]),
      ]),
    );
  }
}
