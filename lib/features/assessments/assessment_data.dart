import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/models.dart';

class AOption {
  const AOption(this.value, this.title, [this.subtitle, this.score = 0]);
  final String value;
  final String title;
  final String? subtitle;
  final num score;
}

enum AType { choice, number }

class AQuestion {
  const AQuestion({
    required this.id,
    required this.section,
    required this.category,
    required this.categoryIcon,
    required this.text,
    this.help = 'Reflect on your typical week during this semester so far. There are no right or wrong answers.',
    this.type = AType.choice,
    this.options = const [],
    this.unit,
    this.min,
    this.max,
    this.optional = false,
  });
  final String id;
  final int section;
  final String category;
  final IconData categoryIcon;
  final String text;
  final String help;
  final AType type;
  final List<AOption> options;
  final String? unit;
  final double? min;
  final double? max;
  final bool optional;
}

class ASection {
  const ASection(this.title, this.image, this.icon);
  final String title;
  final String image;
  final IconData icon;
}

const assessmentSections = <ASection>[
  ASection('Body Measurements', 'heart_desk', Symbols.straighten_rounded),
  ASection('Nutrition & Eating', 'nourishment_bowl', Symbols.restaurant_rounded),
  ASection('Lifestyle & Daily Rhythm', 'study_desk_tea', Symbols.spa_rounded),
  ASection('Physical Activity', 'sneakers', Symbols.directions_walk_rounded),
  ASection('Sleep & Rest', 'moon_cloud', Symbols.bedtime_rounded),
  ASection('Stress & Wellbeing', 'meditating_student', Symbols.self_improvement_rounded),
];

const _freq = [
  AOption('0', 'Never', 'Not at all in the last month', 0),
  AOption('1', 'Almost never', null, 1),
  AOption('2', 'Sometimes', null, 2),
  AOption('3', 'Fairly often', null, 3),
  AOption('4', 'Very often', null, 4),
];

const _freqRev = [
  AOption('0', 'Never', 'Not at all in the last month', 4),
  AOption('1', 'Almost never', null, 3),
  AOption('2', 'Sometimes', null, 2),
  AOption('3', 'Fairly often', null, 1),
  AOption('4', 'Very often', null, 0),
];

const _days = [
  AOption('0', '0 days', 'Not this week', 0),
  AOption('1-2', '1–2 days', null, 1.5),
  AOption('3-4', '3–4 days', null, 3.5),
  AOption('5-7', '5–7 days', null, 6),
];

