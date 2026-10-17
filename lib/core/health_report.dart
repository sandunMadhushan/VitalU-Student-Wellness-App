import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models.dart';
import '../data/repo.dart';
import '../features/diet/pdqs_screen.dart' show pdqsGroups, pdqsPoints, pdqsBand;
import '../features/profile/about_screen.dart' show ResearchTeam;
import '../features/tools/psqi_screen.dart' show Psqi;
import 'app_state.dart';

/// The student's one-page Personal Health Report, laid out like the study's
/// paper report: measurements against healthy ranges with a coloured status,
/// overall heart risk, diet quality, stress, sleep and activity, the last
/// week at a glance, and plain-language recommendations.
class HealthReport {
  HealthReport._();

  static const _ink = PdfColor.fromInt(0xFF1D2433);
  static const _muted = PdfColor.fromInt(0xFF5B6475);
  static const _head = PdfColor.fromInt(0xFF0F7D67);
  static const _band = PdfColor.fromInt(0xFFE7F3EF);
  static const _good = PdfColor.fromInt(0xFFD9F2E3);
  static const _goodInk = PdfColor.fromInt(0xFF1B7A43);
  static const _warn = PdfColor.fromInt(0xFFFFF0C2);
  static const _warnInk = PdfColor.fromInt(0xFF8A6100);
  static const _bad = PdfColor.fromInt(0xFFF9D6D9);
  static const _badInk = PdfColor.fromInt(0xFFB0222F);

  /// 0 healthy, 1 borderline, 2 high, null not measured.
  static (PdfColor, PdfColor) _tone(int? level) => switch (level) {
        0 => (_good, _goodInk),
        1 => (_warn, _warnInk),
        null => (PdfColors.white, _muted),
        _ => (_bad, _badInk),
      };

  static Future<void> share() async {
    final bytes = await build();
    await Printing.sharePdf(bytes: bytes, filename: 'VitalU_Personal_Health_Report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf');
  }

