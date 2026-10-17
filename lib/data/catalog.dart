import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

class Condition {
  const Condition(this.key, this.label, this.icon, this.secondaryTint);
  final String key;
  final String label;
  final IconData icon;
  final bool secondaryTint;
}

/// Health background items used in registration & profile editing.
const conditions = <Condition>[
  Condition('family_heart', 'Heart health in family', Symbols.cardiology_rounded, true),
  Condition('family_diabetes', 'Diabetes in family', Symbols.water_drop_rounded, false),
  Condition('asthma_allergies', 'Asthma or allergies', Symbols.eco_rounded, false),
  Condition('high_bp', 'High blood pressure', Symbols.speed_rounded, true),
  Condition('migraine', 'Migraines & headaches', Symbols.cloud_rounded, true),
  Condition('anxiety_sleep', 'Anxiety or sleep strain', Symbols.bedtime_rounded, false),
  Condition('gastritis', 'Gastritis or acid reflux', Symbols.gastroenterology_rounded, true),
  Condition('family_hypertension', 'High blood pressure in family', Symbols.monitor_heart_rounded, false),
  Condition('pcos', 'Diagnosed PCOS', Symbols.female_rounded, true),
  Condition('anaemia', 'Anaemia / low iron', Symbols.bloodtype_rounded, true),
  Condition('constipation', 'Frequent constipation', Symbols.nutrition_rounded, false),
  Condition('family_cholesterol', 'Dyslipidemia / high cholesterol in family', Symbols.bloodtype_rounded, true),
  Condition('family_obesity', 'Obesity in family', Symbols.monitor_weight_rounded, false),
  Condition('skin_disease', 'Skin diseases', Symbols.dermatology_rounded, false),
  Condition('kidney_disease', 'Kidney disease', Symbols.nephrology_rounded, true),
  Condition('liver_disease', 'Liver disease', Symbols.medical_information_rounded, false),
  Condition('hemorrhoids', 'Hemorrhoids', Symbols.healing_rounded, false),
  Condition('std', 'Sexually transmitted diseases', Symbols.sick_rounded, true),
  Condition('allergies_intolerances', 'Allergies / intolerances', Symbols.allergy_rounded, false),
];

Condition? conditionByKey(String k) {
  for (final c in conditions) {
    if (c.key == k) return c;
  }
  return null;
}

/// Conditions the student has themselves, asked separately from family history.
const personalConditionKeys = <String>[
  'asthma_allergies',
  'allergies_intolerances',
  'high_bp',
  'migraine',
  'anxiety_sleep',
  'gastritis',
  'constipation',
  'skin_disease',
  'kidney_disease',
  'liver_disease',
  'hemorrhoids',
  'anaemia',
  'std',
  'pcos',
];

/// Conditions in parents, siblings or grandparents.
const familyConditionKeys = <String>['family_heart', 'family_hypertension', 'family_diabetes', 'family_cholesterol', 'family_obesity'];

bool isFamilyCondition(String key) => key.startsWith('family_');

/// Short label for a family-history key, shown under a "Family history" heading.
String familyConditionLabel(String key) => switch (key) {
      'family_heart' => 'Heart disease or stroke',
      'family_hypertension' => 'High blood pressure',
      'family_diabetes' => 'Diabetes',
      'family_cholesterol' => 'High cholesterol',
      'family_obesity' => 'Obesity',
      _ => conditionByKey(key)?.label ?? key,
    };

/// Body shapes offered at registration, as a simple picture of where the body
/// tends to store fat.
class BodyShape {
  const BodyShape(this.key, this.label, this.note);
  final String key;
  final String label;
  final String note;
}

const bodyShapes = <BodyShape>[
  BodyShape('apple', 'Apple', 'Fuller around the middle'),
  BodyShape('pear', 'Pear', 'Fuller hips and thighs'),
  BodyShape('hourglass', 'Hourglass', 'Balanced, with a defined waist'),
  BodyShape('rectangle', 'Rectangle', 'Waist, hips and shoulders similar'),
  BodyShape('inverted_triangle', 'Inverted triangle', 'Broader shoulders and chest'),
];

BodyShape? bodyShapeByKey(String? k) {
  for (final s in bodyShapes) {
    if (s.key == k) return s;
  }
  return null;
}

