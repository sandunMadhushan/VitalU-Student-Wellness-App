import 'package:flutter/widgets.dart';

import '../../data/catalog.dart';
import '../../data/models.dart';

/// One answer choice. A higher [score] is a healthier answer; null means the
/// question is descriptive and not scored.
class AOption {
  const AOption(this.value, this.label, {this.hint, this.score});
  final String value;
  final String label;
  final String? hint;
  final num? score;

  factory AOption.fromJson(Map<String, dynamic> j) => AOption('${j['value']}', '${j['label']}', hint: j['hint'] as String?, score: j['score'] as num?);
}

enum AKind { single, multi, scale, number, text }

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

  /// Profile field used to pre-fill a number, e.g. height_cm.
  final String? prefill;
  final bool optional;

  bool get scored => options.any((o) => o.score != null);

  factory AQuestion.fromJson(Map<String, dynamic> j) => AQuestion(
        id: j['id'] as String,
        domain: (j['domain_id'] as num).toInt(),
        kind: AKind.values.firstWhere((k) => k.name == j['kind'], orElse: () => AKind.single),
        text: j['text'] as String,
        help: j['help'] as String?,
        options: [for (final o in (j['options'] as List? ?? const [])) AOption.fromJson(Map<String, dynamic>.from(o as Map))],
        unit: j['unit'] as String?,
        min: (j['min_value'] as num?)?.toDouble(),
        max: (j['max_value'] as num?)?.toDouble(),
        maxChoices: (j['max_choices'] as num?)?.toInt(),
        prefill: j['prefill'] as String?,
        optional: j['optional'] as bool? ?? false,
      );
}

class ADomain {
  const ADomain(this.id, this.title, this.blurb, this.icon);
  final int id;
  final String title;
  final String blurb;
  final String icon;

  IconData get iconData => iconByName(icon);

  factory ADomain.fromJson(Map<String, dynamic> j) => ADomain((j['id'] as num).toInt(), j['title'] as String, (j['blurb'] as String?) ?? '', (j['icon'] as String?) ?? 'assignment');
}

/// The ten areas the campus administration asked to cover.
const defaultDomains = <ADomain>[
  ADomain(1, 'Physical and cardiometabolic health', 'Your body measurements and general health.', 'monitor_heart'),
  ADomain(2, 'Dietary behaviours and food security', 'What and how regularly you eat.', 'restaurant'),
  ADomain(3, 'Academic workload and time pressure', 'How study fits around the rest of life.', 'school'),
  ADomain(4, 'Emotional well-being and stress', 'How you have been feeling lately.', 'psychology'),
  ADomain(5, 'Sleep and daily routines', 'Rest and the rhythm of your days.', 'bedtime'),
  ADomain(6, 'Physical activity and sedentary behaviour', 'Moving and sitting through the week.', 'directions_walk'),
  ADomain(7, 'Financial and living conditions', 'Where you stay and how money affects health.', 'savings'),
  ADomain(8, 'Social environment and personal support', 'The people around you.', 'diversity_3'),
  ADomain(9, 'Campus environment and access to services', 'Food, spaces and health services on campus.', 'local_hospital'),
  ADomain(10, 'Student voice and institutional priorities', 'What the university should do next.', 'campaign'),
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
};

List<AOption> _o(List<(String, String, num?)> l) => [for (final x in l) AOption(x.$1, x.$2, score: x.$3)];
final _never4 = _o([('0', 'Never', 4), ('1', 'Almost never', 3), ('2', 'Sometimes', 2), ('3', 'Fairly often', 1), ('4', 'Very often', 0)]);
final _never4Rev = _o([('0', 'Never', 0), ('1', 'Almost never', 1), ('2', 'Sometimes', 2), ('3', 'Fairly often', 3), ('4', 'Very often', 4)]);