  static Future<T?> _try<T>(Future<T> f) async {
    try {
      return await f;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List> build() async {
    final p = AppState.instance.profile;
    final now = DateTime.now();
    final from = dayStart(now).subtract(const Duration(days: 6));
    final vitals = await _try(Repo.latestVitals()) ?? const LatestVitals();
    final cvd = await _try(Repo.latestToolResult('cvd'));
    final pdqs = await _try(Repo.latestToolResult('pdqs'));
    final stress = await _try(Repo.latestToolResult('stress'));
    final psqi = await _try(Repo.latestToolResult('psqi'));
    final ipaq = await _try(Repo.latestToolResult('ipaq'));
    final water = await _try(Repo.waterByDay(7)) ?? const <String, int>{};
    final steps = await _try(Repo.stepsByDay(from, now)) ?? const <String, int>{};
    final sleep = await _try(Repo.sleepBetween(from, now)) ?? const <Rec>[];
    final earned = await _try(Repo.earnedBadges()) ?? const <String, DateTime>{};
    final badges = await _try(Repo.badges()) ?? const <Rec>[];

    final female = p?.sex != 'male';
    final rows = <List<Object?>>[];
    final advice = <String>[];
    String f1(num? v) => v == null ? '–' : v.toStringAsFixed(1);

    rows.add(['Height (cm)', p?.heightCm?.round().toString() ?? '–', '–', null, '–']);
    rows.add(['Weight (kg)', f1(p?.weightKg), '–', null, '–']);

    final bmi = p?.bmi;
    if (bmi != null) {
      final cat = Calc.bmiCategory(bmi);
      final level = switch (cat) { 'Normal Weight' => 0, 'Overweight' => 1, 'Underweight' => 1, _ => 2 };
      rows.add(['Body Mass Index, BMI (kg/m²)', f1(bmi), '18.5 – 24.9', level, cat == 'Normal Weight' ? 'Healthy' : cat]);
      advice.add(switch (cat) {
        'Underweight' => 'Weight (BMI): below the healthy range. Add a nourishing snack such as milk, nuts, eggs or a banana between meals, and do not skip meals.',
        'Normal Weight' => 'Weight (BMI): in the healthy range. Keep up regular meals, plenty of vegetables and daily movement.',
        'Overweight' => 'Weight (BMI): above the healthy range. Fill half the plate with vegetables, keep rice to one fist, choose water over sugary drinks and walk at least 30 minutes on most days.',
        _ => 'Weight (BMI): well above the healthy range. Cut down on fried food, short eats and sugary drinks, walk 30 minutes a day, and consider talking to a doctor or dietitian.',
      });
    } else {
      rows.add(['Body Mass Index, BMI (kg/m²)', '–', '18.5 – 24.9', null, 'Not measured']);
    }

    final waist = p?.waistCm;
    final waistCut = female ? 80 : 90;
    rows.add(['Waist circumference (cm)', waist?.round().toString() ?? '–', 'Below $waistCut', waist == null ? null : (waist < waistCut ? 0 : 2), waist == null ? 'Not measured' : (waist < waistCut ? 'Healthy' : 'Above healthy range')]);
    final whr = p?.whr;
    if (whr != null) {
      final (cat, _) = Calc.whrCategory(whr, p?.sex ?? 'female');
      final (_, hi) = Calc.whrThresholds(p?.sex ?? 'female');
      rows.add(['Waist-to-hip ratio', whr.toStringAsFixed(2), 'Below ${hi.toStringAsFixed(2)}', cat == 'Low Risk' ? 0 : (cat == 'Moderate Risk' ? 1 : 2), cat.replaceAll(' Risk', ' risk')]);
    }
    if (waist != null && p?.heightCm != null) {
      final wht = waist / p!.heightCm!;
      rows.add(['Waist-to-height ratio', wht.toStringAsFixed(2), 'Below 0.50', wht < 0.5 ? 0 : 2, wht < 0.5 ? 'Healthy' : 'Above healthy range']);
      if (wht >= 0.5 || (whr != null && Calc.whrCategory(whr, p.sex ?? 'female').$1 != 'Low Risk')) {
        advice.add('Waist: extra fat around the middle raises the risk of type 2 diabetes and heart disease. Regular walking, fewer sugary drinks and more vegetables help reduce it.');
      }
    }

    final bp = vitals.bp;
    if (bp != null) {
      final (label, level) = VitalBands.bp(bp.value, bp.extra!);
      rows.add(['Blood pressure (mmHg)', '${bp.value.round()} / ${bp.extra!.round()}', '120 / 80 or below', level.clamp(0, 2), label]);
      if (level > 0) advice.add('Blood pressure: $label. Use less salt, eat fewer salty snacks and instant noodles, stay active every day, and have it checked again in a few months.');
    } else {
      rows.add(['Blood pressure (mmHg)', '–', '120 / 80 or below', null, 'Not measured']);
    }
    final fbg = vitals.fastingGlucose;
    if (fbg != null) {
      final (label, level) = VitalBands.fastingGlucose(fbg.value);
      rows.add(['Fasting blood sugar (mg/dL)', fbg.value.round().toString(), 'Below 100', level.clamp(0, 2), label]);
      advice.add(level == 0 ? 'Blood sugar: your fasting blood sugar is normal.' : 'Blood sugar: $label. Cut down on sugary drinks and sweets, choose red rice or kurakkan, and see a doctor for a repeat test.');
    } else {
      rows.add(['Fasting blood sugar (mg/dL)', '–', 'Below 100', null, 'Not measured']);
    }
    final tg = vitals.triglycerides;
    if (tg != null) {
      final (label, level) = VitalBands.triglycerides(tg.value);
      rows.add(['Triglycerides, blood fat (mg/dL)', tg.value.round().toString(), 'Below 150', level.clamp(0, 2), label]);
      advice.add(level == 0 ? 'Triglycerides: your blood fat level is normal.' : 'Triglycerides: $label. Fewer fried foods, sweets and sugary drinks, plus daily activity, bring them down.');
    } else {
      rows.add(['Triglycerides, blood fat (mg/dL)', '–', 'Below 150', null, 'Not measured']);
    }

    // Overall heart risk from the heart risk check.
    final cvdScore = (cvd?['score'] as num?)?.round();
    final cvdMax = ((cvd?['data'] as Map?)?['max'] as num?)?.round();
    final cvdCat = cvd?['category'] as String?;
    int? cvdLevel(String? c) => c == null ? null : (c.toLowerCase().contains('low') ? 0 : (c.toLowerCase().contains('moderate') ? 1 : 2));

    // Diet quality.
    final pdqsScore = (pdqs?['score'] as num?)?.round();
    final answers = Map<String, dynamic>.from(((pdqs?['data'] as Map?)?['answers'] as Map?) ?? const {});
    final eatMore = [for (final g in pdqsGroups) if (g.healthy && answers[g.key] != null && pdqsPoints(g, (answers[g.key] as num).toInt()) == 0) g.label];
    final eatLess = [for (final g in pdqsGroups) if (!g.healthy && answers[g.key] != null && pdqsPoints(g, (answers[g.key] as num).toInt()) == 0) g.label];
    if (pdqsScore != null) {
      advice.add(pdqsScore >= 28
          ? 'Eating habits: your diet quality is good. Keep eating a variety of vegetables, fruit, pulses and fish.'
          : 'Eating habits: add more ${eatMore.isEmpty ? 'vegetables, fruit and pulses' : eatMore.take(3).join(', ').toLowerCase()}${eatLess.isEmpty ? '' : ', and have ${eatLess.take(2).join(' and ').toLowerCase()} less often'}. Try not to skip meals.');
    }

    // Stress, sleep and activity.
    final stressScore = (stress?['score'] as num?)?.round();
    final stressCat = stress?['category'] as String?;
    if (stressCat != null) {
      advice.add(stressCat == 'Normal'
          ? 'Stress: your stress level is in the normal range. Keep a good balance of study, rest, sleep and time with friends.'
          : 'Stress: your stress level is $stressCat. Short breaks, the breathing exercise in VitalU and talking to someone you trust can help. A university counsellor is always available.');
    }
    final psqiScore = Psqi.scoreOf(psqi);
    if (psqiScore != null && psqiScore < 75) {
      advice.add('Sleep: your sleep quality score is below the healthy level. Keep the same sleep and wake-up times every day, avoid caffeine after 4 PM and screens for 45 minutes before bed, and keep your room dark, quiet and cool.');
    }
    final ipaqCat = ipaq?['category'] as String?;
    if (ipaqCat == 'Low') advice.add('Activity: you are less active than recommended. Aim for 150 minutes of moderate activity a week, such as brisk walking between lectures.');

    double avg(Iterable<num> v) => v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
    final days = [for (int i = 6; i >= 0; i--) isoDate(dayStart(now).subtract(Duration(days: i)))];
    final waterAvg = avg(days.map((d) => (water[d] ?? 0) / 1000));
    final stepAvg = avg(days.map((d) => steps[d] ?? 0)).round();
    final sleepAvg = avg(sleep.map((s) => Repo.sleepMinutes(s) / 60));

    // --- Document ----------------------------------------------------------
    final doc = pw.Document(title: 'Personal Health Report', author: 'VitalU');
    final t9 = pw.TextStyle(fontSize: 8.5, color: _ink);
    final t9b = t9.copyWith(fontWeight: pw.FontWeight.bold);
    final t8m = pw.TextStyle(fontSize: 7.5, color: _muted);

    pw.Widget cell(String text, {pw.TextStyle? style, PdfColor? bg, pw.Alignment align = pw.Alignment.centerLeft}) =>
        pw.Container(color: bg, alignment: align, padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: pw.Text(text, style: style ?? t9));

    pw.Widget band(String title, String score, String status, int? level, {String? note}) {
      final (bg, ink) = _tone(level);
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Table(columnWidths: const {0: pw.FlexColumnWidth(5), 1: pw.FlexColumnWidth(2.4), 2: pw.FlexColumnWidth(2)}, children: [
          pw.TableRow(children: [
            cell(title, style: t9b.copyWith(color: _head), bg: _band),
            cell(score, style: t9b, bg: _band, align: pw.Alignment.center),
            cell(status, style: t9b.copyWith(color: ink), bg: level == null ? _band : bg, align: pw.Alignment.center),
          ]),
        ]),
        if (note != null) pw.Padding(padding: const pw.EdgeInsets.fromLTRB(6, 3, 6, 0), child: pw.Text(note, style: t8m)),
        pw.SizedBox(height: 8),
      ]);
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
      build: (ctx) => [
        pw.Center(child: pw.Text('${ResearchTeam.university}  |  ${ResearchTeam.faculty}  |  ${ResearchTeam.department}', style: t8m)),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('PERSONAL HEALTH REPORT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: _head))),
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text('Study: ${ResearchTeam.title}', style: t8m.copyWith(fontStyle: pw.FontStyle.italic), textAlign: pw.TextAlign.center)),
        pw.Divider(color: _head, thickness: 1.2),
        pw.Table(columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(3), 2: pw.FlexColumnWidth(2), 3: pw.FlexColumnWidth(3)}, children: [
          pw.TableRow(children: [cell('Name', style: t9b), cell(p?.fullName ?? '–'), cell('Registration No.', style: t9b), cell(p?.registrationNumber ?? '–')]),
          pw.TableRow(children: [
            cell('Sex / Age', style: t9b),
            cell('${p?.sex == null ? '–' : (p!.sex == 'male' ? 'Male' : 'Female')} / ${p?.age == null ? '–' : '${p!.age} years'}'),
            cell('Report date', style: t9b),
            cell(DateFormat('d MMMM yyyy').format(now)),
          ]),
          pw.TableRow(children: [cell('Faculty', style: t9b), cell(p?.faculty?.replaceFirst('Faculty of ', '') ?? '–'), cell('Measured', style: t9b), cell(p?.measuredAt == null ? '–' : DateFormat('d MMM yyyy').format(p!.measuredAt!.toLocal()))]),
        ]),
        pw.SizedBox(height: 10),
        pw.Table(
          columnWidths: const {0: pw.FlexColumnWidth(4.2), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(2.4), 3: pw.FlexColumnWidth(2.4)},
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColor.fromInt(0xFFE3E7EC), width: 0.6)),
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: _head), children: [
              for (final h in ['Measurement', 'Your result', 'Healthy range', 'Your status']) cell(h, style: t9b.copyWith(color: PdfColors.white), align: h == 'Measurement' ? pw.Alignment.centerLeft : pw.Alignment.center),
            ]),
            for (final r in rows)
              pw.TableRow(children: [
                cell(r[0] as String),
                cell(r[1] as String, style: t9b, align: pw.Alignment.center),
                cell(r[2] as String, align: pw.Alignment.center),
                cell(r[4] as String, style: t9b.copyWith(color: _tone(r[3] as int?).$2), bg: _tone(r[3] as int?).$1, align: pw.Alignment.center),
              ]),
          ],
        ),
        pw.SizedBox(height: 10),
        band('Overall heart risk (VitalU heart risk check)', cvdScore == null ? 'Not checked' : 'Score: $cvdScore${cvdMax == null ? '' : ' / $cvdMax'}', cvdCat ?? '–', cvdLevel(cvdCat),
            note: cvdScore == null ? 'Complete the heart risk check in Tools to add this.' : 'A summary of your heart risk factors. Small changes now, like more vegetables and fruit, more activity and better sleep, can lower your future risk.'),
        band('Diet quality score (PDQS)', pdqsScore == null ? 'Not checked' : 'Score: $pdqsScore / 42', pdqsScore == null ? '–' : pdqsBand(pdqsScore).$1.replaceAll(' diet quality', ''), pdqsScore == null ? null : (pdqsScore >= 28 ? 0 : (pdqsScore >= 21 ? 1 : 2)),
            note: pdqsScore == null ? null : 'A higher score means a healthier diet.${eatMore.isEmpty ? '' : '  Foods to eat more often: ${eatMore.join(', ')}.'}  Foods to eat less often: ${eatLess.isEmpty ? 'none, well done' : eatLess.join(', ')}.'),
        band('Stress level (DASS-21)', stressScore == null ? 'Not checked' : 'Score: $stressScore / 42', stressCat ?? '–', stressCat == null ? null : (stressCat == 'Normal' ? 0 : (stressCat == 'Mild' || stressCat == 'Moderate' ? 1 : 2))),
        band('Sleep quality score (adapted from PSQI)', psqiScore == null ? 'Not checked' : 'Score: $psqiScore / ${Psqi.max}', psqiScore == null ? '–' : Psqi.tier(psqiScore).short, psqiScore == null ? null : Psqi.tier(psqiScore).level,
            note: psqiScore == null ? null : 'A higher score means better sleep. 75 or more is good.'),
        band('Physical activity (IPAQ short form)', ipaq == null ? 'Not checked' : '${(ipaq['score'] as num).round()} MET-min/week', ipaqCat ?? '–', ipaqCat == null ? null : (ipaqCat == 'Low' ? 2 : (ipaqCat == 'Moderate' ? 0 : 0))),
        pw.Text('Your last 7 days', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _head)),
        pw.SizedBox(height: 4),
        pw.Table(columnWidths: const {0: pw.FlexColumnWidth(), 1: pw.FlexColumnWidth(), 2: pw.FlexColumnWidth(), 3: pw.FlexColumnWidth()}, children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: _band), children: [
            cell('Water: ${waterAvg.toStringAsFixed(1)} L a day', style: t9b),
            cell('Steps: ${NumberFormat.decimalPattern().format(stepAvg)} a day', style: t9b),
            cell('Sleep: ${sleep.isEmpty ? '–' : '${sleepAvg.toStringAsFixed(1)} h a night'}', style: t9b),
            cell('Badges: ${earned.length} of ${badges.isEmpty ? 5 : badges.length}', style: t9b),
          ]),
        ]),
        pw.SizedBox(height: 10),
        pw.Text('What your results mean and what you can do', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _head)),
        pw.SizedBox(height: 4),
        if (advice.isEmpty) pw.Text('Add your measurements and complete the health checks in VitalU to see personal recommendations here.', style: t9),
        for (final a in advice)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('•  ', style: t9b),
              pw.Expanded(child: pw.Text(a, style: t9)),
            ]),
          ),
        pw.SizedBox(height: 10),
        pw.Text('Please note: this report is for screening and health education only. It is not a medical diagnosis. Measurements are as recorded in VitalU; a single reading should be confirmed by a health professional. Your information is kept confidential.',
            style: t8m.copyWith(fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 4),
        pw.Text('Researcher: ${ResearchTeam.researcher} · ${ResearchTeam.email} · ${ResearchTeam.phone}', style: t8m),
        pw.Text('Supervisor: ${ResearchTeam.supervisor} · Co-supervisor: ${ResearchTeam.coSupervisor} · ${ResearchTeam.department}', style: t8m),
      ],
    ));
    return doc.save();
  }
}