const faculties = <String>[
  'Faculty of Agriculture',
  'Faculty of Allied Health Sciences',
  'Faculty of Arts',
  'Faculty of Dental Sciences',
  'Faculty of Engineering',
  'Faculty of Management',
  'Faculty of Medicine',
  'Faculty of Science',
  'Faculty of Veterinary Medicine and Animal Science',
];

/// University of Peradeniya faculty email domains. Only these can create an
/// account, and the domain sets the student's faculty.
const facultyEmailDomains = <String, String>{
  'agri.pdn.ac.lk': 'Faculty of Agriculture',
  'arts.pdn.ac.lk': 'Faculty of Arts',
  'eng.pdn.ac.lk': 'Faculty of Engineering',
  'mgt.pdn.ac.lk': 'Faculty of Management',
  'sci.pdn.ac.lk': 'Faculty of Science',
  'ahs.pdn.ac.lk': 'Faculty of Allied Health Sciences',
  'med.pdn.ac.lk': 'Faculty of Medicine',
  'dental.pdn.ac.lk': 'Faculty of Dental Sciences',
  'vet.pdn.ac.lk': 'Faculty of Veterinary Medicine and Animal Science',
};

/// The faculty an email address belongs to, or null for other addresses.
String? facultyForEmail(String? email) {
  if (email == null || !email.contains('@')) return null;
  return facultyEmailDomains[email.split('@').last.trim().toLowerCase()];
}

/// Where a student lives during the semester.
const accommodationOptions = <String, String>{
  'hostel': 'University hostel',
  'boarding': 'Boarding or rented room',
  'home': 'At home with family',
  'other': 'Somewhere else',
};

const academicYears = <String>['21/22 Batch', '22/23 Batch', '23/24 Batch', '24/25 Batch', '25/26 Batch'];

/// A food group of VitalU's dietary diversity score: the ten food groups used
/// to measure dietary diversity in Sri Lankan men and women (Abeywickrama et
/// al., 2020), adapted from the FAO and FANTA individual dietary diversity
/// groups. One point for each group eaten in a day, whatever the amount; 5 or
/// more of 10 counts as minimum dietary diversity. Oils, sugar, sweets,
/// condiments and drinks are left out because almost everyone in Sri Lanka
/// has them every day, so they would raise the score without improving the
/// diet (Jayawardena et al., 2013).
class FoodGroup {
  const FoodGroup(this.key, this.label, this.icon, this.color, this.meaning, this.examples, {this.imageName});
  final String key;
  final String label;
  final IconData icon;
  final int color;

  /// What the group is, in one plain sentence.
  final String meaning;

  /// Familiar Sri Lankan foods in the group.
  final List<String> examples;

  final String? imageName;

  /// Realistic food photo in assets/food_groups.
  String get image => 'assets/food_groups/${imageName ?? key}.webp';
}

/// Minimum dietary diversity: at least this many of the ten groups in a day.
const minDietaryDiversity = 5;

