import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../tools/tool_widgets.dart';

/// The research project, the team behind it and how to reach them.
class ResearchTeam {
  ResearchTeam._();
  static const title = 'Development of an ADDIE-Based Mobile Health Platform to Improve Cardiometabolic Health among Undergraduate Students';
  static const researcher = 'W. M. O. P. Wijesooriya';
  static const department = 'Department of Food Science and Technology';
  static const faculty = 'Faculty of Agriculture';
  static const university = 'University of Peradeniya';
  static const supervisor = 'Dr. G. M. Somaratne';
  static const coSupervisor = 'Prof. Terrance Madhujith';
  static const email = 'fst20052@agri.pdn.ac.lk';
  static const phone = '0777434769';
}

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

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: TitleHeader('About This Project', onLeading: () => goBack(context, '/profile')),
      children: [
        Column(children: [
          const SizedBox(height: Sp.sm),
          const AppIconTile(size: 72),
          const SizedBox(height: 12),
          Text('VitalU', style: T.headlineLg),
          Text('Version ${_info['version'] ?? '1.0.0'}', style: T.bodySm.c(AppColors.onSurfaceVariant)),
        ]),
        _card(Symbols.smartphone_rounded, AppColors.primary, 'About the application', [
          Text.rich(
            TextSpan(children: [
              const TextSpan(text: 'This application is being developed as part of the research project titled '),
              TextSpan(text: '"${ResearchTeam.title}."', style: const TextStyle(fontStyle: FontStyle.italic)),
              const TextSpan(
                  text: ' The platform aims to support the cardiometabolic health and overall well-being of university undergraduates through personalised nutrition guidance, dietary assessment, health monitoring and evidence-based lifestyle recommendations. It is designed to help students better understand their health, develop healthier dietary behaviours and monitor their progress.'),
            ]),
            style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.5),
          ),
        ]),
        _card(Symbols.science_rounded, AppColors.water, 'Research and development', [
          Text('This application is being developed as a student research project by:', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: 10),
          _fact('Student Researcher', ResearchTeam.researcher),
          _fact('Department', ResearchTeam.department),
          _fact('Faculty', ResearchTeam.faculty),
          _fact('University', ResearchTeam.university),
        ]),
        _card(Symbols.groups_rounded, AppColors.mind, 'Supervisory team', [
          _fact('Supervisor', ResearchTeam.supervisor),
          _fact('Co-supervisor', ResearchTeam.coSupervisor),
        ]),
        ListGroup(header: 'Contact the student researcher', children: [
          ListRow(
            icon: Symbols.mail_rounded,
            color: AppColors.nutrition,
            title: 'Email',
            value: ResearchTeam.email,
            chevron: false,
            onTap: () => launchUrl(Uri(scheme: 'mailto', path: ResearchTeam.email, query: 'subject=VitalU')),
          ),
          ListRow(
            icon: Symbols.call_rounded,
            color: AppColors.primary,
            title: 'Telephone',
            value: ResearchTeam.phone,
            chevron: false,
            onTap: () => launchUrl(Uri(scheme: 'tel', path: ResearchTeam.phone)),
          ),
        ]),
        ListGroup(children: [
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
          ListRow(icon: Symbols.mail_rounded, color: AppColors.nutrition, title: 'Contact Us', subtitle: 'Send feedback to the research team', onTap: () => context.push('/contact')),
        ]),
        Text(
          'Sounds: "Water Glass Pour", "Quick Win Success Fanfare" and "Peaceful Spa Bells" by BudgetPixel, CC BY 4.0 (water sound shortened, bells re-encoded). Illustrations created with Figma AI. For general well-being support, not a diagnostic tool.',
          textAlign: TextAlign.center,
          style: T.bodySm.c(AppColors.outline),
        ),
      ],
    );
  }

  Widget _card(IconData icon, Color c, String title, List<Widget> children) => VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconCircle(icon, size: 34, iconSize: 18, fg: c, radius: 10, fill: 1),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: T.headlineSm)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  Widget _fact(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 136, child: Text(label, style: T.labelMd.c(AppColors.onSurfaceVariant))),
          Expanded(child: Text(value, style: T.bodyMd.w(FontWeight.w600))),
        ]),
      );
}
