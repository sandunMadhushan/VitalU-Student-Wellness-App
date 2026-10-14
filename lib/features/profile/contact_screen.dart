import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'about_screen.dart' show ResearchTeam;

/// Contact the developers: the student researcher's details, the research
/// team, and a feedback form that reaches the team inside the app.
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});
  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _msg = TextEditingController();
  String _topic = 'Question';
  bool _sending = false;

  @override
  void dispose() {
    _msg.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_msg.text.trim().isEmpty) return toast(context, 'Write a short message first.');
    setState(() => _sending = true);
    try {
      await Repo.sendSupport(_topic, _msg.text.trim());
      _msg.clear();
      if (mounted) toast(context, 'Thank you. Your message has been sent to the research team.');
    } catch (_) {
      if (mounted) toast(context, 'Could not send. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: TitleHeader('Contact Us', onLeading: () => goBack(context, '/profile')),
      children: [
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconCircle(Symbols.person_rounded, size: 44, iconSize: 24, fg: AppColors.primary, fill: 1),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ResearchTeam.researcher, style: T.headlineSm),
                  Text('Student Researcher', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            Text('${ResearchTeam.department}, ${ResearchTeam.faculty}, ${ResearchTeam.university}', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ]),
        ),
        ListGroup(children: [
          ListRow(
            icon: Symbols.mail_rounded,
            color: AppColors.nutrition,
            title: 'Email',
            subtitle: ResearchTeam.email,
            onTap: () => launchUrl(Uri(scheme: 'mailto', path: ResearchTeam.email, query: 'subject=VitalU')),
          ),
          ListRow(
            icon: Symbols.call_rounded,
            color: AppColors.primary,
            title: 'Telephone',
            subtitle: ResearchTeam.phone,
            onTap: () => launchUrl(Uri(scheme: 'tel', path: ResearchTeam.phone)),
          ),
        ]),
        ListGroup(header: 'Research team', dividerIndent: 60, children: [
          ListRow(icon: Symbols.school_rounded, color: AppColors.mind, title: ResearchTeam.supervisor, subtitle: 'Supervisor', chevron: false),
          ListRow(icon: Symbols.school_rounded, color: AppColors.mind, title: ResearchTeam.coSupervisor, subtitle: 'Co-supervisor', chevron: false),
        ]),
        const SectionHeader('Send feedback'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in const ['Question', 'Data and privacy', 'Bug report', 'Feature idea']) VChip(t, selected: _topic == t, selectedColor: AppColors.primary, height: 34, onTap: () => setState(() => _topic = t)),
        ]),
        VTextField(controller: _msg, hint: 'Write your message…', maxLines: 5),
        PrimaryButton('Send', leadingIcon: Symbols.send_rounded, loading: _sending, onTap: _send),
      ],
    );
  }
}