const foodGroups = <FoodGroup>[
  FoodGroup('cereals', 'Cereals', Symbols.rice_bowl_rounded, 0xFFD4A017, 'Rice and foods made from grains: your main source of energy.',
      ['Red or white rice', 'String hoppers', 'Roti and bread', 'Pittu', 'Kurakkan', 'Noodles', 'Oats']),
  FoodGroup('starchy', 'Tubers and starchy vegetables', Symbols.nutrition_rounded, 0xFFB7791F, 'Roots, tubers and starchy vegetables that give energy and fibre.',
      ['Manioc (cassava)', 'Sweet potato', 'Potatoes', 'Polos (young jackfruit)', 'Breadfruit', 'Yams (kiriala, innala)']),
  FoodGroup('other_veg', 'Root and fruit vegetables', Symbols.grass_rounded, 0xFF3F9A5B, 'Everyday vegetables for fibre, vitamins and minerals.',
      ['Carrot', 'Pumpkin', 'Beans', 'Brinjal', 'Cabbage', 'Okra (bandakka)', 'Beetroot', 'Tomato', 'Cucumber', 'Leeks']),
  FoodGroup('dark_leafy', 'Green leafy vegetables', Symbols.eco_rounded, 0xFF2E8F42, 'Leafy greens rich in iron, folate and vitamin A.',
      ['Gotukola', 'Mukunuwenna', 'Kankun', 'Spinach', 'Drumstick leaves (murunga)', 'Thampala', 'Green salad']),
  FoodGroup('fruits', 'Fruits', Symbols.spa_rounded, 0xFFE0567F, 'Fresh fruit for vitamin C, fibre and natural sweetness.',
      ['Banana', 'Papaya', 'Mango', 'Guava', 'Pineapple', 'Orange', 'Wood apple', 'Rambutan'], imageName: 'other_fruit'),
  FoodGroup('pulses', 'Pulses, nuts and seeds', Symbols.grain_rounded, 0xFF984062, 'Lentils, beans, nuts and seeds: plant protein and fibre.',
      ['Dhal (parippu)', 'Chickpeas (kadala)', 'Green gram (mung)', 'Cowpea', 'Soya meat', 'Peanuts', 'Cashew nuts', 'Sesame (thala)']),
  FoodGroup('meat', 'Meat and poultry', Symbols.kebab_dining_rounded, 0xFFD1344E, 'Animal protein with iron, zinc and vitamin B12.',
      ['Chicken', 'Beef', 'Pork', 'Mutton', 'Sausages']),
  FoodGroup('eggs', 'Eggs', Symbols.egg_rounded, 0xFFE8A33D, 'A cheap, complete protein that is quick to cook.',
      ['Boiled egg', 'Egg curry', 'Omelette', 'Egg hoppers', 'Egg roti']),
  FoodGroup('fish', 'Fish and seafood', Symbols.set_meal_rounded, 0xFF2F7FB5, 'Protein, omega-3 fats, iodine and vitamin D.',
      ['Fish curry', 'Sprats (halmasso)', 'Dried fish', 'Tinned fish', 'Prawns', 'Cuttlefish']),
  FoodGroup('dairy', 'Milk and milk products', Symbols.water_full_rounded, 0xFF4BA3E3, 'Milk and foods made from it: calcium and protein.',
      ['Milk', 'Curd (meekiri)', 'Yoghurt', 'Cheese', 'Milk tea or Milo made with milk']),
];

FoodGroup? groupByKey(String k, {String? food}) {
  final key = legacyGroupKey(k, food: food);
  for (final g in foodGroups) {
    if (g.key == key) return g;
  }
  return null;
}

/// The dietary diversity group for keys from earlier versions of the app
/// (the MDD-W groups and the first 8-group tracker) and from meal photo
/// analysis, so older logs still count. Where an old group was split, the
/// food's name decides (for example "meat and fish" becomes fish for a fish
/// curry). Herbs and spices are not a dietary diversity group.
String? legacyGroupKey(String k, {String? food}) {
  final name = (food ?? '').toLowerCase();
  bool has(String pattern) => RegExp(pattern).hasMatch(name);
  return switch (k) {
    'grains' => has('potato|manioc|cassava|yam|kiriala|innala|polos|jackfruit|breadfruit') ? 'starchy' : 'cereals',
    'meat_fish' || 'protein' => has('fish|sprat|halmasso|prawn|shrimp|cuttle|squid|crab|tuna|seer|seafood|karawala|ambul') ? 'fish' : 'meat',
    'vita_veg_fruit' => has('papaya|mango|fruit|melon|passion') ? 'fruits' : 'other_veg',
    'other_fruit' => 'fruits',
    'greens' => 'dark_leafy',
    'nuts_seeds' || 'fats_seeds' || 'legumes_nuts' => 'pulses',
    'probiotics' => 'dairy',
    'herbs_spices' => null,
    _ => foodGroups.any((g) => g.key == k) ? k : null,
  };
}