/// The built-in questionnaire, the same as the database seed. Used only when
/// the questions cannot be loaded (for example, offline on first open).
final defaultQuestions = <AQuestion>[
  const AQuestion(id: 'p_height', domain: 1, kind: AKind.number, text: 'What is your height?', help: 'We filled this in from your profile. Change it if it is out of date.', unit: 'cm', min: 100, max: 230, prefill: 'height_cm', optional: true),
  const AQuestion(id: 'p_weight', domain: 1, kind: AKind.number, text: 'What is your weight?', help: 'A recent reading is perfect.', unit: 'kg', min: 25, max: 250, prefill: 'weight_kg', optional: true),
  const AQuestion(id: 'p_waist', domain: 1, kind: AKind.number, text: 'What is your waist measurement?', help: 'Measure midway between your lowest rib and hip bone, after breathing out.', unit: 'cm', min: 40, max: 200, prefill: 'waist_cm', optional: true),
  const AQuestion(id: 'p_hip', domain: 1, kind: AKind.number, text: 'What is your hip measurement?', help: 'Measure around the widest part of your hips.', unit: 'cm', min: 50, max: 200, prefill: 'hip_cm', optional: true),
  AQuestion(id: 'p_general', domain: 1, kind: AKind.scale, text: 'How would you rate your overall physical health right now?', options: _o([('1', 'Poor', 0), ('2', 'Fair', 1), ('3', 'Good', 2), ('4', 'Very good', 3), ('5', 'Excellent', 4)])),
  AQuestion(id: 'p_conditions', domain: 1, kind: AKind.multi, text: 'Has a doctor ever told you that you have any of these?', help: 'Select all that apply.', options: _o([
    ('high_bp', 'High blood pressure', null),
    ('diabetes', 'Diabetes or prediabetes', null),
    ('cholesterol', 'High cholesterol', null),
    ('asthma', 'Asthma', null),
    ('anaemia', 'Anaemia', null),
    ('thyroid', 'Thyroid condition', null),
    ('pcos', 'PCOS', null),
    ('none', 'None of these', null),
  ])),
  AQuestion(id: 'p_checkup', domain: 1, kind: AKind.single, text: 'When did you last have your blood pressure or blood sugar checked?', options: _o([('6m', 'Within the last 6 months', 3), ('12m', '6 to 12 months ago', 2), ('older', 'More than a year ago', 1), ('never', 'Never, or not sure', 0)])),
  AQuestion(id: 'd_breakfast', domain: 2, kind: AKind.single, text: 'How many days a week do you eat breakfast?', options: _o([('0-1', '0 to 1 days', 0), ('2-4', '2 to 4 days', 1), ('5-7', '5 to 7 days', 2)])),
  AQuestion(id: 'd_fruitveg', domain: 2, kind: AKind.single, text: 'On a typical day, how many servings of fruit and vegetables do you eat?', help: 'One serving is about a handful, or a small bowl of mallum.', options: _o([('0-1', '0 to 1 servings', 0), ('2-3', '2 to 3 servings', 1), ('4', '4 servings', 2), ('5+', '5 or more servings', 3)])),
  AQuestion(id: 'd_sugary', domain: 2, kind: AKind.single, text: 'How many sugary drinks do you have a day?', help: 'Soft drinks, sweet milk tea or coffee, packet juice.', options: _o([('0', 'None', 2), ('1', '1 a day', 1), ('2+', '2 or more a day', 0)])),
  AQuestion(id: 'd_fried', domain: 2, kind: AKind.single, text: 'How often do you eat fried or fast food?', help: 'Short eats, kottu, fried rice, instant noodles, burgers.', options: _o([('rare', 'Rarely', 3), ('1-2', '1 to 2 times a week', 2), ('3-5', '3 to 5 times a week', 1), ('daily', 'Almost every day', 0)])),
  AQuestion(id: 'd_skip_money', domain: 2, kind: AKind.single, text: 'In the past month, did you skip meals or eat less because money was short?', options: _o([('never', 'Never', 3), ('once', 'Once or twice', 2), ('sometimes', 'Sometimes', 1), ('often', 'Often', 0)])),
  AQuestion(id: 'a_load', domain: 3, kind: AKind.scale, text: 'How manageable is your academic workload right now?', options: _o([('1', 'Very hard', 0), ('2', 'Hard', 1), ('3', 'Okay', 2), ('4', 'Manageable', 3), ('5', 'Very manageable', 4)])),
  AQuestion(id: 'a_tradeoff', domain: 3, kind: AKind.single, text: 'How often do deadlines make you skip meals, sleep or exercise?', options: _o([('never', 'Never', 3), ('sometimes', 'Sometimes', 2), ('often', 'Often', 1), ('always', 'Almost always', 0)])),
  AQuestion(id: 'a_breaks', domain: 3, kind: AKind.single, text: 'Do you take short breaks while studying?', options: _o([('regularly', 'Regularly', 2), ('sometimes', 'Sometimes', 1), ('rarely', 'Rarely', 0)])),
  AQuestion(id: 'e_mood', domain: 4, kind: AKind.scale, text: 'Overall, how has your mood been over the past two weeks?', options: _o([('1', 'Very low', 0), ('2', 'Low', 1), ('3', 'Okay', 2), ('4', 'Good', 3), ('5', 'Great', 4)])),
  AQuestion(id: 'e_pss1', domain: 4, kind: AKind.single, text: 'In the last month, how often have you felt unable to control the important things in your life?', options: _never4),
  AQuestion(id: 'e_pss2', domain: 4, kind: AKind.single, text: 'In the last month, how often have you felt confident about handling your personal problems?', options: _never4Rev),
  AQuestion(id: 'e_pss3', domain: 4, kind: AKind.single, text: 'In the last month, how often have you felt that things were going your way?', options: _never4Rev),
  AQuestion(id: 'e_pss4', domain: 4, kind: AKind.single, text: 'In the last month, how often have difficulties piled up so high that you could not overcome them?', options: _never4),
  AQuestion(id: 's_hours', domain: 5, kind: AKind.single, text: 'On average, how many hours do you sleep a night?', options: _o([('<5', 'Less than 5 hours', 0), ('5-6', '5 to 6 hours', 1), ('7-8', '7 to 8 hours', 3), ('9+', '9 hours or more', 2)])),
  AQuestion(id: 's_quality', domain: 5, kind: AKind.single, text: 'How would you rate your sleep quality this month?', options: _o([('very_good', 'Very good', 3), ('fairly_good', 'Fairly good', 2), ('fairly_bad', 'Fairly bad', 1), ('very_bad', 'Very bad', 0)])),
  AQuestion(id: 's_regular', domain: 5, kind: AKind.single, text: 'Do you go to bed and wake up at about the same times most days?', options: _o([('mostly', 'Mostly, yes', 2), ('sometimes', 'Sometimes', 1), ('rarely', 'Rarely', 0)])),
  AQuestion(id: 'm_active_days', domain: 6, kind: AKind.single, text: 'In the last 7 days, on how many days were you active for at least 30 minutes?', help: 'Brisk walking, sport, gym, cycling or dancing all count.', options: _o([('0', '0 days', 0), ('1-2', '1 to 2 days', 1), ('3-4', '3 to 4 days', 2), ('5-7', '5 to 7 days', 3)])),
  AQuestion(id: 'm_getting_around', domain: 6, kind: AKind.single, text: 'How do you usually get around campus?', options: _o([('walk', 'Mostly walk or cycle', 2), ('mix', 'A mix of walking and transport', 1), ('vehicle', 'Mostly bus, three-wheeler or vehicle', 0)])),
  AQuestion(id: 'm_sitting', domain: 6, kind: AKind.single, text: 'On a typical weekday, how many hours do you spend sitting?', help: 'Lectures, studying, travel and screen time together.', options: _o([('<6', 'Less than 6 hours', 2), ('6-9', '6 to 9 hours', 1), ('10+', '10 hours or more', 0)])),
  AQuestion(id: 'f_living', domain: 7, kind: AKind.single, text: 'Where do you live during the semester?', options: _o([('hostel', 'University hostel', null), ('boarding', 'Boarding or rented room', null), ('home', 'At home with family', null), ('other', 'Somewhere else', null)])),
  AQuestion(id: 'f_money', domain: 7, kind: AKind.single, text: 'How often do money worries affect your food, transport or health choices?', options: _o([('never', 'Never', 3), ('sometimes', 'Sometimes', 2), ('often', 'Often', 1), ('always', 'Almost always', 0)])),
  AQuestion(id: 'f_water', domain: 7, kind: AKind.single, text: 'Can you easily get safe drinking water where you stay?', options: _o([('always', 'Always', 2), ('mostly', 'Mostly', 1), ('rarely', 'Rarely', 0)])),
  AQuestion(id: 'o_talk', domain: 8, kind: AKind.single, text: 'Do you have someone you can talk to when things get hard?', options: _o([('always', 'Yes, always', 2), ('sometimes', 'Sometimes', 1), ('no', 'Not really', 0)])),
  AQuestion(id: 'o_lonely', domain: 8, kind: AKind.single, text: 'How often do you feel lonely on campus?', options: _o([('never', 'Never', 3), ('rarely', 'Rarely', 2), ('sometimes', 'Sometimes', 1), ('often', 'Often', 0)])),
  AQuestion(id: 'o_groups', domain: 8, kind: AKind.single, text: 'Do you take part in clubs, sports, societies or cultural groups?', options: _o([('regularly', 'Regularly', 2), ('occasionally', 'Occasionally', 1), ('no', 'Not at all', 0)])),
  AQuestion(id: 'c_food', domain: 9, kind: AKind.scale, text: 'How easy is it to find healthy, affordable food on campus?', options: _o([('1', 'Very hard', 0), ('2', 'Hard', 1), ('3', 'Okay', 2), ('4', 'Easy', 3), ('5', 'Very easy', 4)])),
  AQuestion(id: 'c_spaces', domain: 9, kind: AKind.scale, text: 'How suitable are campus spaces for walking or exercise?', options: _o([('1', 'Very poor', 0), ('2', 'Poor', 1), ('3', 'Okay', 2), ('4', 'Good', 3), ('5', 'Very good', 4)])),
  AQuestion(id: 'c_health_centre', domain: 9, kind: AKind.single, text: 'Have you used the university health centre this academic year?', options: _o([('yes', 'Yes', null), ('no_need', 'No, I did not need to', null), ('no_barrier', 'No, I needed to but did not go', null)])),
  AQuestion(id: 'c_barriers', domain: 9, kind: AKind.multi, text: 'What makes it hard to use campus health services?', help: 'Select all that apply.', options: _o([
    ('unaware', 'Not sure what is offered', null),
    ('hours', 'Opening hours', null),
    ('waiting', 'Waiting time', null),
    ('privacy', 'Privacy worries', null),
    ('distance', 'Distance or transport', null),
    ('uncomfortable', 'Feeling uncomfortable asking', null),
    ('none', 'Nothing, it is easy', null),
  ])),
  AQuestion(id: 'v_priorities', domain: 10, kind: AKind.multi, text: 'Pick up to three things the university should prioritise for student health.', maxChoices: 3, options: _o([
    ('canteen', 'Healthier canteen food', null),
    ('affordable', 'Affordable meals', null),
    ('mental', 'Mental health and counselling', null),
    ('fitness', 'Sports and fitness facilities', null),
    ('water', 'Drinking water stations', null),
    ('schedule', 'Better exam and study scheduling', null),
    ('screening', 'Regular health screenings', null),
    ('hostels', 'Safer, cleaner hostels', null),
    ('education', 'Health workshops and education', null),
  ])),
  const AQuestion(id: 'v_idea', domain: 10, kind: AKind.text, text: 'One change that would make student life healthier (optional)', help: 'Please do not include names or anything that could identify you.', optional: true),
];

