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
        if (mounted) toast(context, 'Your session expired — please sign out and sign in again.', error: true);
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
        final bmi = p.bmi, whr = p.whr;
        return VPage(
          header: const MainHeader('Profile'),
          nav: NavTab.profile,
          padding: const EdgeInsets.symmetric(horizontal: Sp.margin),
          children: [
            FullBleed(
              child: Container(
                padding: const EdgeInsets.fromLTRB(Sp.margin, 16, Sp.margin, 24),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Rad.lg)),
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.tertiaryFixedDim.withValues(alpha: 0.2), AppColors.surfaceContainerLow, AppColors.surface]),
                ),
                child: Column(children: [
                  Row(children: [
                    CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainerLowest, fg: AppColors.onSurface, shadow: Shadows.soft, onTap: () => goBack(context)),
                    Expanded(child: Text('Health Profile', textAlign: TextAlign.center, style: T.headlineSm)),
                    CircleButton(Symbols.edit, size: 40, iconSize: 19, bg: AppColors.surfaceContainerLowest, fg: AppColors.primary, shadow: Shadows.tinted(AppColors.primary, opacity: 0.2, blur: 20, y: 8), onTap: () => context.push('/profile/edit')),
                  ]),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _avatar,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Positioned.fill(child: Glow(color: AppColors.tertiaryFixed.withValues(alpha: 0.7), size: 100)),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, shape: BoxShape.circle, boxShadow: Shadows.soft),
                        child: Avatar(size: 88, ring: false, onTap: _avatar),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(color: AppColors.tertiaryContainer, shape: BoxShape.circle, boxShadow: Shadows.tinted(AppColors.tertiary, opacity: 0.3, blur: 8, y: 2, spread: 0)),
                          child: Icon(Symbols.photo_camera, size: 13, color: AppColors.onTertiary, fill: 1),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Text(p.fullName, style: T.headlineMd),
                ]),
              ),
            ),
            Row(children: [
              Expanded(child: Text('My Health Metrics', style: T.headlineSm)),
              Text(p.measuredAt == null ? 'Not yet updated' : 'Updated ${DateFormat('d MMM').format(p.measuredAt!.toLocal())}', style: T.labelSm.c(AppColors.onSurfaceVariant)),
            ]),
            Row(children: [
              _bmiStat(bmi, () => context.push('/tools/bmi')),
              const SizedBox(width: 10),
              _stat(Symbols.accessibility_new, AppColors.primaryFixed.withValues(alpha: 0.6), AppColors.primary, whr?.toStringAsFixed(2) ?? '—', 'WHR Ratio',
                  whr == null ? 0 : ((whr - 0.6) / 0.5).clamp(0, 1), () => context.push('/tools/whr')),
            ]),
            Text("Today's Health Goals", style: T.headlineSm),
            Row(children: [
              _goalTile(Symbols.water_drop, AppColors.primaryFixed, AppColors.primary, '${(_waterMl / 250).round()}/${(p.waterGoalMl / 250).round()}', 'Water (glasses)'),
              const SizedBox(width: Sp.xs),
              _goalTile(Symbols.restaurant, AppColors.secondaryFixed, AppColors.secondary, '$_mealsToday', 'Meals logged'),
              const SizedBox(width: Sp.xs),
              _goalTile(Symbols.nutrition, AppColors.tertiaryFixed, AppColors.tertiary, '$_diversityToday/8', 'Diet diversity'),
            ]),
            Row(children: [
              _goalTile(Symbols.directions_walk, AppColors.butterWash, AppColors.butterAccent, Fmt.thousands(_steps), 'Activity (steps)'),
              const SizedBox(width: Sp.xs),
              _goalTile(Symbols.bedtime, AppColors.primaryFixed, AppColors.primary, _sleepMinutes == null ? '—' : Fmt.hm(_sleepMinutes!), 'Sleep'),
            ]),
            Text('Settings & Support', style: T.headlineSm),
            VCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shadow: Shadows.soft,
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.md, 10, Sp.md, 4),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    IconCircle(AppState.instance.themeMode == ThemeMode.dark ? Symbols.dark_mode : Symbols.light_mode, size: 36, iconSize: 18, bg: AppColors.surfaceContainerLow, fg: AppColors.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Appearance', style: T.labelLg),
                        Text('Light, dark or match your device', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                      ]),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.md, 8, Sp.md, 10),
                  child: Segmented(
                    small: false,
                    options: const ['Light', 'Dark', 'System'],
                    value: _themeModeLabel(AppState.instance.themeMode),
                    onChanged: (v) => AppState.instance.setThemeMode(_themeModeFromLabel(v)),
                  ),
                ),
                Container(height: 1, color: AppColors.outlineVariant.withValues(alpha: 0.3), margin: const EdgeInsets.symmetric(horizontal: Sp.md)),
                SwitchListTile(
                  value: p.researchConsent,
                  onChanged: _consent,
                  activeTrackColor: AppColors.tertiary,
                  secondary: IconCircle(Symbols.science, size: 36, iconSize: 18, bg: AppColors.tertiaryFixed, fg: AppColors.tertiary),
                  title: Text('Research participation', style: T.labelLg),
                  subtitle: Text('Share anonymised assessment results', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ),
                _link(Symbols.event_note, 'My appointments & requests', () => _appointments()),
                _link(Symbols.lab_profile, 'My blood reports', () => context.push('/blood-report')),
                _link(Symbols.notifications, 'Notifications', () => context.push('/notifications')),
                _link(Symbols.info, 'About & Support', () => context.push('/about')),
                _link(Symbols.emergency, 'Need Help Now', () => context.push('/help'), color: AppColors.error),
                _link(Symbols.logout, 'Sign out', () async {
                  await AppState.instance.signOut();
                  if (context.mounted) context.go('/auth/login');
                }),
              ]),
            ),
          ],
        );
      },
    );
  }

  Future<void> _appointments() async {
    final list = await Repo.appointments();
    if (!mounted) return;
    showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('My Appointments & Requests', style: T.headlineMd),
          const SizedBox(height: Sp.md),
          if (list.isEmpty) Text('No requests yet. Book a visit from Talk to a Professional.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          for (final a in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: VCard(
                color: AppColors.surfaceContainerLow,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(a['kind'] == 'chat' ? Symbols.chat : Symbols.event, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text((a['professionals'] as Map?)?['name'] ?? a['service'] ?? 'Request', style: T.labelLg),
                      Text(
                          '${a['preferred_at'] != null ? DateFormat('EEE d MMM, h:mm a').format(DateTime.parse(a['preferred_at']).toLocal()) : DateFormat('d MMM').format(DateTime.parse(a['created_at']).toLocal())} • ${a['status']}',
                          style: T.bodySm.c(AppColors.onSurfaceVariant)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]));
  }

  Widget _link(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final color0 = color ?? AppColors.primary;
    return ListTile(
      onTap: onTap,
      leading: IconCircle(icon, size: 36, iconSize: 18, bg: AppColors.surfaceContainerLow, fg: color0),
      title: Text(label, style: T.labelLg.c(color0 == AppColors.error ? AppColors.error : AppColors.onSurface)),
      trailing: Icon(Symbols.chevron_right, color: AppColors.outline),
    );
  }

  Widget _stat(IconData icon, Color bg, Color fg, String value, String label, double bar, VoidCallback onTap) => Expanded(
        child: VCard(
          padding: const EdgeInsets.all(14),
          shadow: Shadows.soft,
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(icon, size: 28, iconSize: 16, bg: bg, fg: fg),
            const SizedBox(height: 8),
            Text(value, style: T.headlineMd.lh(1)),
            const SizedBox(height: 4),
            Text(label, style: T.labelSm.s(11).c(AppColors.onSurfaceVariant)),
            const SizedBox(height: 10),
            Bar(value: bar, height: 6, color: fg, track: AppColors.surfaceContainer),
          ]),
        ),
      );

  /// BMI tile with a status-coloured icon (underweight/normal/overweight/obese)
  /// instead of a body photo, per the "visually show BMI status" request.
  Widget _bmiStat(double? bmi, VoidCallback onTap) {
    final (icon, bg, fg) = switch (bmi == null ? null : Calc.bmiCategory(bmi)) {
      null => (Symbols.scale, AppColors.surfaceContainerHigh, AppColors.onSurfaceVariant),
      'Underweight' => (Symbols.trending_down, AppColors.skyWash, AppColors.skyAccent),
      'Normal Weight' => (Symbols.check_circle, AppColors.tertiaryFixed, AppColors.tertiary),
      'Overweight' => (Symbols.trending_up, AppColors.butterWash, AppColors.butterAccent),
      _ => (Symbols.priority_high, AppColors.errorContainer, AppColors.error),
    };
    return _stat(icon, bg, fg, bmi?.toStringAsFixed(1) ?? '—', 'BMI Range', bmi == null ? 0 : ((bmi - 15) / 20).clamp(0, 1), onTap);
  }

  Widget _goalTile(IconData icon, Color bg, Color fg, String value, String label) => Expanded(
        child: VCard(
          color: AppColors.surfaceContainerLowest,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          shadow: Shadows.tiny,
          child: Column(children: [
            IconCircle(icon, size: 32, iconSize: 16, bg: bg, fg: fg, fill: 1),
            const SizedBox(height: 6),
            Text(value, style: T.labelLg.bold, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(label, style: T.labelSm.s(10).c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          ]),
        ),
      );

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
