import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/pdf_export.dart';
import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// One decoded lab value as produced by the `analyze-blood-report` edge function.
class LabValue {
  LabValue(this.raw);
  final Map raw;
  String get name => raw['name']?.toString() ?? 'Value';
  String get subtitle => raw['subtitle']?.toString() ?? '';
  num? get value => raw['value'] is num ? raw['value'] as num : num.tryParse('${raw['value']}');
  String get valueText => raw['value_text']?.toString() ?? (value == null ? '-' : _fmt(value!));
  String get unit => raw['unit']?.toString() ?? '';
  num? get refLow => raw['ref_low'] is num ? raw['ref_low'] as num : null;
  num? get refHigh => raw['ref_high'] is num ? raw['ref_high'] as num : null;
  String get reference => raw['reference']?.toString() ?? '';
  String get category => raw['category']?.toString() ?? 'other';
  String get status => raw['status']?.toString() ?? 'normal';
  String get statusLabel => raw['status_label']?.toString() ?? (inRange ? 'Normal' : (status == 'low' ? 'Low' : 'High'));
  String get explanation => raw['explanation']?.toString() ?? '';
  IconData get icon => iconByName(raw['icon']?.toString() ?? 'science');
  IconData get tipIcon => iconByName(raw['tip_icon']?.toString() ?? 'auto_awesome');
  bool get inRange => status == 'optimal' || status == 'normal';

