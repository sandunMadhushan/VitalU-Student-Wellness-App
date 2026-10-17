import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../data/catalog.dart';
import '../../data/models.dart';

/// One answer choice. A higher [score] is a healthier answer; null means the
/// question is descriptive and not scored. [image] is an asset under
/// `assets/` and [icon] a Material Symbols name, both optional.
class AOption {
  const AOption(this.value, this.label, {this.hint, this.score, this.image, this.icon});
  final String value;
  final String label;
  final String? hint;
  final num? score;
  final String? image;
  final String? icon;

  /// "None" and "prefer not to say" clear every other choice.
  bool get exclusive => value == 'none' || value == 'pns';

  factory AOption.fromJson(Map<String, dynamic> j) => AOption(
        '${j['value']}',
        '${j['label']}',
        hint: j['hint'] as String?,
        score: j['score'] as num?,
        image: j['image'] as String?,
        icon: j['icon'] as String?,
      );
}

/// `profile` shows the student's saved details to confirm or update.
enum AKind { single, multi, scale, number, text, profile }

class AQuestion {
  const AQuestion({
    required this.id,
    required this.domain,
    required this.kind,
    required this.text,
    this.help,
    this.options = const [],
    this.unit,
    this.min,
    this.max,
    this.maxChoices,
    this.prefill,
    this.optional = false,
    this.style,
    this.image,
    this.showIf,
  });

  final String id;
  final int domain;
  final AKind kind;
  final String text;
  final String? help;
  final List<AOption> options;
  final String? unit;
  final double? min;
  final double? max;
  final int? maxChoices;

  /// Profile or vitals value used to pre-fill the answer, e.g. height_cm.
  final String? prefill;
  final bool optional;

  /// How a single-choice question is drawn: `days` (food photo and a
  /// days-of-the-week picker), `faces`, `slider` (illustrated) or cards.
  final String? style;

  /// Picture shown above the question, an asset under `assets/`.
  final String? image;

  /// Ask only when another answer allows it: {"q": id, "not_in": [values]}.
  final Map<String, dynamic>? showIf;

  bool get scored => options.any((o) => o.score != null);

  /// Whether the question applies, given the answers so far.
  bool visible(Map<String, dynamic> answers) {
    final rule = showIf;
    if (rule == null) return true;
    final v = answers[rule['q']];
    if (v == null) return true;
    final notIn = List<String>.from(rule['not_in'] ?? const []);
    final inList = List<String>.from(rule['in'] ?? const []);
    if (notIn.contains('$v')) return false;
    if (inList.isNotEmpty && !inList.contains('$v')) return false;
    return true;
  }

  factory AQuestion.fromJson(Map<String, dynamic> j) => AQuestion(
        id: j['id'] as String,
        domain: ((j['domain_id'] ?? j['domain']) as num).toInt(),
        kind: AKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => AKind.single),
        text: j['text'] as String,
        help: j['help'] as String?,
        options: [for (final o in (j['options'] as List? ?? const [])) AOption.fromJson(Map<String, dynamic>.from(o as Map))],
        unit: j['unit'] as String?,
        min: ((j['min_value'] ?? j['min']) as num?)?.toDouble(),
        max: ((j['max_value'] ?? j['max']) as num?)?.toDouble(),
        maxChoices: (j['max_choices'] as num?)?.toInt(),
        prefill: j['prefill'] as String?,
        optional: j['optional'] as bool? ?? false,
        style: j['style'] as String?,
        image: j['image'] as String?,
        showIf: j['show_if'] == null ? null : Map<String, dynamic>.from(j['show_if'] as Map),
      );
}

class ADomain {
  const ADomain(this.id, this.title, this.blurb, this.icon, {this.active = true});
  final int id;
  final String title;
  final String blurb;
  final String icon;

  /// The administration can hide a whole section for a round (for example
  /// clinical measurements when the health centre has not measured students).
  final bool active;

  IconData get iconData => iconByName(icon);

  factory ADomain.fromJson(Map<String, dynamic> j) => ADomain(
        (j['id'] as num).toInt(),
        j['title'] as String,
        (j['blurb'] as String?) ?? '',
        (j['icon'] as String?) ?? 'assignment',
        active: j['active'] as bool? ?? true,
      );
}

