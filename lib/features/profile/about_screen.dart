import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../tools/tool_widgets.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});
  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  Map<String, String> _info = {};

  @override
  void initState() {
    super.initState();
    Repo.appInfo().then((v) {
      if (mounted) setState(() => _info = v);
    }).catchError((_) {});
  }

  String get _email => _info['support_email'] ?? 'support@vitalu.lk';

  Future<void> _contact() async {
    final msg = TextEditingController();
    var topic = 'Question';
    var sending = false;
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Contact Support & Feedback', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('Our research coordinators read every message. ${_info['support_hours'] ?? ''}', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in const ['Question', 'Data & privacy', 'Bug report', 'Feature idea'])
                VChip(t, selected: topic == t, height: 34, onTap: () => set(() => topic = t)),
            ]),
            const SizedBox(height: Sp.sm),
            VTextField(controller: msg, hint: 'Write your message…', maxLines: 5),
            const SizedBox(height: Sp.md),
            PrimaryButton('Send Message', icon: Symbols.send, loading: sending, onTap: () async {
              if (msg.text.trim().isEmpty) {
                toast(ctx, 'Please write a short message first');
                return;
              }
              set(() => sending = true);
              try {
                await Repo.sendSupport(topic, msg.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) toast(context, 'Thanks — we\'ll get back to you soon 💜');
              } catch (e) {
                set(() => sending = false);
                if (ctx.mounted) toast(ctx, 'Could not send. Please try again.', error: true);
              }
            }),
            const SizedBox(height: Sp.xs),
            TextLinkButton('Or email $_email', leading: Symbols.mail, onTap: () => launchUrl(Uri(scheme: 'mailto', path: _email, query: 'subject=VitalU support'))),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      (Symbols.eco, AppColors.primaryFixed, AppColors.primary, 'About This Research Project', 'A collaborative digital health initiative for student life', null,
          () => showInfoSheet(context, title: 'About This Research Project', icon: Symbols.eco, paragraphs: [_info['about'] ?? 'Loading…', _info['ethics'] ?? ''])),
      (Symbols.verified_user, AppColors.tertiaryFixed, AppColors.tertiary, 'Privacy & Data Use', 'Row-level secured • You own your student data', 'Encrypted',
          () => showInfoSheet(context, title: 'Privacy & Data Use', icon: Symbols.verified_user, paragraphs: [_info['privacy'] ?? 'Loading…'])),
      (Symbols.local_hospital, AppColors.secondaryFixed, AppColors.secondary, 'University Health Services', 'Walk-in clinic, mental wellness & counselling contacts', null, () => context.push('/help')),
      (Symbols.chat_bubble, AppColors.primaryFixed, AppColors.primary, 'Contact Support & Feedback', 'Need help or want to suggest a gentle feature?', null, _contact),
      (Symbols.history_edu, AppColors.surfaceContainerHigh, AppColors.onSurfaceVariant, 'Terms & Study Consent', 'Participant agreement & academic ethics approval', null,
          () => showInfoSheet(context, title: 'Terms & Study Consent', icon: Symbols.history_edu, paragraphs: [_info['terms'] ?? 'Loading…', _info['ethics'] ?? ''])),
    ];

    return VPage(
      header: const MainHeader('Profile'),
      nav: NavTab.profile,
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, iconSize: 22, onTap: () => goBack(context, '/profile')),
          Expanded(
            child: Column(children: [
              Text('About & Support', style: T.headlineSm.s(20)),
              Text('App information & student care', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          CircleButton(Symbols.contact_support, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurfaceVariant, iconSize: 22, onTap: _contact),
        ]),
        Column(children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                width: 128,
                height: 128,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(Rad.lg), boxShadow: Shadows.card),
                child: const AssetImg('about_crest', radius: 24),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: AppColors.tertiaryFixed, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 3)),
                  child: Icon(Symbols.verified, size: 18, color: AppColors.tertiary, fill: 1),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          Text('VitalU', style: T.headlineLg.s(32)),
          const SizedBox(height: 4),
          Text('Student Wellness & Care Companion', style: T.bodyLg.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.sm),
          TagPill(_info['faculty'] ?? 'Faculty of Applied Sciences & Student Well-Being', icon: Symbols.school, bg: AppColors.primaryFixed, fg: AppColors.onPrimaryFixedVariant, iconColor: AppColors.primary),
          const SizedBox(height: Sp.sm),
          Text('Version ${_info['version'] ?? '1.0.0'}', style: T.labelMd.c(AppColors.outline)),
        ]),
        for (final it in items)
          VCard(
            shadow: Shadows.card,
            onTap: it.$7,
            child: Row(children: [
              IconCircle(it.$1, size: 52, bg: it.$2, fg: it.$3),
              const SizedBox(width: Sp.md - 4),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(it.$4, style: T.headlineSm.s(17).w(FontWeight.w500), overflow: TextOverflow.ellipsis)),
                    if (it.$6 != null) ...[
                      const SizedBox(width: 8),
                      TagPill(it.$6!, bg: AppColors.tertiaryFixed, fg: AppColors.onTertiaryFixedVariant),
                    ],
                  ]),
                  Text(it.$5, style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              Icon(Symbols.chevron_right, color: AppColors.outlineVariant),
            ]),
          ),
        VCard(
          color: AppColors.surfaceContainerLow,
          radius: Rad.lg,
          shadow: Shadows.tiny,
          padding: const EdgeInsets.all(Sp.md + 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconCircle(Symbols.support_agent, size: 40, iconSize: 22, bg: AppColors.primary, fg: AppColors.onPrimary),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Questions about your wellness data?', style: T.headlineSm.w(FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text('Our research coordinators are available ${_info['support_hours'] ?? 'Mon–Fri, 9am–5pm at the University Health Centre'} or via $_email',
                      style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
            ]),
            const SizedBox(height: Sp.md),
            Align(alignment: Alignment.centerRight, child: PrimaryButton('Send Message', leadingIcon: Symbols.mail, height: 48, expand: false, onTap: _contact)),
          ]),
        ),
        Column(children: [
          Text('Developed in partnership with the University Faculty of Applied Sciences & Campus Wellbeing Initiative.',
              textAlign: TextAlign.center, style: T.bodySm.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text('© ${DateTime.now().year} VitalU Research Project. For educational wellness support — not a diagnostic tool.',
              textAlign: TextAlign.center, style: T.labelSm.c(AppColors.outline).w(FontWeight.w400)),
        ]),
      ],
    );
  }
}
