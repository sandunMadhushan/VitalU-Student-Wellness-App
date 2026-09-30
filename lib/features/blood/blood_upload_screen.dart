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
      if (mounted) toast(context, 'Camera unavailable. Try choosing a file instead.', error: true);
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
      _stage = 'Uploading…';
    });
    Rec? report;
    try {
      report = await Repo.uploadReport(_bytes!, _name!, _mime!);
      setState(() => _stage = 'Reading values…');
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

  void _explain() => showInfoSheet(context, title: 'How reports are explained', icon: Symbols.lab_profile_rounded, paragraphs: const [
        'Your report is uploaded to private, encrypted storage in your VitalU account. An AI model reads the printed values, units and the reference ranges your lab provided.',
        "Each value is compared with the lab's own reference range and explained in plain language. Nothing is added to university or insurance records.",
        'AI can misread blurry photos or unusual layouts, so always check the original report and talk to a doctor about anything flagged.',
      ]);

  @override
  Widget build(BuildContext context) {
    return VPage(
      header: TitleHeader('Blood report', onLeading: () => goBack(context, '/library'), actions: [
        IconButton(tooltip: 'How it works', icon: const Icon(Symbols.info_rounded), onPressed: _explain),
      ]),
      onRefresh: _loadHistory,
      bottom: PrimaryButton(_busy ? _stage : 'Explain report', loading: _busy, onTap: _bytes == null || _busy ? null : _analyze),
      children: [
        Text("Upload a lab report and get a plain-language note on each value, compared with your lab's reference range.", style: T.bodyLg.c(AppColors.onSurfaceVariant)),
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_name == null) ...[
              Row(children: [
                IconCircle(Symbols.upload_file_rounded, size: 44, iconSize: 22, fg: AppColors.heart),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Add your report', style: T.headlineSm),
                    Text('PDF, JPG or PNG, up to 15 MB', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  ]),
                ),
              ]),
              const SizedBox(height: Sp.md),
              Row(children: [
                Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _photo, icon: const Icon(Symbols.photo_camera_rounded, size: 20), label: const Text('Take photo'))),
                const SizedBox(width: Sp.sm),
                Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _file, icon: const Icon(Symbols.folder_open_rounded, size: 20), label: const Text('Choose file'))),
              ]),
            ] else
              Row(children: [
                IconCircle(_mime == 'application/pdf' ? Symbols.picture_as_pdf_rounded : Symbols.image_rounded, size: 44, iconSize: 22, fg: AppColors.heart),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_name!, style: T.labelLg.semi, overflow: TextOverflow.ellipsis),
                    Text('${(_bytes!.length / 1024 / 1024).toStringAsFixed(1)} MB · ready to explain', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  ]),
                ),
                IconButton(tooltip: 'Remove file', icon: const Icon(Symbols.close_rounded), onPressed: _busy ? null : () => setState(() => _bytes = _name = null)),
              ]),
          ]),
        ),
        ListGroup(header: 'Works well with', dividerIndent: 16, children: [
          for (final t in const [('Full blood count (CBC)', 'Haemoglobin, white cells, platelets'), ('Iron studies', 'Serum iron and ferritin'), ('Vitamin D', '25-hydroxy vitamin D'), ('Thyroid', 'TSH, free T4')])
            ListRow(title: t.$1, subtitle: t.$2),
        ]),
        VCard(
          color: AppColors.warningContainer,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Symbols.info_rounded, size: 22, color: AppColors.warning, fill: 1),
            const SizedBox(width: 12),
            Expanded(
              child: Text('This explains values in simple terms. It does not diagnose. Confirm anything flagged with a doctor or the university health centre.',
                  style: T.bodyMd.lh(1.45)),
            ),
          ]),
        ),
        if (_history.isNotEmpty)
          ListGroup(header: 'Past reports', children: [
            for (final r in _history)
              ListRow(
                icon: r['status'] == 'done' ? Symbols.lab_profile_rounded : (r['status'] == 'failed' ? Symbols.error_rounded : Symbols.hourglass_top_rounded),
                color: r['status'] == 'failed' ? AppColors.error : AppColors.heart,
                title: r['panel_name'] ?? r['file_name'] ?? 'Lab report',
                subtitle: '${DateFormat('d MMM yyyy').format(DateTime.parse(r['created_at']).toLocal())} · ${switch (r['status']) {
                  'done' => 'Explained',
                  'failed' => 'Needs a retry',
                  _ => 'Processing',
                }}',
                onTap: () async {
                  await context.push('/blood-report/${r['id']}');
                  _loadHistory();
                },
              ),
          ]),
        const PrivacyNote('Encrypted in transit and stored privately in your account.'),
      ],
    );
  }
}
