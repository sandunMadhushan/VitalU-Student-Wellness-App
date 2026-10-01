import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../data/models.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../home/home_screen.dart' show bodyMetricTiles;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _waterMl = 0;
  int _mealsToday = 0;
  int _diversityToday = 0;
  int _steps = 0;
  int? _sleepMinutes;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    try {
      final now = DateTime.now();
      final today = isoDate(now);
      final results = await Future.wait([
        Repo.waterTotal(now),
        Repo.mealsOn(now),
        Repo.diversityBetween(weekStart(now), now),
        Repo.activityTotals(now),
        Repo.sleepLatest(),
      ]);
      if (!mounted) return;
      setState(() {
        _waterMl = results[0] as int;
        _mealsToday = (results[1] as List).length;
        _diversityToday = (results[2] as List).where((r) => r['log_date'] == today).map((r) => r['food_group']).toSet().length;
        _steps = (results[3] as Rec)['steps'] as int;
        final s = results[4] as Rec?;
        _sleepMinutes = (s != null && now.difference(DateTime.parse(s['sleep_date'])).inDays <= 1) ? Repo.sleepMinutes(s) : null;
      });
    } catch (_) {}
  }

  Future<void> _avatar() async {
    late final XFile? x;
    try {
      // On web, image_picker resizes via an in-browser canvas when maxWidth/imageQuality
      // are set; that resize silently fails for some photo formats (e.g. HEIC), so the
      // file picker never returns and the tap looks like it does nothing. Skip resizing
      // on web and let the server-side upload handle the original bytes instead.
      x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: kIsWeb ? null : 512, imageQuality: kIsWeb ? null : 85);
    } catch (e) {
      if (mounted) toast(context, 'Could not open your photo library: $e', error: true);
      return;
    }
    if (x == null) return;
    try {
      // A backgrounded app can miss its automatic token refresh, leaving a stale
      // session that Storage would otherwise reject. Force a fresh one first.
      try {
        await db.auth.refreshSession();
      } catch (_) {
        /* fall through to the session check below */
      }
      final id = uid;
      final session = db.auth.currentSession;
      if (id == null || session == null) {
        if (mounted) toast(context, 'Your session expired. Sign out and sign in again.', error: true);
        return;
      }
      final bytes = await x.readAsBytes();
      final path = '$id/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      // supabase_flutter's storage client kept returning a row-level-security 403
      // for this exact upload even with a fresh, valid, matching-user session —
      // while the same request built and sent by hand succeeds. Bypass the
      // package for this call and post the multipart upload directly.
      final uri = Uri.parse('${Env.supabaseUrl}/storage/v1/object/avatars/$path');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${session.accessToken}'
        ..headers['apikey'] = Env.supabaseKey
        ..headers['x-upsert'] = 'true'
        ..files.add(http.MultipartFile.fromBytes('', bytes, filename: '', contentType: MediaType('image', 'jpeg')));
      final response = await http.Response.fromStream(await request.send());
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Upload failed (${response.statusCode}): ${response.body}');
      }
      final url = db.storage.from('avatars').getPublicUrl(path);
      await AppState.instance.updateProfile({'avatar_url': url});
    } catch (e) {
      if (mounted) toast(context, 'Could not update your photo: $e', error: true);
    }
  }

  Future<void> _consent(bool v) async {
    if (v) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Research participation'),
          content: const Text(
              'Allow your completed periodic assessments to be included in anonymised, faculty-level statistics that help the university plan student health services. Only groups of 5 or more students are ever reported, and your daily tracking data is never included. You can withdraw at any time.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('I agree'))],
        ),
      );
      if (ok != true) return;
    }
    await AppState.instance.updateProfile({'research_consent': v});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final p = AppState.instance.profile;
        if (p == null) return const Scaffold(body: Loading());
        final goalGlasses = (p.waterGoalMl / 250).round();
        return VPage(
          header: const MainHeader('Profile'),
          nav: NavTab.profile,
          topPadding: 0,
          children: [
            _identity(p),
            SectionHeader('My health metrics',
                trailing: Text(p.measuredAt == null ? 'Not measured yet' : 'Updated ${DateFormat('d MMM').format(p.measuredAt!.toLocal())}', style: T.labelMd.c(AppColors.onSurfaceVariant))),
            bodyMetricTiles(p, (r) => context.push(r)),
            const SectionHeader("Today's goals"),
            TileGrid(children: [
              MetricTile(
                label: 'Water',
                icon: Symbols.water_drop_rounded,
                color: AppColors.water,
                value: '${(_waterMl / 250).round()}',
                unit: 'of $goalGlasses glasses',
                progress: _waterMl / p.waterGoalMl,
                onTap: () => context.push('/tools/water'),
              ),
              MetricTile(
                label: 'Activity',
                icon: Symbols.directions_walk_rounded,
                color: AppColors.activity,
                value: Fmt.thousands(_steps),
                unit: 'steps',
                progress: _steps / p.stepGoal,
                onTap: () => context.push('/tools/activity'),
              ),
              MetricTile(
                label: 'Meals',
                icon: Symbols.restaurant_rounded,
                color: AppColors.nutrition,
                value: '$_mealsToday',
                unit: 'logged',
                onTap: () => context.push('/diet'),
              ),
              MetricTile(
                label: 'Food variety',
                icon: Symbols.nutrition_rounded,
                color: AppColors.nutrition,
                value: '$_diversityToday',
                unit: 'of 8 groups',
                progress: _diversityToday / 8,
                onTap: () => context.push('/diet/diversity'),
              ),
              MetricTile(
                label: 'Sleep',
                icon: Symbols.bedtime_rounded,
                color: AppColors.sleep,
                value: _sleepMinutes == null ? '—' : Fmt.hm(_sleepMinutes!).replaceAll(' 0', ' '),
                caption: _sleepMinutes == null ? 'Not logged' : 'Goal ${p.sleepGoalHours.toStringAsFixed(0)} h',
                onTap: () => context.push('/tools/sleep'),
              ),
            ]),
            ListGroup(header: 'Appearance', children: [
              Padding(
                padding: const EdgeInsets.all(Sp.md),
                child: SizedBox(
                  width: double.infinity,
                  child: Segmented(
                    small: false,
                    options: const ['Light', 'Dark', 'System'],
                    value: _themeModeLabel(AppState.instance.themeMode),
                    onChanged: (v) => AppState.instance.setThemeMode(_themeModeFromLabel(v)),
                  ),
                ),
              ),
            ]),
            ListGroup(
              header: 'Privacy',
              footer: 'Includes only completed term assessments, reported for groups of five or more students. Daily tracking is never shared.',
              children: [
                ListRow(
                  icon: Symbols.science_rounded,
                  color: AppColors.mind,
                  title: 'Research participation',
                  subtitle: 'Share anonymised assessment results',
                  trailing: Switch(value: p.researchConsent, onChanged: _consent),
                ),
              ],
            ),
            ListGroup(header: 'Records', children: [
              ListRow(icon: Symbols.event_note_rounded, color: AppColors.primary, title: 'Appointments & requests', onTap: _appointments),
              ListRow(icon: Symbols.lab_profile_rounded, color: AppColors.heart, title: 'Blood reports', onTap: () => context.push('/blood-report')),
              ListRow(icon: Symbols.notifications_rounded, color: AppColors.warning, title: 'Notifications', onTap: () => context.push('/notifications')),
            ]),
            ListGroup(header: 'Support', children: [
              ListRow(icon: Symbols.info_rounded, color: AppColors.water, title: 'About VitalU', onTap: () => context.push('/about')),
              ListRow(icon: Symbols.emergency_rounded, color: AppColors.error, title: 'Emergency & support lines', onTap: () => context.push('/help')),
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

  Widget _identity(Profile p) => VCard(
        onTap: () => context.push('/profile/edit'),
        child: Row(children: [
          GestureDetector(
            onTap: _avatar,
            child: Stack(clipBehavior: Clip.none, children: [
              Avatar(size: 64, ring: false, onTap: _avatar),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.surfaceContainerLowest, width: 2)),
                  child: Icon(Symbols.photo_camera_rounded, size: 13, color: AppColors.onPrimary, fill: 1),
                ),
              ),
            ]),
          ),
          const SizedBox(width: Sp.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.displayName, style: T.headlineMd, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (p.username != null) ...[
                const SizedBox(height: 1),
                Text('@${p.username}', style: T.bodyMd.c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              if (p.faculty != null || p.registrationNumber != null) ...[
                const SizedBox(height: 4),
                Text(
                  [p.faculty, p.registrationNumber].whereType<String>().join(' · '),
                  style: T.labelMd.c(AppColors.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ]),
          ),
          Icon(Symbols.chevron_right_rounded, color: AppColors.outline),
        ]),
      );

  Future<void> _appointments() async {
    final list = await Repo.appointments();
    if (!mounted) return;
    showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Appointments & requests', style: T.headlineMd),
          const SizedBox(height: Sp.md),
          if (list.isEmpty) Text('No requests yet. You can book from Talk to a professional.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          if (list.isNotEmpty)
            ListGroup(dividerIndent: 16, children: [
              for (final a in list)
                ListRow(
                  icon: a['kind'] == 'chat' ? Symbols.chat_rounded : Symbols.event_rounded,
                  title: (a['professionals'] as Map?)?['name'] ?? a['service'] ?? 'Request',
                  subtitle:
                      '${a['preferred_at'] != null ? DateFormat('EEE d MMM, h:mm a').format(DateTime.parse(a['preferred_at']).toLocal()) : DateFormat('d MMM').format(DateTime.parse(a['created_at']).toLocal())} · ${a['status']}',
                ),
            ]),
        ]));
  }

  String _themeModeLabel(ThemeMode m) => switch (m) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System',
      };

  ThemeMode _themeModeFromLabel(String l) => switch (l) {
        'Light' => ThemeMode.light,
        'Dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