/// Maps icon names stored in the database to Material Symbols.
IconData iconByName(String? name) {
  switch (name) {
    case 'stethoscope':
      return Symbols.stethoscope_rounded;
    case 'bedtime_off':
      return Symbols.bedtime_off_rounded;
    case 'nights_stay':
      return Symbols.nights_stay_rounded;
    case 'hotel':
      return Symbols.hotel_rounded;
    case 'person_check':
      return Symbols.person_check_rounded;
    case 'water_drop':
      return Symbols.water_drop_rounded;
    case 'menstrual_health':
      return Symbols.menstrual_health_rounded;
    case 'self_improvement':
      return Symbols.self_improvement_rounded;
    case 'verified':
      return Symbols.verified_rounded;
    case 'auto_stories':
      return Symbols.auto_stories_rounded;
    case 'spa':
      return Symbols.spa_rounded;
    case 'nutrition':
      return Symbols.nutrition_rounded;
    case 'bedtime':
      return Symbols.bedtime_rounded;
    case 'directions_walk':
      return Symbols.directions_walk_rounded;
    case 'favorite_border':
    case 'favorite':
      return Symbols.favorite_rounded;
    case 'autorenew':
      return Symbols.autorenew_rounded;
    case 'nature_people':
      return Symbols.nature_people_rounded;
    case 'restaurant':
      return Symbols.restaurant_rounded;
    case 'emoji_food_beverage':
      return Symbols.emoji_food_beverage_rounded;
    case 'rice_bowl':
      return Symbols.rice_bowl_rounded;
    case 'icecream':
      return Symbols.icecream_rounded;
    case 'lunch_dining':
      return Symbols.lunch_dining_rounded;
    case 'bakery_dining':
      return Symbols.bakery_dining_rounded;
    case 'skillet':
      return Symbols.skillet_rounded;
    case 'soup_kitchen':
      return Symbols.soup_kitchen_rounded;
    case 'call':
      return Symbols.call_rounded;
    case 'local_hospital':
      return Symbols.local_hospital_rounded;
    case 'volunteer_activism':
      return Symbols.volunteer_activism_rounded;
    case 'chat':
      return Symbols.chat_rounded;
    case 'event_upcoming':
      return Symbols.event_upcoming_rounded;
    case 'health_and_safety':
      return Symbols.health_and_safety_rounded;
    case 'insights':
      return Symbols.insights_rounded;
    case 'notifications':
      return Symbols.notifications_rounded;
    case 'monitor_heart':
      return Symbols.monitor_heart_rounded;
    case 'air':
      return Symbols.air_rounded;
    case 'timer':
      return Symbols.timer_rounded;
    case 'chair':
      return Symbols.chair_rounded;
    case 'info':
      return Symbols.info_rounded;
    case 'warning':
      return Symbols.warning_rounded;
    case 'schedule':
      return Symbols.schedule_rounded;
    case 'eco':
      return Symbols.eco_rounded;
    case 'local_drink':
      return Symbols.local_drink_rounded;
    case 'bloodtype':
      return Symbols.bloodtype_rounded;
    case 'cardiology':
      return Symbols.cardiology_rounded;
    case 'wb_sunny':
      return Symbols.wb_sunny_rounded;
    case 'bolt':
      return Symbols.bolt_rounded;
    case 'vital_signs':
      return Symbols.vital_signs_rounded;
    case 'science':
      return Symbols.science_rounded;
    case 'psychology':
      return Symbols.psychology_rounded;
    case 'local_cafe':
      return Symbols.local_cafe_rounded;
    case 'park':
      return Symbols.park_rounded;
    case 'auto_awesome':
      return Symbols.auto_awesome_rounded;
    case 'medication':
      return Symbols.medication_rounded;
    case 'egg':
      return Symbols.egg_rounded;
    case 'thermostat':
      return Symbols.thermostat_rounded;
    case 'labs':
      return Symbols.labs_rounded;
    case 'shield':
      return Symbols.shield_rounded;
    case 'grain':
      return Symbols.grain_rounded;
    case 'sunny':
      return Symbols.sunny_rounded;
    case 'lab_profile':
      return Symbols.lab_profile_rounded;
    case 'hematology':
      return Symbols.hematology_rounded;
    case 'neurology':
      return Symbols.neurology_rounded;
    case 'ecg_heart':
      return Symbols.ecg_heart_rounded;
    case 'glucose':
      return Symbols.glucose_rounded;
    case 'school':
      return Symbols.school_rounded;
    case 'savings':
      return Symbols.savings_rounded;
    case 'diversity_3':
      return Symbols.diversity_3_rounded;
    case 'campaign':
      return Symbols.campaign_rounded;
    case 'assignment':
      return Symbols.assignment_rounded;
    default:
      return Symbols.spa_rounded;
  }
}
