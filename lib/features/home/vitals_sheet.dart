import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Lets the student record blood pressure, fasting blood glucose and
/// triglycerides from a clinic visit or a lab report. Returns true if saved.
Future<bool> showVitalsSheet(BuildContext context) async {
  final sys = TextEditingController(), dia = TextEditingController();
  final fbg = TextEditingController(), tg = TextEditingController();
  var day = DateTime.now();
  var saved = false;
  final digits = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];

  Widget field(TextEditingController c, String hint, String unit) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: digits,
        style: T.bodyLg.tnum,
        decoration: InputDecoration(hintText: hint, suffixText: unit, isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
      );

  Widget label(String image, String title, String note) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/icons3d/$image.jpg', width: 36, height: 36, fit: BoxFit.cover)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.labelLg.w(FontWeight.w700)),
              Text(note, style: T.bodySm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
        ]),
      );

  await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Log a reading', style: T.headlineMd),
          const SizedBox(height: 4),
          Text('From a clinic visit, a pharmacy check or a lab report. Fill in only what you have.', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: Sp.md),
          ListRow(
            icon: Symbols.event_rounded,
            color: AppColors.primary,
            title: 'Measured on',
            value: DateFormat('d MMM yyyy').format(day),
            onTap: () async {
              final d = await showDatePicker(context: ctx, initialDate: day, firstDate: DateTime.now().subtract(const Duration(days: 730)), lastDate: DateTime.now());
              if (d != null) set(() => day = d);
            },
          ),
          const SizedBox(height: Sp.md),
          label('bp', 'Blood pressure', 'Upper (systolic) and lower (diastolic) numbers'),
          Row(children: [
            Expanded(child: field(sys, 'Systolic', 'mmHg')),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('/', style: T.headlineMd.c(AppColors.outline))),
            Expanded(child: field(dia, 'Diastolic', 'mmHg')),
          ]),
          const SizedBox(height: Sp.md),
          label('glucose', 'Fasting blood glucose', 'After at least 8 hours without food'),
          field(fbg, 'For example 92', 'mg/dL'),
          const SizedBox(height: Sp.md),
          label('tg', 'Triglycerides', 'From a lipid profile'),
          field(tg, 'For example 130', 'mg/dL'),
          const SizedBox(height: Sp.lg),
          PrimaryButton('Save', onTap: () async {
            final s = int.tryParse(sys.text), d = int.tryParse(dia.text);
            final g = double.tryParse(fbg.text), t = double.tryParse(tg.text);
            if ((s == null) != (d == null)) return toast(ctx, 'Enter both blood pressure numbers, or leave both blank.', error: true);
            if (s != null && (s < 70 || s > 250 || d! < 40 || d > 150)) return toast(ctx, 'That blood pressure looks unusual. Please check it.', error: true);
            if (g != null && (g < 40 || g > 600)) return toast(ctx, 'That glucose value looks unusual. Please check it (mg/dL).', error: true);
            if (t != null && (t < 20 || t > 2000)) return toast(ctx, 'That triglyceride value looks unusual. Please check it (mg/dL).', error: true);
            if (s == null && g == null && t == null) return toast(ctx, 'Enter at least one reading.', error: true);
            try {
              await Repo.saveVitals(systolic: s, diastolic: d, fastingGlucose: g, triglycerides: t, measuredOn: day);
              saved = true;
              if (ctx.mounted) Navigator.pop(ctx);
            } catch (_) {
              if (ctx.mounted) toast(ctx, 'Could not save right now. Please try again later.', error: true);
            }
          }),
          const SizedBox(height: Sp.sm),
          const PrivacyNote('Only you can see these readings. They are not a diagnosis.'),
        ]);
      }));
  return saved;
}
