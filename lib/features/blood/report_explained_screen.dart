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
  String get valueText => raw['value_text']?.toString() ?? (value == null ? '—' : _fmt(value!));
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
  ('all', 'All Results'),
  ('metabolic', 'Metabolic'),
  ('vitamins_minerals', 'Vitamins & Minerals'),
  ('lipids', 'Lipids'),
  ('blood_count', 'Blood Count'),
  ('thyroid', 'Thyroid'),
  ('kidney_liver', 'Kidney & Liver'),
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
      title: 'Your Report, Explained',
      subtitle: '${_r?['panel_name'] ?? 'Lab panel'} • decoded ${pdfDate(DateTime.parse(_r!['created_at']).toLocal())}',
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
      if (mounted) toast(context, 'Consult request sent — the health centre will confirm a time 💜');
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
      header: const MainHeader('Vitalu Health Education Library'),
      nav: NavTab.library,
      navVariantLibrary: true,
      onRefresh: _load,
      children: [
        Container(
          padding: const EdgeInsets.all(Sp.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Rad.lg),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [AppColors.primaryFixed.withValues(alpha: 0.6), AppColors.surfaceContainerLow]),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainerLowest, fg: AppColors.onSurface, shadow: Shadows.tiny, onTap: () => goBack(context, '/blood-report')),
              const Spacer(),
              TagPill('Decoded with VitalU Care', icon: Symbols.verified, bg: AppColors.surfaceContainerLowest, fg: AppColors.primary, iconColor: AppColors.primary),
              if (r != null) ...[const SizedBox(width: 6), CircleButton(Symbols.delete, size: 36, iconSize: 18, onTap: _delete)],
            ]),
            const SizedBox(height: Sp.sm),
            Text('Your Report, Explained', style: T.headlineMd.s(24)),
            const SizedBox(height: 4),
            Text('Demystified routine student lab values in plain, gentle English.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            VCard(
              padding: const EdgeInsets.all(12),
              shadow: Shadows.tiny,
              child: Row(children: [
                const SizedBox(width: 88, height: 72, child: AssetImg('decoded_report', radius: 16)),
                const SizedBox(width: Sp.sm),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TagPill(r?['panel_name'] ?? 'Lab Panel', icon: Symbols.circle, fill: 1, bg: AppColors.tertiaryFixed.withValues(alpha: 0.6), fg: AppColors.onTertiaryFixedVariant, iconColor: AppColors.tertiary),
                    const SizedBox(height: 6),
                    if (vals.isNotEmpty)
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '${vals.length - flagged.length} of ${vals.length} indicators', style: T.labelMd),
                          TextSpan(
                              text: ' in your optimal zone. ${flagged.isEmpty ? 'Lovely balance!' : '${flagged.length} item${flagged.length == 1 ? '' : 's'} for gentle observation.'}',
                              style: T.bodySm.c(AppColors.onSurfaceVariant)),
                        ]),
                      )
                    else
                      Text(
                          switch (r?['status']) {
                            'failed' => 'We could not read this report yet.',
                            'done' => r?['summary'] ?? 'No values found.',
                            _ => 'Your report is being decoded…',
                          },
                          style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        if (_loading) const Loading(),
        if (!_loading && r == null) const EmptyState(icon: Symbols.lab_profile, title: 'Report not found', text: 'It may have been deleted.'),
        if (r != null && vals.isEmpty)
          VCard(
            shadow: Shadows.card,
            child: Column(children: [
              IconCircle(r['status'] == 'failed' ? Symbols.error : Symbols.hourglass_top, size: 56, bg: AppColors.surfaceContainerLow),
              const SizedBox(height: Sp.sm),
              Text(r['status'] == 'failed' ? 'We couldn\'t decode this one' : 'Still decoding', style: T.headlineSm),
              const SizedBox(height: 4),
              Text(
                  r['status'] == 'failed'
                      ? (r['error']?.toString().contains('GEMINI') == true
                          ? 'The report reader is not configured yet. Please try again later.'
                          : 'Blurry photos or unusual layouts can be tricky. You can retry, or upload a clearer photo or PDF.')
                      : 'This usually takes under a minute. Pull down to refresh.',
                  textAlign: TextAlign.center,
                  style: T.bodySm.c(AppColors.onSurfaceVariant)),
              const SizedBox(height: Sp.md),
              PrimaryButton('Try decoding again', leadingIcon: Symbols.refresh, loading: _retrying, onTap: _retrying ? null : _retry),
            ]),
          ),
        if (vals.isNotEmpty) ...[
          FullBleed(
            child: ChipRow(children: [
              for (final c in cats)
                VChip(c.$1 == 'all' ? '${c.$2} (${vals.length})' : c.$2,
                    icon: c.$1 == 'all' ? Symbols.check_circle : null,
                    selected: _cat == c.$1,
                    selectedColor: AppColors.inverseSurface,
                    selectedFg: AppColors.inverseOnSurface,
                    color: AppColors.surfaceContainer,
                    onTap: () => setState(() => _cat = c.$1)),
            ]),
          ),
          for (final v in shown) _LabCard(v),
          VCard(
            color: AppColors.secondaryFixed.withValues(alpha: 0.35),
            shadow: Shadows.tiny,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconCircle(Symbols.medical_services, size: 40, iconSize: 20, bg: AppColors.secondaryFixed, fg: AppColors.secondary, radius: 12),
                const SizedBox(width: Sp.sm),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Campus Care Check-in', style: T.headlineSm),
                    const SizedBox(height: 2),
                    Text(
                        flagged.isEmpty
                            ? 'Everything looks balanced. A routine yearly check with campus doctors keeps it that way.'
                            : 'Some values (like your ${flagged.first.name}) may benefit from a quick professional glance. Campus doctors can provide tailored guidance.',
                        style: T.bodySm.c(AppColors.onSurfaceVariant)),
                  ]),
                ),
              ]),
              const SizedBox(height: Sp.md),
              PrimaryButton('Book Campus Health Consult', leadingIcon: Symbols.calendar_today, height: 52, onTap: _book),
              const SizedBox(height: 4),
              Center(child: TextLinkButton('Download Decoded PDF', leading: Symbols.download, color: AppColors.primary, onTap: _pdf)),
            ]),
          ),
        ],
        VCard(
          color: AppColors.surfaceContainer,
          child: Column(children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Symbols.lock, size: 16, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('Stored privately in your account', style: T.labelSm.c(AppColors.onSurfaceVariant)),
            ]),
            const SizedBox(height: 6),
            Text(
                'Decoded for educational wellness purposes. VitalU does not provide formal diagnosis or treatment plans. AI can misread values — always check your original report and consult your university health provider for clinical decisions.',
                textAlign: TextAlign.center,
                style: T.bodySm.c(AppColors.outline)),
          ]),
        ),
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
    final accent = good ? AppColors.tertiary : AppColors.secondary;
    return VCard(
      shadow: Shadows.card,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconCircle(v.icon, size: 40, iconSize: 20, bg: AppColors.surfaceContainerLow),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.name, style: T.headlineSm.lh(1.25)),
              if (v.subtitle.isNotEmpty) Text(v.subtitle, style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 6),
          TagPill(v.statusLabel,
              icon: good ? Symbols.check : (v.status == 'low' ? Symbols.south : Symbols.north),
              bg: good ? AppColors.tertiaryFixed.withValues(alpha: 0.6) : AppColors.secondaryFixed,
              fg: good ? AppColors.onTertiaryFixedVariant : AppColors.onSecondaryFixedVariant,
              iconColor: accent),
        ]),
        const SizedBox(height: Sp.md),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(v.valueText, style: T.headlineLg.c(good ? AppColors.onSurface : AppColors.secondary)),
          const SizedBox(width: 4),
          Text(v.unit, style: T.bodySm.c(AppColors.onSurfaceVariant)),
          const Spacer(),
          Flexible(child: Text(v.reference, style: T.labelSm.c(AppColors.onSurfaceVariant).w(FontWeight.w500), textAlign: TextAlign.right)),
        ]),
        const SizedBox(height: 10),
        _Gauge(v),
        const SizedBox(height: Sp.sm),
        if (v.explanation.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: good ? AppColors.surfaceContainerLow : AppColors.secondaryFixed.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(Rad.base)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(v.tipIcon, size: 18, color: good ? AppColors.primary : AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(child: Text(v.explanation, style: T.bodySm.c(AppColors.onSurface))),
            ]),
          ),
      ]),
    );
  }
}