/// Periodic university health assessment (≈5 minutes, six sections).
/// Activity items follow the IPAQ-SF structure; stress items use the PSS-4.
const assessmentQuestions = <AQuestion>[
  // 1: Body measurements
  AQuestion(id: 'height_cm', section: 0, category: 'Anthropometrics', categoryIcon: Symbols.height_rounded, text: 'What is your height?', help: 'Use your most recent measurement. You can skip if unsure.', type: AType.number, unit: 'cm', min: 100, max: 230, optional: true),
  AQuestion(id: 'weight_kg', section: 0, category: 'Anthropometrics', categoryIcon: Symbols.monitor_weight_rounded, text: 'What is your weight?', help: 'A recent reading is perfect. No judgment, ever.', type: AType.number, unit: 'kg', min: 25, max: 250, optional: true),
  AQuestion(id: 'waist_cm', section: 0, category: 'Anthropometrics', categoryIcon: Symbols.straighten_rounded, text: 'What is your waist circumference?', help: 'Measure at the narrowest point above the navel after a relaxed breath out.', type: AType.number, unit: 'cm', min: 40, max: 200, optional: true),
  AQuestion(id: 'hip_cm', section: 0, category: 'Anthropometrics', categoryIcon: Symbols.accessibility_new_rounded, text: 'What is your hip circumference?', help: 'Measure around the widest part of your hips.', type: AType.number, unit: 'cm', min: 50, max: 200, optional: true),
  AQuestion(id: 'sbp', section: 0, category: 'Clinical', categoryIcon: Symbols.monitor_heart_rounded, text: 'Do you know your recent blood pressure (upper/systolic number)?', help: 'Only if measured in the last 6 months. Skip if you don\'t know.', type: AType.number, unit: 'mmHg', min: 70, max: 220, optional: true),

  // 2: Nutrition
  AQuestion(id: 'fruit_veg', section: 1, category: 'Fruit & Vegetables', categoryIcon: Symbols.nutrition_rounded, text: 'On a typical day, how many servings of fruit and vegetables do you eat?', options: [
    AOption('0-1', '0–1 servings', 'Rarely have fruit or veg', 0),
    AOption('2-3', '2–3 servings', 'Some with most meals', 1),
    AOption('4', '4 servings', 'Almost there', 2),
    AOption('5+', '5 or more servings', 'Colourful plates most days', 3),
  ]),
  AQuestion(id: 'breakfast', section: 1, category: 'Meal Rhythm', categoryIcon: Symbols.bakery_dining_rounded, text: 'How many days a week do you eat breakfast?', options: [
    AOption('0-1', '0–1 days', 'Usually skip it', 0),
    AOption('2-4', '2–4 days', 'Depends on lectures', 1),
    AOption('5-7', '5–7 days', 'Most mornings', 2),
  ]),
  AQuestion(id: 'fried', section: 1, category: 'Food Choices', categoryIcon: Symbols.fastfood_rounded, text: 'How often do you eat fried, fast or ultra-processed foods (short eats, instant noodles, burgers)?', options: [
    AOption('rare', 'Rarely', 'Less than once a week', 3),
    AOption('1-2', '1–2 times a week', null, 2),
    AOption('3-5', '3–5 times a week', null, 1),
    AOption('daily', 'Daily', 'Almost every day', 0),
  ]),
  AQuestion(id: 'sugary', section: 1, category: 'Drinks', categoryIcon: Symbols.local_cafe_rounded, text: 'How many sugary drinks (soft drinks, sweetened tea/coffee, juices) do you have per day?', options: [
    AOption('0', 'None', null, 2),
    AOption('1', '1 per day', null, 1),
    AOption('2+', '2 or more per day', null, 0),
  ]),

  // 3: Lifestyle
  AQuestion(id: 'balance', section: 2, category: 'Daily Balance & Energy', categoryIcon: Symbols.balance_rounded, text: 'How easily are you able to balance academic coursework with daily downtime and meals?', options: [
    AOption('smooth', 'Smoothly balanced', 'I regularly take breaks and eat on schedule.', 3),
    AOption('manageable', 'Manageable, with occasional rushes', 'Busier around assignment deadlines, but generally okay.', 2),
    AOption('compromised', 'Often compromised', 'I frequently skip meals or study through resting hours.', 1),
    AOption('overwhelmed', 'Constantly overwhelmed', 'Struggling to find time for basic self-care.', 0),
  ]),
  AQuestion(id: 'tobacco', section: 2, category: 'Tobacco & Vaping', categoryIcon: Symbols.smoke_free_rounded, text: 'Do you currently smoke or vape?', help: 'Confidential. This helps estimate heart-health risk at a population level.', options: [
    AOption('never', 'Never', null, 2),
    AOption('former', 'I used to, but quit', null, 1),
    AOption('sometimes', 'Occasionally', null, 0),
    AOption('daily', 'Daily', null, 0),
  ]),
  AQuestion(id: 'alcohol', section: 2, category: 'Alcohol', categoryIcon: Symbols.local_bar_rounded, text: 'How often do you drink alcohol?', options: [
    AOption('never', 'Never', null, 2),
    AOption('monthly', 'Monthly or less', null, 2),
    AOption('weekly', '2–4 times a month', null, 1),
    AOption('frequent', '2 or more times a week', null, 0),
  ]),
  AQuestion(id: 'screen', section: 2, category: 'Screen Time', categoryIcon: Symbols.smartphone_rounded, text: 'Outside of study, how many hours a day do you spend on screens?', options: [
    AOption('<2', 'Less than 2 hours', null, 2),
    AOption('2-4', '2–4 hours', null, 1),
    AOption('4+', 'More than 4 hours', null, 0),
  ]),

  // 4: Physical activity (IPAQ-SF structure)
  AQuestion(id: 'vigorous_days', section: 3, category: 'Vigorous Activity', categoryIcon: Symbols.sprint_rounded, text: 'During the last 7 days, on how many days did you do vigorous activity (running, fast cycling, sports) for at least 10 minutes?', options: _days),
  AQuestion(id: 'moderate_days', section: 3, category: 'Moderate Activity', categoryIcon: Symbols.pedal_bike_rounded, text: 'On how many days did you do moderate activity (carrying loads, easy cycling, dancing) for at least 10 minutes?', options: _days),
  AQuestion(id: 'walk_days', section: 3, category: 'Walking', categoryIcon: Symbols.directions_walk_rounded, text: 'On how many days did you walk for at least 10 minutes at a time?', options: _days),
  AQuestion(id: 'sitting', section: 3, category: 'Sitting Time', categoryIcon: Symbols.chair_rounded, text: 'On a typical weekday, how much time do you spend sitting?', options: [
    AOption('<6', 'Less than 6 hours', null, 2),
    AOption('6-9', '6–9 hours', null, 1),
    AOption('10+', '10 hours or more', null, 0),
  ]),

  // 5: Sleep
  AQuestion(id: 'sleep_hours', section: 4, category: 'Sleep Duration', categoryIcon: Symbols.bedtime_rounded, text: 'On average, how many hours do you sleep per night?', options: [
    AOption('<5', 'Less than 5 hours', null, 4.5),
    AOption('5-6', '5–6 hours', null, 5.5),
    AOption('7-8', '7–8 hours', null, 7.5),
    AOption('9+', '9 hours or more', null, 9),
  ]),
  AQuestion(id: 'sleep_quality', section: 4, category: 'Sleep Quality', categoryIcon: Symbols.nights_stay_rounded, text: 'How would you rate your overall sleep quality this month?', options: [
    AOption('very_good', 'Very good', null, 3),
    AOption('fairly_good', 'Fairly good', null, 2),
    AOption('fairly_bad', 'Fairly bad', null, 1),
    AOption('very_bad', 'Very bad', null, 0),
  ]),

  // 6: Stress (PSS-4)
  AQuestion(id: 'pss1', section: 5, category: 'Perceived Stress', categoryIcon: Symbols.psychology_rounded, text: 'In the last month, how often have you felt that you were unable to control the important things in your life?', help: 'Take a slow breath. There are no right or wrong answers.', options: _freq),
  AQuestion(id: 'pss2', section: 5, category: 'Perceived Stress', categoryIcon: Symbols.psychology_rounded, text: 'In the last month, how often have you felt confident about your ability to handle your personal problems?', help: 'Take a slow breath. There are no right or wrong answers.', options: _freqRev),
  AQuestion(id: 'pss3', section: 5, category: 'Perceived Stress', categoryIcon: Symbols.psychology_rounded, text: 'In the last month, how often have you felt that things were going your way?', help: 'Take a slow breath. There are no right or wrong answers.', options: _freqRev),
  AQuestion(id: 'pss4', section: 5, category: 'Perceived Stress', categoryIcon: Symbols.psychology_rounded, text: 'In the last month, how often have you felt difficulties were piling up so high that you could not overcome them?', help: 'Take a slow breath. There are no right or wrong answers.', options: _freq),
];

