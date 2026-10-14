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

/// Lets the student pick a new profile photo and uploads it.
Future<void> changeAvatar(BuildContext context) async {
  late final XFile? x;
  try {
    // On web, image_picker resizes via an in-browser canvas when maxWidth/imageQuality
    // are set; that resize silently fails for some photo formats (e.g. HEIC), so the
    // file picker never returns and the tap looks like it does nothing. Skip resizing
    // on web and let the server-side upload handle the original bytes instead.
    x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: kIsWeb ? null : 512, imageQuality: kIsWeb ? null : 85);
  } catch (e) {
    if (context.mounted) toast(context, 'Could not open your photo library: $e', error: true);
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
      if (context.mounted) toast(context, 'Your session expired. Sign out and sign in again.', error: true);
      return;
    }
    final bytes = await x.readAsBytes();
    final path = '$id/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    // supabase_flutter's storage client kept returning a row-level-security 403
    // for this exact upload even with a fresh, valid, matching-user session,
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
    if (context.mounted) toast(context, 'Could not update your photo: $e', error: true);
  }
}

/// Everything the student has told VitalU, in one place, with an Edit button.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final p = AppState.instance.profile;
        if (p == null) return const Scaffold(body: Loading());
        String or(String? v, [String fallback = 'Not set']) => (v == null || v.trim().isEmpty) ? fallback : v;
        String cm(double? v) => v == null ? 'Not set' : '${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} cm';
        final personal = p.conditions.where((k) => !isFamilyCondition(k)).map((k) => conditionByKey(k)?.label ?? k).toList()..addAll(p.customConditions);
        final family = p.conditions.where(isFamilyCondition).map(familyConditionLabel).toList();

        return VPage(
          header: TitleHeader('Account', onLeading: () => goBack(context, '/profile')),
          bottom: PrimaryButton('Edit details', leadingIcon: Symbols.edit_rounded, onTap: () => context.push('/profile/edit')),
          children: [
            Column(children: [
              const SizedBox(height: Sp.sm),
              GestureDetector(
                onTap: () => changeAvatar(context),
                child: Stack(clipBehavior: Clip.none, children: [
                  Avatar(size: 104, ring: false, onTap: () => changeAvatar(context)),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, border: Border.all(color: AppColors.surface, width: 3)),
                      child: Icon(Symbols.photo_camera_rounded, size: 16, color: AppColors.onPrimary, fill: 1),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: Sp.sm),
              Text(p.fullName, style: T.headlineLg, textAlign: TextAlign.center),
              if (p.username != null) Text('@${p.username}', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
              const SizedBox(height: 2),
              TextLinkButton('Change photo', leading: Symbols.photo_camera_rounded, onTap: () => changeAvatar(context)),
            ]),
            ListGroup(header: 'Personal', dividerIndent: 60, children: [
              _row(Symbols.badge_rounded, AppColors.primary, 'Name with initials', or(p.nameWithInitials)),
              _row(Symbols.id_card_rounded, AppColors.heart, 'Registration number', or(p.registrationNumber)),
              _row(Symbols.mail_rounded, AppColors.water, 'Email', or(p.email)),
              _row(Symbols.wc_rounded, AppColors.water, 'Gender', p.sex == null ? 'Not set' : (p.sex == 'male' ? 'Male' : 'Female')),
              _row(Symbols.cake_rounded, AppColors.cycle, 'Date of birth', p.dob == null ? 'Not set' : DateFormat('d MMMM yyyy').format(p.dob!)),
              _row(Symbols.hourglass_rounded, AppColors.mind, 'Age', p.age == null ? 'Not set' : '${p.age} years'),
            ]),
            ListGroup(header: 'Academic and living', dividerIndent: 60, children: [
              _row(Symbols.school_rounded, AppColors.primary, 'Faculty', or(p.faculty)),
              _row(Symbols.calendar_month_rounded, AppColors.warning, 'Batch', or(p.academicYear)),
              _row(Symbols.home_rounded, AppColors.mind, 'Accommodation', accommodationOptions[p.accommodation] ?? 'Not set'),
            ]),
            ListGroup(
              header: 'Body measurements',
              footer: p.measuredAt == null ? null : 'Last updated ${DateFormat('d MMM yyyy').format(p.measuredAt!.toLocal())}',
              dividerIndent: 60,
              children: [
                _row(Symbols.height_rounded, AppColors.body, 'Height', cm(p.heightCm)),
                _row(Symbols.monitor_weight_rounded, AppColors.body, 'Weight', p.weightKg == null ? 'Not set' : '${p.weightKg!.toStringAsFixed(p.weightKg! % 1 == 0 ? 0 : 1)} kg'),
                _row(Symbols.straighten_rounded, AppColors.body, 'Waist circumference', cm(p.waistCm)),
                _row(Symbols.accessibility_new_rounded, AppColors.body, 'Hip circumference', cm(p.hipCm)),
                _row(Symbols.accessibility_rounded, AppColors.body, 'Body shape', bodyShapeByKey(p.bodyShape)?.label ?? 'Not set'),
                _row(Symbols.calculate_rounded, AppColors.body, 'BMI', p.bmi == null ? 'Add height and weight' : '${p.bmi!.toStringAsFixed(1)} · ${Calc.bmiCategory(p.bmi!)}'),
                _row(Symbols.donut_large_rounded, AppColors.body, 'Waist-to-hip ratio', p.whr == null ? 'Add waist and hip' : p.whr!.toStringAsFixed(2)),
              ],
            ),
            _chips('Medical conditions', Symbols.medical_information_rounded, AppColors.heart, personal, 'None recorded'),
            _chips('Family health history', Symbols.family_restroom_rounded, AppColors.heart, [
              ...family,
              for (final f in p.familyHistory) '${f['condition']} (${f['relation']})',
            ], 'None recorded'),
            _chips('Allergies', Symbols.allergy_rounded, AppColors.error, p.allergies, 'None recorded'),
            _chips('Medications and supplements', Symbols.medication_rounded, AppColors.primary, [for (final m in p.medications) '${m['name']}'], 'None recorded'),
            ListGroup(header: 'Lifestyle', dividerIndent: 60, children: [
              _row(Symbols.directions_walk_rounded, AppColors.activity, 'Activity level', p.activityLevel),
            ]),
            ListGroup(children: [
              ListRow(icon: Symbols.event_note_rounded, color: AppColors.primary, title: 'Appointment requests', subtitle: 'Bookings with campus professionals', onTap: () => _appointments(context)),
            ]),
            const PrivacyNote('Only you can see these details.'),
          ],
        );
      },
    );
  }

  Widget _row(IconData icon, Color c, String title, String value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 12),
        child: Row(children: [
          IconCircle(icon, size: 30, iconSize: 18, bg: c, fg: AppColors.isDark ? AppColors.surface : Colors.white, radius: 8, fill: 1),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: T.bodyLg.w(FontWeight.w600))),
          const SizedBox(width: 8),
          Flexible(child: Text(value, style: T.bodyMd.c(AppColors.onSurfaceVariant), textAlign: TextAlign.right)),
        ]),
      );

  Widget _chips(String title, IconData icon, Color c, List<String> items, String empty) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(title, style: T.labelMd.c(AppColors.onSurfaceVariant))),
        VCard(
          child: items.isEmpty
              ? Text(empty, style: T.bodyMd.c(AppColors.onSurfaceVariant))
              : Wrap(spacing: 6, runSpacing: 6, children: [for (final i in items) TagPill(i, icon: icon, bg: AppColors.tint(c), fg: c, fill: 1)]),
        ),
      ]);

  Future<void> _appointments(BuildContext context) async {
    List<Rec> list = [];
    try {
      list = await Repo.appointments();
    } catch (_) {}
    if (!context.mounted) return;
    showVSheet(context, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Appointment requests', style: T.headlineMd),
          const SizedBox(height: Sp.md),
          if (list.isEmpty) Text('No requests yet. You can book from Talk to a professional in Tools.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
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
}