/// Three-zone gauge (low / in-range / high) with a pin at the value.
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
    const pink = Color(0xFFFFC7D9), mint = Color(0xFF9EEBC6), lav = Color(0xFFD9D0FF);
    String n(double x) => LabValue._fmt(x);
    final labels = [
      if (lo != null) 'Low (<${n(lo)})',
      lo != null && hi != null ? 'Optimal' : (hi != null ? '<${n(hi)} Desirable' : '≥${n(lo!)} Optimal'),
      if (hi != null) 'High (>${n(hi)})',
    ];
    return Column(children: [
      LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: 14,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              top: 3,
              bottom: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(children: [
                  if (a > 0) Expanded(flex: (a * 1000).round().clamp(1, 1000), child: Container(color: lo == null ? mint : lav)),
                  Expanded(flex: ((b - a) * 1000).round().clamp(1, 1000), child: Container(color: mint)),
                  if (b < 1) Expanded(flex: ((1 - b) * 1000).round().clamp(1, 1000), child: Container(color: pink)),
                ]),
              ),
            ),
            Positioned(
              left: (pos * w - 7).clamp(0, w - 14),
              top: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: v.inRange ? AppColors.tertiary : AppColors.secondary, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: Shadows.tiny),
              ),
            ),
          ]),
        );
      }),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final l in labels) Text(l, style: T.labelSm.s(10).c(AppColors.onSurfaceVariant).w(FontWeight.w500)),
      ]),
    ]);
  }
}