num _score(String id, Map<String, dynamic> a) {
  final q = assessmentQuestions.firstWhere((e) => e.id == id);
  final v = a[id];
  if (v == null) return 0;
  return q.options.firstWhere((o) => o.value == v, orElse: () => const AOption('', '')).score;
}

/// Computes aggregate scores stored with a completed assessment.
(Map<String, dynamic>, String) scoreAssessment(Map<String, dynamic> a) {
  double? n(String k) => a[k] == null ? null : double.tryParse(a[k].toString());
  final bmi = Calc.bmi(n('height_cm'), n('weight_kg'));
  final whr = Calc.whr(n('waist_cm'), n('hip_cm'));
  final diet = _score('fruit_veg', a) + _score('breakfast', a) + _score('fried', a) + _score('sugary', a); // 0..10
  final lifestyle = _score('balance', a) + _score('tobacco', a) + _score('alcohol', a) + _score('screen', a); // 0..9
  final activeDays = _score('vigorous_days', a) + _score('moderate_days', a) + _score('walk_days', a);
  final stress = _score('pss1', a) + _score('pss2', a) + _score('pss3', a) + _score('pss4', a); // 0..16
  final sleepH = _score('sleep_hours', a);
  final sleepQ = _score('sleep_quality', a);

  int points = 0;
  if (diet >= 7) points += 2; else if (diet >= 4) points += 1;
  if (lifestyle >= 7) points += 2; else if (lifestyle >= 4) points += 1;
  if (activeDays >= 7) points += 2; else if (activeDays >= 3) points += 1;
  if (stress <= 6) points += 2; else if (stress <= 10) points += 1;
  if (sleepH >= 7 && sleepH < 9 && sleepQ >= 2) points += 2; else if (sleepH >= 5.5) points += 1;

  final label = points >= 9 ? 'Healthy habits' : points >= 6 ? 'Mostly on track' : points >= 3 ? 'Room to improve' : 'Needs attention';
  return ({
    if (bmi != null) 'bmi': double.parse(bmi.toStringAsFixed(1)),
    if (whr != null) 'whr': double.parse(whr.toStringAsFixed(2)),
    if (n('sbp') != null) 'sbp': n('sbp'),
    'diet_score': diet,
    'lifestyle_score': lifestyle,
    'activity_days': activeDays,
    'stress': stress,
    'sleep_hours': sleepH,
    'sleep_quality': sleepQ,
    'points': points,
  }, label);
}