/// The ten areas the campus administration asked to cover, plus clinical
/// measurements. Kept in code for icons and names on summary screens.
const defaultDomains = <ADomain>[
  ADomain(1, 'Physical and cardiometabolic health', 'Your details and recent health history.', 'monitor_heart'),
  ADomain(2, 'Dietary behaviours and food security', 'Think about the last 7 days.', 'restaurant'),
  ADomain(3, 'Academic workload and time pressure', 'How study fits around the rest of life.', 'school'),
  ADomain(4, 'Emotional well-being and stress', 'How you have been feeling lately.', 'psychology'),
  ADomain(5, 'Sleep and daily routines', 'Rest and the rhythm of your days.', 'bedtime'),
  ADomain(6, 'Physical activity and sedentary behaviour', 'Moving and sitting through the week.', 'directions_walk'),
  ADomain(7, 'Financial and living conditions', 'Where you stay and how money affects health.', 'savings'),
  ADomain(8, 'Social environment and personal support', 'The people around you.', 'diversity_3'),
  ADomain(9, 'Campus environment and access to services', 'Food, spaces and health services on campus.', 'local_hospital'),
  ADomain(10, 'Student voice and institutional priorities', 'What the university should do next.', 'campaign'),
  ADomain(11, 'Clinical measurements', 'Your latest measured values.', 'stethoscope'),
];

/// Short names for charts and summaries.
const domainShortNames = {
  1: 'Physical health',
  2: 'Diet and food security',
  3: 'Academic pressure',
  4: 'Emotional well-being',
  5: 'Sleep and routine',
  6: 'Physical activity',
  7: 'Money and living',
  8: 'Social support',
  9: 'Campus and services',
  10: 'Student voice',
  11: 'Clinical measurements',
};

/// The questionnaire bundled with the app (generated from
/// `supabase/seed/assessment_questionnaire.json`), used when the database
/// cannot be reached.
Future<(List<ADomain>, List<AQuestion>)> bundledQuestionnaire() async {
  final j = jsonDecode(await rootBundle.loadString('assets/assessment/questionnaire.json')) as Map<String, dynamic>;
  return (
    [for (final d in j['domains'] as List) ADomain.fromJson(Map<String, dynamic>.from(d as Map))],
    [for (final q in j['questions'] as List) AQuestion.fromJson(Map<String, dynamic>.from(q as Map))],
  );
}

/// PHQ-2 (Kroenke et al., 2003): two items scored 0 to 3, total 0 to 6.
/// A total of 3 or more is a positive screen, never a diagnosis.
const phq2Items = ['e_phq1', 'e_phq2'];
const phq2Cutoff = 3;

/// Scores a completed questionnaire: a 0 to 100 well-being score for each
/// domain (higher is healthier), an overall average, BMI and waist-to-hip
/// ratio, and the PHQ-2 total. [profile] fills in body measurements when the
/// clinical section was hidden or skipped.
(Map<String, dynamic>, String) scoreAssessment(List<AQuestion> questions, Map<String, dynamic> answers, {Profile? profile}) {
  final perDomain = <int, List<double>>{};
  for (final q in questions) {
    if (!q.scored || q.kind == AKind.multi) continue;
    final v = answers[q.id];
    if (v == null) continue;
    final opt = q.options.where((o) => o.value == '$v').firstOrNull;
    if (opt?.score == null) continue;
    final max = q.options.map((o) => o.score ?? 0).fold<num>(0, (a, b) => b > a ? b : a);
    if (max <= 0) continue;
    perDomain.putIfAbsent(q.domain, () => []).add(opt!.score! / max);
  }
  final domains = {for (final e in perDomain.entries) '${e.key}': (e.value.reduce((a, b) => a + b) / e.value.length * 100).round()};
  final overall = domains.isEmpty ? null : (domains.values.reduce((a, b) => a + b) / domains.length).round();

  double? n(List<String> keys) {
    for (final k in keys) {
      final v = answers[k] == null ? null : double.tryParse('${answers[k]}');
      if (v != null) return v;
    }
    return null;
  }

  final height = n(['k_height', 'p_height']), weight = n(['k_weight', 'p_weight']);
  final waist = n(['k_waist', 'p_waist']), hip = n(['k_hip', 'p_hip']);
  final measured = height != null && weight != null;
  final bmi = Calc.bmi(height ?? profile?.heightCm, weight ?? profile?.weightKg);
  final whr = Calc.whr(waist ?? profile?.waistCm, hip ?? profile?.hipCm);
  final phq = phq2Items.every((k) => answers[k] != null) ? phq2Items.fold<int>(0, (a, k) => a + (int.tryParse('${answers[k]}') ?? 0)) : null;

  final label = overall == null
      ? 'Completed'
      : overall >= 75
          ? 'Healthy habits'
          : overall >= 55
              ? 'Mostly on track'
              : overall >= 35
                  ? 'Room to improve'
                  : 'Needs attention';
  return ({
    'domains': domains,
    'overall': ?overall,
    if (bmi != null) 'bmi': double.parse(bmi.toStringAsFixed(1)),
    if (bmi != null) 'bmi_source': measured ? (answers['k_source'] ?? 'answered') : 'profile',
    if (whr != null) 'whr': double.parse(whr.toStringAsFixed(2)),
    'phq2': ?phq,
    if (phq != null) 'phq2_positive': phq >= phq2Cutoff,
  }, label);
}
