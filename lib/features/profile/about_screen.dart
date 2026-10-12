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
            Text('Send feedback', style: T.headlineMd),
            const SizedBox(height: 4),
            Text('The research team reads every message. ${_info['support_hours'] ?? ''}', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in const ['Question', 'Data and privacy', 'Bug report', 'Feature idea'])
                VChip(t, selected: topic == t, height: 34, onTap: () => set(() => topic = t)),
            ]),
            const SizedBox(height: Sp.sm),
            VTextField(controller: msg, hint: 'Write your message…', maxLines: 5),
            const SizedBox(height: Sp.md),
            PrimaryButton('Send', loading: sending, onTap: () async {
              if (msg.text.trim().isEmpty) {
                toast(ctx, 'Write a short message first.');
                return;
              }
              set(() => sending = true);
              try {
                await Repo.sendSupport(topic, msg.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) toast(context, "Thanks. We'll get back to you soon.");
              } catch (e) {
                set(() => sending = false);
                if (ctx.mounted) toast(ctx, 'Could not send. Please try again.', error: true);
              }
            }),
            const SizedBox(height: Sp.xs),
            TextLinkButton('Or email $_email', leading: Symbols.mail_rounded, onTap: () => launchUrl(Uri(scheme: 'mailto', path: _email, query: 'subject=VitalU support'))),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: TitleHeader('About', onLeading: () => goBack(context, '/profile')),
      children: [
        Column(children: [
          const SizedBox(height: Sp.sm),
          const AppIconTile(size: 72),
          const SizedBox(height: 12),
          Text('VitalU', style: T.headlineLg),
          const SizedBox(height: 2),
          Text('Student health companion', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text('Version ${_info['version'] ?? '1.0.0'}', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          if (_info['faculty'] != null) ...[
            const SizedBox(height: 8),
            Text(_info['faculty']!, textAlign: TextAlign.center, style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ],
        ]),
        ListGroup(children: [
          ListRow(
            icon: Symbols.science_rounded,
            color: AppColors.primary,
            title: 'About the research project',
            onTap: () => showInfoSheet(context, title: 'About the research project', icon: Symbols.science_rounded, paragraphs: [_info['about'] ?? 'Loading…', _info['ethics'] ?? '']),
          ),
          ListRow(
            icon: Symbols.lock_rounded,
            color: AppColors.tertiary,
            title: 'Privacy and data use',
            onTap: () => showInfoSheet(context, title: 'Privacy and data use', icon: Symbols.lock_rounded, paragraphs: [_info['privacy'] ?? 'Loading…']),
          ),
          ListRow(
            icon: Symbols.description_rounded,
            color: AppColors.onSurfaceVariant,
            title: 'Terms and study consent',
            onTap: () => showInfoSheet(context, title: 'Terms and study consent', icon: Symbols.description_rounded, paragraphs: [_info['terms'] ?? 'Loading…', _info['ethics'] ?? '']),
          ),
        ]),
        ListGroup(
          header: 'Support',
          footer: _info['support_hours'],
          children: [
            ListRow(icon: Symbols.local_hospital_rounded, color: AppColors.heart, title: 'University health services', onTap: () => context.push('/help')),
            ListRow(icon: Symbols.chat_rounded, color: AppColors.primary, title: 'Send feedback', onTap: _contact),
            ListRow(icon: Symbols.mail_rounded, color: AppColors.water, title: 'Email', value: _email, chevron: false, onTap: () => launchUrl(Uri(scheme: 'mailto', path: _email, query: 'subject=VitalU support'))),
          ],
        ),
        ListGroup(children: [
          ListRow(
            icon: Symbols.palette_rounded,
            color: AppColors.mind,
            title: 'Credits',
            subtitle: 'Illustrations and sounds',
            onTap: () => showInfoSheet(context, title: 'Credits', icon: Symbols.palette_rounded, paragraphs: const [
              'Illustrations by unDraw (undraw.co), used under the unDraw licence.',
              'Sounds: "Water Glass Pour", "Quick Win Success Fanfare" and "Peaceful Spa Bells" by BudgetPixel (budgetpixel.com), licensed under Creative Commons Attribution 4.0 (CC BY 4.0). The water sound has been shortened.',
              'Badge mascots and the body and cycle diagrams were drawn for VitalU.',
            ]),
          ),
        ]),
        Text('© ${DateTime.now().year} VitalU research project. For general wellbeing support, not a diagnostic tool.',
            textAlign: TextAlign.center, style: T.bodySm.c(AppColors.onSurfaceVariant)),
      ],
    );
  }
}