  static String _fmt(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

const reportCategories = [
  ('all', 'All'),
  ('metabolic', 'Metabolic'),
  ('vitamins_minerals', 'Vitamins and minerals'),
  ('lipids', 'Lipids'),
  ('blood_count', 'Blood count'),
  ('thyroid', 'Thyroid'),
  ('kidney_liver', 'Kidney and liver'),
  ('other', 'Other'),
];

class ReportExplainedScreen extends StatefulWidget {
  const ReportExplainedScreen({super.key, required this.id});
  final String id;
  @override
  State<ReportExplainedScreen> createState() => _ReportExplainedScreenState();
}

class _ReportExplainedScreenState extends State<ReportExplainedScreen> {
  Rec? _r;
  bool _loading = true;
  bool _retrying = false;
  String _cat = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _r = await Repo.report(widget.id);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  List<LabValue> get _values => [for (final v in (_r?['results'] as List? ?? [])) if (v is Map) LabValue(v)];

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      _r = await Repo.analyzeReport(widget.id);
    } catch (e) {
      if (mounted) toast(context, 'Still could not read this report. Try a clearer photo or PDF.', error: true);
      _r = await Repo.report(widget.id);
    }
    if (mounted) setState(() => _retrying = false);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this report?'),
        content: const Text('The uploaded file and its explanation will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || _r == null) return;
    await Repo.deleteReport(_r!);
    if (mounted) goBack(context, '/blood-report');
  }

  Future<void> _pdf() async {
    final vals = _values;
    await sharePdf(
      title: 'Blood report explained',
      subtitle: '${_r?['panel_name'] ?? 'Lab panel'} · explained ${pdfDate(DateTime.parse(_r!['created_at']).toLocal())}',
      sections: {
        'Summary': [
          [_r?['summary']?.toString() ?? ''],
        ],
        for (final v in vals)
          v.name: [
            ['Your value', '${v.valueText} ${v.unit}'],
            ['Reference', v.reference],
            ['Status', v.statusLabel],
            [v.explanation],
          ],
      },
      footer: 'Decoded for educational wellness purposes. VitalU does not provide formal diagnosis or treatment plans. Consult your university health provider for clinical decisions.',
      filename: 'vitalu-report-explained.pdf',
    );
  }

  Future<void> _book() async {
    final flagged = _values.where((v) => !v.inRange).map((v) => v.name).toList();
    try {
      await Repo.requestAppointment(
        service: 'Lab report review',
        message: flagged.isEmpty ? 'Routine review of my decoded lab report.' : 'I would like a review of: ${flagged.join(', ')}.',
      );
      if (mounted) toast(context, 'Request sent. The health centre will confirm a time.');
    } catch (_) {
      if (mounted) toast(context, 'Could not send the request. Please try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final vals = _values;
    final shown = vals.where((v) => _cat == 'all' || v.category == _cat).toList();
    final cats = reportCategories.where((c) => c.$1 == 'all' || vals.any((v) => v.category == c.$1)).toList();
    final flagged = vals.where((v) => !v.inRange).toList();

    return VPage(
      header: TitleHeader('Report explained', onLeading: () => goBack(context, '/blood-report'), actions: [
        if (vals.isNotEmpty) IconButton(tooltip: 'Download PDF', icon: const Icon(Symbols.download_rounded), onPressed: _pdf),
        if (r != null) IconButton(tooltip: 'Delete report', icon: const Icon(Symbols.delete_rounded), onPressed: _delete),
      ]),
      onRefresh: _load,
      children: [
        if (_loading) const Loading(),
        if (!_loading && r == null) const EmptyState(icon: Symbols.lab_profile_rounded, title: 'Report not found', text: 'It may have been deleted.'),
        if (r != null && vals.isNotEmpty)
          VCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['panel_name'] ?? 'Lab panel', style: T.labelMd.c(AppColors.onSurfaceVariant)),
              const SizedBox(height: 6),
              MetricValue('${vals.length - flagged.length}', unit: 'of ${vals.length} values in range', size: 30, color: flagged.isEmpty ? AppColors.tertiary : null),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 8,
                  child: Row(children: [
                    for (int i = 0; i < vals.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Expanded(child: Container(color: vals[i].inRange ? AppColors.tertiary : AppColors.warning)),
                    ],
                  ]),
                ),
              ),
              if (r['summary'] != null) ...[
                const SizedBox(height: 12),
                Text(r['summary'], style: T.bodyMd.c(AppColors.onSurfaceVariant)),
              ],
            ]),
          ),
        if (r != null && vals.isEmpty)
          VCard(
            child: Column(children: [
              const SizedBox(height: Sp.sm),
              IconCircle(r['status'] == 'failed' ? Symbols.error_rounded : Symbols.hourglass_top_rounded, size: 56, iconSize: 28, fg: r['status'] == 'failed' ? AppColors.error : AppColors.primary),
              const SizedBox(height: Sp.md),
              Text(r['status'] == 'failed' ? "Couldn't read this report" : 'Reading your report', style: T.headlineSm),
              const SizedBox(height: 6),
              Text(
                  r['status'] == 'failed'
                      ? (r['error']?.toString().contains('API_KEY') == true
                          ? 'The report reader is not configured yet. Please try again later.'
                          : r['error']?.toString().startsWith('This PDF') == true
                              ? r['error'].toString()
                              : 'Blurry photos or unusual layouts can be hard to read. Try again, or upload a clearer photo or PDF.')
                      : 'This usually takes under a minute. Pull down to refresh.',
                  textAlign: TextAlign.center,
                  style: T.bodyMd.c(AppColors.onSurfaceVariant)),
              const SizedBox(height: Sp.md),
              if (r['status'] == 'failed') PrimaryButton('Try again', loading: _retrying, onTap: _retrying ? null : _retry),
            ]),
          ),
        if (vals.isNotEmpty) ...[
          if (cats.length > 2)
            FullBleed(
              child: ChipRow(children: [
                for (final c in cats) VChip(c.$2, selected: _cat == c.$1, onTap: () => setState(() => _cat = c.$1)),
              ]),
            ),
          for (final v in shown) _LabCard(v),
          VCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconCircle(Symbols.stethoscope_rounded, size: 40, iconSize: 20, fg: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(flagged.isEmpty ? 'Everything is in range' : 'Worth a check-up', style: T.headlineSm),
                    const SizedBox(height: 2),
                    Text(
                        flagged.isEmpty
                            ? 'A routine yearly check with the university medical officer keeps it that way.'
                            : '${flagged.map((v) => v.name).take(3).join(', ')} ${flagged.length == 1 ? 'is' : 'are'} outside the reference range. A doctor can tell you what it means for you.',
                        style: T.bodyMd.c(AppColors.onSurfaceVariant)),
                  ]),
                ),
              ]),
              const SizedBox(height: Sp.md),
              SoftButton('Request a consultation', icon: Symbols.calendar_today_rounded, onTap: _book),
            ]),
          ),
        ],
        const PrivacyNote('For education only, not a diagnosis. AI can misread values, so check your original report and ask a doctor about clinical decisions.'),
      ],
    );
  }
}

