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
  Condition('family_heart', 'Heart health in family', Symbols.cardiology, true),
  Condition('family_diabetes', 'Diabetes in family', Symbols.water_drop, false),
  Condition('asthma_allergies', 'Asthma or allergies', Symbols.eco, false),
  Condition('high_bp', 'High blood pressure', Symbols.speed, true),
  Condition('migraine', 'Migraines & headaches', Symbols.cloud, true),
  Condition('anxiety_sleep', 'Anxiety or sleep strain', Symbols.bedtime, false),
  Condition('gastritis', 'Gastritis or acid reflux', Symbols.gastroenterology, true),
  Condition('family_hypertension', 'High blood pressure in family', Symbols.monitor_heart, false),
  Condition('pcos', 'Diagnosed PCOS', Symbols.female, true),
  Condition('anaemia', 'Anaemia / low iron', Symbols.bloodtype, true),
  Condition('constipation', 'Frequent constipation', Symbols.nutrition, false),
];

Condition? conditionByKey(String k) {
  for (final c in conditions) {
    if (c.key == k) return c;
  }
  return null;
}

const faculties = <String>[
  'Faculty of Applied Sciences',
  'Faculty of Agriculture',
  'Faculty of Management Studies',
  'Faculty of Medicine & Allied Sciences',
  'Faculty of Social Sciences & Humanities',
  'Faculty of Technology',
  'Other Academic Department',
];

const academicYears = <String>['Year 1', 'Year 2', 'Year 3', 'Year 4', 'Postgraduate'];

/// The eight food groups used by the dietary diversity tracker.
class FoodGroup {
  const FoodGroup(this.key, this.label, this.icon, this.color, this.suggestion, this.where);
  final String key;
  final String label;
  final IconData icon;
  final int color;
  final String suggestion;
  final String where;
}

const foodGroups = <FoodGroup>[
  FoodGroup('grains', 'Whole Grains', Symbols.grain, 0xFFD4A017, 'Red rice / Oats', 'Canteen rice counter'),
  FoodGroup('fruits', 'Fruits & Berries', Symbols.nutrition, 0xFFE0567F, 'Papaya / Guava / Banana', 'Campus fruit stall'),
  FoodGroup('greens', 'Leafy Greens', Symbols.nest_eco_leaf, 0xFF3F9A5B, 'Gotukola / Mukunuwenna', 'Canteen mallum'),
  FoodGroup('fats_seeds', 'Healthy Fats & Seeds', Symbols.palette, 0xFF8B6B2E, 'Avocado / Sesame', 'Cafe & salad bar'),
  FoodGroup('probiotics', 'Probiotics', Symbols.bubble_chart, 0xFF7459F7, 'Curd / Yoghurt', 'Campus Cafe'),
  FoodGroup('legumes_nuts', 'Nuts & Beans', Symbols.spa, 0xFF984062, 'Dhal / Chickpeas / Nuts', 'Library Grab & Go'),
  FoodGroup('herbs_spices', 'Herbs & Spices', Symbols.eco, 0xFF006A45, 'Turmeric / Curry leaves', 'Canteen curries'),
  FoodGroup('protein', 'Eggs, Fish & Meat', Symbols.egg_alt, 0xFF4BA3E3, 'Egg / Fish / Chicken', 'Canteen main line'),
];

FoodGroup? groupByKey(String k) {
  for (final g in foodGroups) {
    if (g.key == k) return g;
  }
  return null;
}

/// Maps icon names stored in the database to Material Symbols.
IconData iconByName(String? name) {
  switch (name) {
    case 'water_drop':
      return Symbols.water_drop;
    case 'verified':
      return Symbols.verified;
    case 'auto_stories':
      return Symbols.auto_stories;
    case 'spa':
      return Symbols.spa;
    case 'nutrition':
      return Symbols.nutrition;
    case 'bedtime':
      return Symbols.bedtime;
    case 'directions_walk':
      return Symbols.directions_walk;
    case 'favorite_border':
    case 'favorite':
      return Symbols.favorite;
    case 'autorenew':
      return Symbols.autorenew;
    case 'nature_people':
      return Symbols.nature_people;
    case 'restaurant':
      return Symbols.restaurant;
    case 'emoji_food_beverage':
      return Symbols.emoji_food_beverage;
    case 'rice_bowl':
      return Symbols.rice_bowl;
    case 'icecream':
      return Symbols.icecream;
    case 'lunch_dining':
      return Symbols.lunch_dining;
    case 'bakery_dining':
      return Symbols.bakery_dining;
    case 'skillet':
      return Symbols.skillet;
    case 'soup_kitchen':
      return Symbols.soup_kitchen;
    case 'call':
      return Symbols.call;
    case 'local_hospital':
      return Symbols.local_hospital;
    case 'volunteer_activism':
      return Symbols.volunteer_activism;
    case 'chat':
      return Symbols.chat;
    case 'event_upcoming':
      return Symbols.event_upcoming;
    case 'health_and_safety':
      return Symbols.health_and_safety;
    case 'insights':
      return Symbols.insights;
    case 'notifications':
      return Symbols.notifications;
    case 'monitor_heart':
      return Symbols.monitor_heart;
    case 'air':
      return Symbols.air;
    case 'timer':
      return Symbols.timer;
    case 'chair':
      return Symbols.chair;
    case 'info':
      return Symbols.info;
    case 'warning':
      return Symbols.warning;
    case 'schedule':
      return Symbols.schedule;
    case 'eco':
      return Symbols.eco;
    case 'local_drink':
      return Symbols.local_drink;
    case 'bloodtype':
      return Symbols.bloodtype;
    case 'cardiology':
      return Symbols.cardiology;
    case 'wb_sunny':
      return Symbols.wb_sunny;
    case 'bolt':
      return Symbols.bolt;
    case 'vital_signs':
      return Symbols.vital_signs;
    case 'science':
      return Symbols.science;
    case 'psychology':
      return Symbols.psychology;
    case 'local_cafe':
      return Symbols.local_cafe;
    case 'park':
      return Symbols.park;
    case 'auto_awesome':
      return Symbols.auto_awesome;
    case 'medication':
      return Symbols.medication;
    case 'egg':
      return Symbols.egg;
    case 'thermostat':
      return Symbols.thermostat;
    case 'labs':
      return Symbols.labs;
    case 'shield':
      return Symbols.shield;
    case 'grain':
      return Symbols.grain;
    case 'sunny':
      return Symbols.sunny;
    case 'lab_profile':
      return Symbols.lab_profile;
    case 'hematology':
      return Symbols.hematology;
    case 'neurology':
      return Symbols.neurology;
    case 'ecg_heart':
      return Symbols.ecg_heart;
    case 'glucose':
      return Symbols.glucose;
    default:
      return Symbols.spa;
  }
}