/// PSS-4 items (Perceived Stress Scale), summed 0 to 16, higher is more stress.
const _pss = ['e_pss1', 'e_pss2', 'e_pss3', 'e_pss4'];

/// Scores a completed questionnaire: a 0 to 100 well-being score for each
/// domain (higher is healthier), an overall average, BMI and waist-to-hip
/// ratio when measured, and the PSS-4 stress sum.
(Map<String, dynamic>, String) scoreAssessment(List<AQuestion> questions, Map<String, dynamic> answers) {
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

  double? n(String k) => answers[k] == null ? null : double.tryParse('${answers[k]}');
  final bmi = Calc.bmi(n('p_height'), n('p_weight'));
  final whr = Calc.whr(n('p_waist'), n('p_hip'));
  // PSS-4: option values are the raw frequency (0 never to 4 very often);
  // items 2 and 3 are positively worded, so they are reversed.
  final pss = _pss.every((k) => answers[k] != null)
      ? [for (final k in _pss) (k == 'e_pss2' || k == 'e_pss3') ? 4 - (int.tryParse('${answers[k]}') ?? 0) : (int.tryParse('${answers[k]}') ?? 0)].fold<int>(0, (a, b) => a + b)
      : null;

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
    if (whr != null) 'whr': double.parse(whr.toStringAsFixed(2)),
    'stress': ?pss,
  }, label);
}
