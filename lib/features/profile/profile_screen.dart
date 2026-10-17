import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:intl/intl.dart';

import '../../core/app_state.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/badge_ui.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Profile hub: who you are at the top (tap for full account details), then
/// Account, Achievements, Summary, About This Project, Settings and Contact.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final p = AppState.instance.profile;
        if (p == null) return const Scaffold(body: Loading());
        return VPage(
          header: const MainHeader('Profile'),
          nav: NavTab.profile,
          topPadding: 0,
          children: [
            _ProfileHeader(profile: p),
            ListGroup(children: [
              _row(context, Symbols.person_rounded, AppColors.primary, 'Account', 'Your details, health background and measurements', '/profile/account'),
            ]),
            SectionHeader('Achievements', trailing: TextLinkButton('See all', icon: Symbols.chevron_right_rounded, onTap: () => context.push('/milestones'))),
            const _AchievementsStrip(),
            ListGroup(children: [
              _row(context, Symbols.monitoring_rounded, AppColors.mind, 'Summary', 'Your progress and personal health report', '/profile/summary'),
            ]),
            ListGroup(children: [
              _row(context, Symbols.science_rounded, AppColors.water, 'About This Project', 'The research behind VitalU', '/about'),
              _row(context, Symbols.settings_rounded, AppColors.onSurfaceVariant, 'Settings', 'Mode and sounds', '/settings'),
              _row(context, Symbols.mail_rounded, AppColors.nutrition, 'Contact Us', 'Reach the research team or send feedback', '/contact'),
            ]),
            ListGroup(children: [
              ListRow(
                icon: Symbols.logout_rounded,
                title: 'Sign out',
                destructive: true,
                chevron: false,
                onTap: () async {
                  await AppState.instance.signOut();
                  if (context.mounted) context.go('/auth/login');
                },
              ),
            ]),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, IconData icon, Color color, String title, String subtitle, String route) =>
      ListRow(icon: icon, color: color, title: title, subtitle: subtitle, onTap: () => context.push(route));
}

/// Photo, full name, username and faculty. The whole card opens the
/// account details screen.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final dark = AppColors.isDark;
    return Material(
      borderRadius: BorderRadius.circular(Rad.xl),
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Rad.xl),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
            Color.alphaBlend(AppColors.primary.withValues(alpha: dark ? 0.28 : 0.15), AppColors.surfaceContainerLowest),
            Color.alphaBlend(AppColors.water.withValues(alpha: dark ? 0.10 : 0.05), AppColors.surfaceContainerLowest),
          ]),
        ),
        child: InkWell(
          onTap: () => context.push('/profile/account'),
          child: Padding(
            padding: const EdgeInsets.all(Sp.md),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceContainerLowest),
                child: Avatar(size: 76, ring: false, onTap: () => context.push('/profile/account')),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.fullName, style: T.headlineMd, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (p.username != null) Text('@${p.username}', style: T.bodyMd.c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (p.faculty != null) ...[
                    const SizedBox(height: 6),
                    TagPill(p.faculty!.replaceFirst('Faculty of ', ''), icon: Symbols.school_rounded, bg: AppColors.surfaceContainerLowest, fg: AppColors.primary, fill: 1),
                  ],
                ]),
              ),
              Icon(Symbols.chevron_right_rounded, color: AppColors.outline),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Earned badges under the Achievements title, newest first, with the date
/// each was earned. Badges still to earn follow, greyed out.
class _AchievementsStrip extends StatefulWidget {
  const _AchievementsStrip();
  @override
  State<_AchievementsStrip> createState() => _AchievementsStripState();
}

class _AchievementsStripState extends State<_AchievementsStrip> {
  List<Rec>? _badges;
  Map<String, DateTime> _earned = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _badges = await Repo.badges();
    try {
      _earned = await Repo.earnedBadges();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final all = _badges;
    if (all == null) return const SizedBox(height: 132, child: Loading());
    final earned = all.where((b) => _earned.containsKey(b['code'])).toList()..sort((a, b) => _earned[b['code']]!.compareTo(_earned[a['code']]!));
    final locked = all.where((b) => !_earned.containsKey(b['code'])).toList();
    final list = [...earned, ...locked];
    if (list.isEmpty) return const SizedBox();
    return FullBleed(
      child: SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Sp.margin),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final b = list[i];
            final at = _earned[b['code']];
            return SizedBox(
              width: 92,
              child: InkWell(
                borderRadius: BorderRadius.circular(Rad.lg),
                onTap: () => at == null
                    ? context.push('/milestones')
                    : showBadgePopup(context, code: b['code'], title: b['title'], description: b['description'], icon: b['icon'], category: b['category']),
                child: Column(children: [
                  BadgeArt(code: b['code'], icon: b['icon'], category: b['category'], size: 76, locked: at == null),
                  const SizedBox(height: 4),
                  Text(b['title'], style: T.labelSm.semi.c(at == null ? AppColors.onSurfaceVariant : AppColors.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  Text(at == null ? 'Not yet' : DateFormat('d MMM yyyy').format(at.toLocal()), style: T.labelSm.c(AppColors.outline), maxLines: 1),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}
