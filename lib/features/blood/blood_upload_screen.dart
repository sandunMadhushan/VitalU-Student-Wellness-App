import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../tools/tool_widgets.dart';

class BloodUploadScreen extends StatefulWidget {
  const BloodUploadScreen({super.key});
  @override
  State<BloodUploadScreen> createState() => _BloodUploadScreenState();
}

class _BloodUploadScreenState extends State<BloodUploadScreen> {
  static const _maxBytes = 15 * 1024 * 1024;
  Uint8List? _bytes;
  String? _name;
  String? _mime;
  bool _busy = false;
  String _stage = '';
  List<Rec> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final h = await Repo.reports();
      if (mounted) setState(() => _history = h);
    } catch (_) {}
  }

  void _setFile(Uint8List bytes, String name, String mime) {
    if (bytes.length > _maxBytes) {
      toast(context, 'That file is larger than 15MB. Try a clearer photo or a smaller PDF.', error: true);
      return;
    }
    setState(() {
      _bytes = bytes;
      _name = name;
      _mime = mime;
    });
  }

  Future<void> _photo() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2200);
      if (x == null) return;
      _setFile(await x.readAsBytes(), 'lab-report-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.jpg', 'image/jpeg');
    } catch (_) {
      if (mounted) toast(context, 'Camera unavailable — try uploading a file instead.', error: true);
    }
  }

  Future<void> _file() async {
    final files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png']);
    final f = files.firstOrNull;
    if (f == null) return;
    final ext = (f.extension ?? '').toLowerCase().replaceAll('.', '');
    final mime = ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg');
    final size = await f.length();
    if (size != null && size > _maxBytes) {
      if (mounted) toast(context, 'That file is larger than 15MB. Try a clearer photo or a smaller PDF.', error: true);
      return;
    }
    _setFile(await f.readAsBytes(), f.name, mime);
  }

  Future<void> _analyze() async {
    if (_bytes == null) return;
    setState(() {
      _busy = true;
      _stage = 'Uploading securely…';
    });
    Rec? report;
    try {
      report = await Repo.uploadReport(_bytes!, _name!, _mime!);
      setState(() => _stage = 'Translating your values…');
      await Repo.analyzeReport(report['id']);
    } catch (e) {
      if (mounted) {
        toast(context, report == null ? 'Upload failed. Check your connection and try again.' : 'We saved your report but could not read it just now.', error: true);
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _bytes = null;
      _name = null;
    });
    if (report != null) {
      await context.push('/blood-report/${report['id']}');
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: const MainHeader('Vitalu Health Education Library'),
      nav: NavTab.library,
      navVariantLibrary: true,
      onRefresh: _loadHistory,
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, iconSize: 22, onTap: () => goBack(context, '/library')),
          const Spacer(),
          TagPill('Private & Secure', icon: Symbols.lock, bg: AppColors.tertiaryFixed.withValues(alpha: 0.6), fg: AppColors.onTertiaryFixedVariant, iconColor: AppColors.onTertiaryFixedVariant),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Understand Your Blood Report', style: T.headlineMd.s(24)),
          const SizedBox(height: 4),
          Text('Empathetic, clear translations of routine student lab panels', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        ]),
        VCard(
          radius: Rad.lg,
          gradient: LinearGradient(colors: [AppColors.tertiaryFixed.withValues(alpha: 0.18), AppColors.surfaceContainerLow]),
          shadow: Shadows.card,
          padding: const EdgeInsets.all(Sp.md + 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 116,
                height: 116,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.circular(Rad.md), boxShadow: Shadows.tiny),
                child: const ClipOval(child: AssetImg('lab_report')),
              ),
              const SizedBox(width: Sp.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('CAMPUS HEALTH COMPANION', style: T.labelSm.c(AppColors.tertiary).tracking(0.6)),
                  const SizedBox(height: 4),
                  Text('Demystify Your Lab Numbers', style: T.headlineMd.lh(1.25)),
                ]),
              ),
            ]),
            const SizedBox(height: Sp.md),
            Text('Got routine lab work done from the student health clinic? Upload your results for plain-English, supportive insights without intimidating medical jargon.',
                style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.7)),
          ]),
        ),
        VCard(
          radius: Rad.lg,
          shadow: Shadows.card,
          padding: const EdgeInsets.all(Sp.lg + 8),
          child: CustomPaint(
            painter: _DashedBorder(),
            child: Padding(
              padding: const EdgeInsets.all(Sp.md),
              child: Column(children: [
                const SizedBox(height: Sp.sm),
                IconCircle(Symbols.document_scanner, size: 76, iconSize: 34, bg: AppColors.surfaceContainerLow, shadow: Shadows.tiny),
                const SizedBox(height: Sp.md),
                Text('Upload or scan your report', style: T.headlineSm.s(20).w(FontWeight.w500), textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('Supports PDF, JPEG, PNG from university clinics & local labs (up to 15MB)', style: T.bodySm.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center),
                const SizedBox(height: Sp.md),
                Row(children: [
                  Expanded(child: _pickBtn(Symbols.photo_camera, 'Take Photo', AppColors.tertiaryFixed.withValues(alpha: 0.45), AppColors.onTertiaryFixed, _busy ? null : _photo)),
                  const SizedBox(width: Sp.sm),
                  Expanded(child: _pickBtn(Symbols.upload_file, 'Upload File', AppColors.primaryFixed, AppColors.onPrimaryFixed, _busy ? null : _file)),
                ]),
                if (_name != null) ...[
                  const SizedBox(height: Sp.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.tertiaryFixed.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(Rad.base)),
                    child: Row(children: [
                      const Icon(Symbols.check_circle, size: 20, color: AppColors.tertiary, fill: 1),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_name!, style: T.labelMd, overflow: TextOverflow.ellipsis)),
                      Text('${(_bytes!.length / 1024 / 1024).toStringAsFixed(1)} MB', style: T.labelSm.c(AppColors.onSurfaceVariant)),
                      const SizedBox(width: 4),
                      CircleButton(Symbols.close, size: 28, iconSize: 16, onTap: _busy ? null : () => setState(() => _bytes = _name = null)),
                    ]),
                  ),
                ],
                const SizedBox(height: Sp.md),
                Text('FREQUENTLY DECODED STUDENT PANELS', style: T.labelSm.c(AppColors.onSurfaceVariant).w(FontWeight.w500).tracking(0.6), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                  for (final t in const ['CBC Panel', 'Iron & Ferritin', 'Vitamin D', 'Thyroid (TSH)'])
                    Pill(color: AppColors.surfaceContainerLowest, border: Border.all(color: AppColors.surfaceContainerHigh), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text(t, style: T.bodySm.c(AppColors.onSurfaceVariant))),
                ]),
                const SizedBox(height: Sp.sm),
              ]),
            ),
          ),
        ),
        VCard(
          color: AppColors.butterWash.withValues(alpha: 0.7),
          radius: Rad.lg,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const IconCircle(Symbols.health_and_safety, size: 40, iconSize: 22, bg: Color(0xFFFFE3B3), fg: Color(0xFF8A5A00)),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('This tool explains values in simple terms — it does not diagnose. Always confirm with a doctor or visit campus health services for medical advice.',
                    style: T.bodyMd.c(AppColors.onSurface).lh(1.5)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => showInfoSheet(context, title: 'How we translate values', icon: Symbols.auto_read_play, paragraphs: const [
                    'Your report is uploaded to your private, encrypted storage in VitalU. An AI model reads the printed values, units and the reference ranges your lab provided.',
                    'Each value is compared with the lab\'s own reference range and explained in plain language. Nothing is added to campus or insurance records.',
                    'AI can misread blurry photos or unusual layouts, so always check the original report and talk to a doctor about anything flagged.',
                  ]),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Learn how we translate values', style: T.labelMd.c(const Color(0xFF8A5A00))),
                    const SizedBox(width: 4),
                    const Icon(Symbols.north_east, size: 16, color: Color(0xFF8A5A00)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        Column(children: [
          PrimaryButton(
            _busy ? _stage : 'Analyze Report',
            leadingIcon: Symbols.auto_read_play,
            loading: _busy,
            color: _bytes == null ? AppColors.surfaceContainerHigh : AppColors.primary,
            fg: _bytes == null ? AppColors.outline : AppColors.onPrimary,
            onTap: _bytes == null || _busy ? null : _analyze,
          ),
          const SizedBox(height: Sp.sm),
          Text(_bytes == null ? '(Select a report or take a photo above to begin)' : 'Ready when you are — this takes about 20 seconds', style: T.bodySm.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.sm),
          const PrivacyNote('Encrypted in transit • Stored privately in your account • Never shared with insurers or campus records', center: false),
        ]),
        if (_history.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Your past reports', style: T.headlineSm),
            const SizedBox(height: Sp.sm),
            for (final r in _history)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: VCard(
                  padding: const EdgeInsets.all(14),
                  shadow: Shadows.tiny,
                  onTap: () async {
                    await context.push('/blood-report/${r['id']}');
                    _loadHistory();
                  },
                  child: Row(children: [
                    IconCircle(r['status'] == 'done' ? Symbols.lab_profile : Symbols.hourglass_top,
                        size: 44, bg: r['status'] == 'done' ? AppColors.tertiaryFixed.withValues(alpha: 0.5) : AppColors.surfaceContainer, fg: AppColors.tertiary),
                    const SizedBox(width: Sp.sm),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(r['panel_name'] ?? r['file_name'] ?? 'Lab report', style: T.labelLg, overflow: TextOverflow.ellipsis),
                        Text(
                            '${DateFormat('d MMM yyyy').format(DateTime.parse(r['created_at']).toLocal())} • ${switch (r['status']) {
                              'done' => 'Explained',
                              'failed' => 'Needs a retry',
                              _ => 'Processing',
                            }}',
                            style: T.bodySm.c(AppColors.onSurfaceVariant)),
                      ]),
                    ),
                    const Icon(Symbols.chevron_right, color: AppColors.outlineVariant),
                  ]),
                ),
              ),
          ]),
      ],
    );
  }

  Widget _pickBtn(IconData icon, String label, Color bg, Color fg, VoidCallback? onTap) => Pressable(
        onTap: onTap,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Rad.full)),
          child: Row(children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: T.labelLg.c(fg), textAlign: TextAlign.center)),
          ]),
        ),
      );
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7FD3D8)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20));
    final path = Path()..addRRect(rrect);
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 8), paint);
        d += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