class _LabCard extends StatelessWidget {
  const _LabCard(this.v);
  final LabValue v;

  @override
  Widget build(BuildContext context) {
    final good = v.inRange;
    final accent = good ? AppColors.tertiary : AppColors.warning;
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.name, style: T.headlineSm),
              if (v.subtitle.isNotEmpty) Text(v.subtitle, style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 8),
          TagPill(v.statusLabel,
              icon: good ? Symbols.check_rounded : (v.status == 'low' ? Symbols.arrow_downward_rounded : Symbols.arrow_upward_rounded),
              bg: AppColors.tint(accent),
              fg: accent,
              iconColor: accent),
        ]),
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          MetricValue(v.valueText, unit: v.unit, size: 28),
          const Spacer(),
          if (v.reference.isNotEmpty) Flexible(child: Text('Range ${v.reference}', style: T.bodySm.c(AppColors.onSurfaceVariant), textAlign: TextAlign.right)),
        ]),
        const SizedBox(height: 12),
        _Gauge(v),
        if (v.explanation.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(v.explanation, style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.45)),
        ],
      ]),
    );
  }
}

/// Three-zone gauge (low / in-range / high) with a marker at the value.
class _Gauge extends StatelessWidget {
  const _Gauge(this.v);
  final LabValue v;

  @override
  Widget build(BuildContext context) {
    final lo = v.refLow?.toDouble(), hi = v.refHigh?.toDouble(), val = v.value?.toDouble();
    if (val == null || (lo == null && hi == null)) return const SizedBox.shrink();
    final top = math.max(hi ?? lo! * 2, val) * 1.25;
    final min = lo == null ? 0.0 : math.min(lo * 0.6, val * 0.9);
    final span = (top - min).clamp(1e-6, double.infinity);
    double f(double x) => ((x - min) / span).clamp(0.0, 1.0);
    final a = lo == null ? 0.0 : f(lo), b = hi == null ? 1.0 : f(hi);
    final pos = f(val);
    final ok = AppColors.tint(AppColors.tertiary), out = AppColors.surfaceContainerHigh;
    String n(double x) => LabValue._fmt(x);
    return Column(children: [
      LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 16,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              top: 4,
              bottom: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Row(children: [
                  if (a > 0) Expanded(flex: (a * 1000).round().clamp(1, 1000), child: Container(color: lo == null ? ok : out)),
                  Expanded(flex: ((b - a) * 1000).round().clamp(1, 1000), child: Container(color: ok)),
                  if (b < 1) Expanded(flex: ((1 - b) * 1000).round().clamp(1, 1000), child: Container(color: out)),
                ]),
              ),
            ),
            Positioned(
              left: (pos * w - 2).clamp(0, w - 4),
              top: 0,
              child: Container(width: 4, height: 16, decoration: BoxDecoration(color: v.inRange ? AppColors.tertiary : AppColors.warning, borderRadius: BorderRadius.circular(2))),
            ),
          ]),
        );
      }),
      const SizedBox(height: 4),
      LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        final style = T.labelSm.tnum.c(AppColors.onSurfaceVariant);
        return SizedBox(
          height: 16,
          child: Stack(children: [
            if (lo != null) Positioned(left: (a * w - 20).clamp(0, w - 40), width: 40, child: Text(n(lo), style: style, textAlign: TextAlign.center)),
            if (hi != null) Positioned(left: (b * w - 20).clamp(0, w - 40), width: 40, child: Text(n(hi), style: style, textAlign: TextAlign.center)),
          ]),
        );
      }),
    ]);
  }
}
