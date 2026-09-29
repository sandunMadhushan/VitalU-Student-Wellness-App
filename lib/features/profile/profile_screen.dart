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
import '../../data/catalog.dart';
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
  final _open = <String>{};
  Rec? _nextWindow;

  @override
  void initState() {
    super.initState();
    Repo.currentAndNextWindow().then((w) {
      if (mounted) setState(() => _nextWindow = w.$1 ?? w.$2);
    }).catchError((_) {});
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

  Future<void> _addLineage() async {
    String relation = 'Mother';
    String condition = 'High blood pressure';
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Add Family Health Record', style: T.headlineMd),
            const SizedBox(height: Sp.md),
            Text('Relative', style: T.labelLg),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in const ['Mother', 'Father', 'Sibling', 'Grandparent']) VChip(r, selected: relation == r, selectedColor: AppColors.secondary, onTap: () => set(() => relation = r)),
            ]),
            const SizedBox(height: Sp.md),
            Text('Condition', style: T.labelLg),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in const ['Heart disease', 'Stroke', 'High blood pressure', 'Diabetes', 'High cholesterol', 'Asthma', 'Other'])
                VChip(c, selected: condition == c, selectedColor: AppColors.secondary, onTap: () => set(() => condition = c)),
            ]),
            const SizedBox(height: Sp.lg),
            PrimaryButton('Save Record', color: AppColors.secondary, onTap: () async {
              final p = AppState.instance.profile!;
              final fam = [...p.familyHistory, {'relation': relation, 'condition': condition, 'added': isoDate(DateTime.now())}];
              final conds = {...p.conditions};
              if (condition == 'Heart disease' || condition == 'Stroke') conds.add('family_heart');
              if (condition == 'Diabetes') conds.add('family_diabetes');
              if (condition == 'High blood pressure') conds.add('family_hypertension');
              await AppState.instance.updateProfile({'family_history': fam, 'health_conditions': conds.toList()});
              if (ctx.mounted) Navigator.pop(ctx);
            }),
          ]);
        }));
  }

  Future<void> _addAllergy() async {
    final c = TextEditingController();
    await showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Add Allergy', style: T.headlineMd),
          const SizedBox(height: Sp.md),
          VTextField(controller: c, hint: 'e.g. Penicillin, peanuts, dust', icon: Symbols.warning),
          const SizedBox(height: Sp.md),
          PrimaryButton('Save', onTap: () async {
            if (c.text.trim().isEmpty) return;
            final p = AppState.instance.profile!;
            await AppState.instance.updateProfile({'allergies': [...p.allergies, c.text.trim()]});
            if (ctx.mounted) Navigator.pop(ctx);
          }),
        ]));
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
        final sub = [p.academicYear, p.faculty].whereType<String>().join(' • ');
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
                  if (sub.isNotEmpty) Text(sub, textAlign: TextAlign.center, style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  Pill(
                    color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
                    shadow: Shadows.tiny,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('Private & Encrypted Profile', style: T.labelSm.tracking(0.4)),
                    ]),
                  ),
                ]),
              ),
            ),
            Row(children: [
              _stat(Symbols.scale, AppColors.tertiaryFixed.withValues(alpha: 0.4), AppColors.tertiary, bmi == null ? 'Add' : Calc.bmiCategory(bmi).split(' ').first, bmi?.toStringAsFixed(1) ?? '—', 'BMI Range',
                  bmi == null ? 0 : ((bmi - 15) / 20).clamp(0, 1), () => context.push('/tools/bmi')),
              const SizedBox(width: 10),
              _stat(Symbols.accessibility_new, AppColors.primaryFixed.withValues(alpha: 0.6), AppColors.primary, whr == null ? 'Add' : 'Balance', whr?.toStringAsFixed(2) ?? '—', 'WHR Ratio',
                  whr == null ? 0 : ((whr - 0.6) / 0.5).clamp(0, 1), () => context.push('/tools/whr')),
              const SizedBox(width: 10),
              Expanded(
                child: VCard(
                  padding: const EdgeInsets.all(14),
                  shadow: Shadows.soft,
                  onTap: () => context.push('/assessments'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      IconCircle(Symbols.sync_saved_locally, size: 28, iconSize: 16, bg: AppColors.secondaryFixed, fg: AppColors.secondary),
                      const Spacer(),
                      Flexible(child: TagPill('Synced', bg: AppColors.secondaryFixed.withValues(alpha: 0.4), fg: AppColors.secondary)),
                    ]),
                    const SizedBox(height: 8),
                    Text(_nextWindow == null ? 'TBA' : DateFormat("MMM ''yy").format(DateTime.parse(_nextWindow!['opens_at']).toLocal()), style: T.headlineSm, overflow: TextOverflow.ellipsis),
                    Text('Checkup Due', style: T.labelSm.s(11).c(AppColors.onSurfaceVariant)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.tertiary, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text('Campus Link', style: T.labelSm.s(10).c(AppColors.onSurfaceVariant)),
                    ]),
                  ]),
                ),
              ),
            ]),
            Row(children: [
              Expanded(child: Text('Records & Vitals', style: T.headlineSm)),
              Text('4 Modules', style: T.labelSm.c(AppColors.primary)),
            ]),
            _accordion(
              'family',
              Symbols.family_restroom,
              AppColors.secondaryFixed.withValues(alpha: 0.4),
              AppColors.secondary,
              'Family Health History',
              '${p.familyHistory.length} logged condition${p.familyHistory.length == 1 ? '' : 's'} • Confidential',
              [
                if (p.familyHistory.isEmpty) _kv('No records yet', ''),
                for (final f in p.familyHistory) _kv('${f['relation']}', '${f['condition']}'),
              ],
              action: ('Add Family Record', _addLineage),
            ),
            _accordion(
              'health',
              Symbols.medication,
              AppColors.tertiaryFixed.withValues(alpha: 0.4),
              AppColors.tertiary,
              'Health & Prescriptions',
              '${p.allergies.isEmpty ? 'No allergies' : '${p.allergies.first} allergy'} • ${p.medications.length} active med${p.medications.length == 1 ? '' : 's'}',
              [
                for (final a in p.allergies) _kv('⚠️ ${a[0].toUpperCase()}${a.substring(1)} Allergy', 'Noted', color: AppColors.error),
                _kv('Medications', p.medications.isEmpty ? 'None Active' : p.medications.map((m) => m['name']).join(', ')),
                _kv('Conditions', [...p.conditions.map((c) => conditionByKey(c)?.label ?? c), ...p.customConditions].join(', ').ifEmpty('None noted')),
                _kv('Immunizations', p.immunizations ?? 'Not added'),
              ],
              action: ('Add Allergy', _addAllergy),
            ),
            _accordion(
              'body',
              Symbols.straighten,
              AppColors.primaryFixed.withValues(alpha: 0.5),
              AppColors.primary,
              'Anthropometrics',
              'Height, weight & body metrics',
              [
                _kv('Height', p.heightCm == null ? '—' : '${p.heightCm!.round()} cm'),
                _kv('Weight', p.weightKg == null ? '—' : '${p.weightKg} kg'),
                _kv('Waist-Hip Ratio', whr?.toStringAsFixed(2) ?? '—'),
                _kv('Last Measured', p.measuredAt == null ? '—' : DateFormat('d MMM yyyy').format(p.measuredAt!.toLocal())),
              ],
              action: ('Update Measurements', () => context.push('/profile/edit')),
            ),
            _accordion(
              'life',
              Symbols.wb_sunny,
              AppColors.butterWash,
              AppColors.butterAccent,
              'Lifestyle & Pacing',
              'Sleep rhythm, hydration & activity',
              [
                _kv('Avg Sleep Target', '${p.sleepGoalHours} hrs / night', color: AppColors.primary),
                _kv('Hydration Intake', '${Fmt.thousands(p.waterGoalMl)} mL / day', color: AppColors.tertiary),
                _kv('Daily Steps Goal', Fmt.thousands(p.stepGoal)),
                _kv('Daily Activity', p.activityLevel),
              ],
            ),
            VCard(
              color: AppColors.surfaceContainer,
              shadow: Shadows.tiny,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconCircle(Symbols.lock, size: 36, iconSize: 20, bg: AppColors.primaryFixed, fill: 1),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Private Health Vault', style: T.labelLg),
                    const SizedBox(height: 2),
                    Text('Your health records are private and protected. Only you can see them — campus practitioners see details only if you choose to share during an appointment.',
                        style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
                  ]),
                ),
              ]),
            ),
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

  Widget _stat(IconData icon, Color bg, Color fg, String chip, String value, String label, double bar, VoidCallback onTap) => Expanded(
        child: VCard(
          padding: const EdgeInsets.all(14),
          shadow: Shadows.soft,
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconCircle(icon, size: 28, iconSize: 16, bg: bg, fg: fg),
              const Spacer(),
              Flexible(child: Pill(color: bg.withValues(alpha: 0.5), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), child: Text(chip, style: T.labelSm.s(10).c(fg).bold, overflow: TextOverflow.ellipsis))),
            ]),
            const SizedBox(height: 8),
            Text(value, style: T.headlineMd.lh(1)),
            const SizedBox(height: 4),
            Text(label, style: T.labelSm.s(11).c(AppColors.onSurfaceVariant)),
            const SizedBox(height: 10),
            Bar(value: bar, height: 6, color: fg, track: AppColors.surfaceContainer),
          ]),
        ),
      );

  Widget _kv(String k, String v, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(k, style: T.labelMd.c(color ?? AppColors.onSurface))),
          const SizedBox(width: 8),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: T.labelSm.c(color ?? AppColors.onSurfaceVariant))),
        ]),
      );

  Widget _accordion(String key, IconData icon, Color bg, Color fg, String title, String sub, List<Widget> rows, {(String, VoidCallback)? action}) {
    final open = _open.contains(key);
    return VCard(
      padding: EdgeInsets.zero,
      clip: true,
      shadow: const [BoxShadow(color: Color(0x122D2B38), blurRadius: 28, offset: Offset(0, 10), spreadRadius: -10)],
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => open ? _open.remove(key) : _open.add(key)),
          child: Padding(
            padding: const EdgeInsets.all(Sp.md),
            child: Row(children: [
              IconCircle(icon, size: 48, iconSize: 24, bg: bg, fg: fg, shadow: Shadows.tinted(fg, opacity: 0.12, blur: 12, y: 4, spread: -2)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: T.headlineSm, overflow: TextOverflow.ellipsis),
                  Text(sub, style: T.bodySm.c(AppColors.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                ]),
              ),
              AnimatedRotation(turns: open ? 0.5 : 0, duration: const Duration(milliseconds: 300), child: Icon(Symbols.expand_more, color: AppColors.onSurfaceVariant)),
            ]),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: open
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(Sp.md, 0, Sp.md, Sp.md),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.base)),
                    child: Column(children: [
                      for (int i = 0; i < rows.length; i++) ...[
                        if (i > 0) Container(height: 1, color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                        rows[i],
                      ],
                      if (action != null) ...[
                        const SizedBox(height: 8),
                        SoftButton(action.$1, icon: Symbols.add, color: AppColors.surfaceContainerLowest, fg: AppColors.primary, height: 40, style: T.labelMd, onTap: action.$2),
                      ],
                    ]),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ]),
    );
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

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
