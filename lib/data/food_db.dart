/// The single food database used across the Diet section: meal logging, the
/// calorie counter, the budget meal planner and the healthy plate guide.
/// Built around foods commonly eaten by Sri Lankan university students
/// (canteen, hostel and short-eat staples).
///
/// Every food carries practical portion units with estimated kcal, its
/// dietary diversity food groups and its PDQS groups (diet quality).
/// All values are estimates: energy varies with recipe, oil and portion.
library;

/// A practical way to measure a portion (a tablespoon, a cup, a piece…),
/// with the estimated kcal for exactly one of that unit and a sensible range
/// for the quantity stepper.
class PortionUnit {
  const PortionUnit(this.label, this.kcalPerUnit, {this.min = 1, this.max = 20, this.step = 1});
  final String label;
  final double kcalPerUnit;
  final double min;
  final double max;
  final double step;
}

class Food {
  const Food(this.name, this.units, {this.groups = const [], this.pdqs = const []});
  final String name;
  final List<PortionUnit> units;

  /// Dietary diversity food groups (keys of `foodGroups` in catalog.dart).
  final List<String> groups;

  /// PDQS food groups (keys of `pdqsGroups` in pdqs_screen.dart).
  final List<String> pdqs;
}

/// Photo for each food database category (under assets/).
const foodCategoryImages = <String, String>{
  'Rice & Main Meals': 'plate/plate_hero.webp',
  'Curries & Side Dishes': 'food_groups/pulses.webp',
  'Mallung, Sambol & Salads': 'food_groups/dark_leafy.webp',
  'Protein & Add-ons': 'food_groups/meat_fish.webp',
  'Dairy': 'food_groups/dairy.webp',
  'Breakfast & Flour Foods': 'food_groups/breakfast.webp',
  'Short Eats': 'food_groups/fried_out.webp',
  'Bakery & Sweets': 'food_groups/sweets.webp',
  'Drinks': 'food_groups/ssb.webp',
  'Fruits': 'food_groups/other_fruit.webp',
};

class FoodCategory {
  const FoodCategory(this.name, this.foods);
  final String name;
  final List<Food> foods;
}

Food? foodByName(String name) {
  for (final c in foodDatabase) {
    for (final f in c.foods) {
      if (f.name == name) return f;
    }
  }
  return null;
}

PortionUnit unitOf(Food f, String label) => f.units.firstWhere((u) => u.label == label, orElse: () => f.units.first);

String pluralUnit(String unit) => unit == 'glass' ? 'glasses' : '${unit}s';

/// One food in a logged meal: what, how much, and its estimated energy and
/// food groups. Stored on the meal (meals.items) for diet quality scoring.
class LoggedItem {
  const LoggedItem(this.name, this.qty, this.unit, this.kcal, {this.groups = const [], this.pdqs = const []});
  final String name;
  final double qty;
  final String unit;
  final int kcal;
  final List<String> groups;
  final List<String> pdqs;

  factory LoggedItem.of(Food f, PortionUnit u, double qty) => LoggedItem(f.name, qty, u.label, (u.kcalPerUnit * qty).round(), groups: f.groups, pdqs: f.pdqs);

  String get portion => portionLabel(qty, unit);

  Map<String, dynamic> toJson() => {'name': name, 'qty': qty, 'unit': unit, 'kcal': kcal, 'groups': groups, 'pdqs': pdqs};

  static LoggedItem fromJson(Map<String, dynamic> j) => LoggedItem(
        '${j['name']}',
        (j['qty'] as num?)?.toDouble() ?? 1,
        '${j['unit'] ?? 'serving'}',
        (j['kcal'] as num?)?.round() ?? 0,
        groups: List<String>.from(j['groups'] ?? const []),
        pdqs: List<String>.from(j['pdqs'] ?? const []),
      );
}

/// "1 cup", "2 pieces", "1.5 cups".
String portionLabel(double qty, String unit) {
  final q = qty == qty.roundToDouble() ? qty.toStringAsFixed(0) : qty.toStringAsFixed(1);
  return '$q ${qty == 1 ? unit : pluralUnit(unit)}';
}

const _tbsp = 'tablespoon';
const _cup = 'cup';
const _piece = 'piece';
const _slice = 'slice';
const _egg = 'egg';
const _glass = 'glass';
const _serving = 'serving';

// Sri Lankan dietary diversity groups (see foodGroups in catalog.dart)
const _ce = 'cereals', _st = 'starchy', _ov = 'other_veg', _dl = 'dark_leafy', _fr = 'fruits';
const _pu = 'pulses', _mt = 'meat', _eg = 'eggs', _fi = 'fish', _da = 'dairy';

const foodDatabase = <FoodCategory>[
  FoodCategory('Rice & Main Meals', [
    Food('White rice', [PortionUnit(_tbsp, 25, max: 16), PortionUnit(_cup, 260, max: 4, step: 0.5), PortionUnit(_serving, 390, max: 3)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Red rice', [PortionUnit(_tbsp, 24, max: 16), PortionUnit(_cup, 250, max: 4, step: 0.5), PortionUnit(_serving, 370, max: 3)], groups: [_ce], pdqs: ['whole_grains']),
    Food('Rice & curry', [PortionUnit(_serving, 650, max: 3)], groups: [_ce, _pu, _ov], pdqs: ['refined_grains', 'legumes', 'other_veg']),
    Food('Fried rice', [PortionUnit(_cup, 340, max: 4, step: 0.5), PortionUnit(_serving, 450, max: 3)], groups: [_ce, _ov], pdqs: ['refined_grains', 'fried_out']),
    Food('Chicken fried rice', [PortionUnit(_cup, 380, max: 4, step: 0.5), PortionUnit(_serving, 520, max: 3)], groups: [_ce, _mt, _ov], pdqs: ['refined_grains', 'poultry', 'fried_out']),
    Food('Egg fried rice', [PortionUnit(_cup, 360, max: 4, step: 0.5), PortionUnit(_serving, 500, max: 3)], groups: [_ce, _eg, _ov], pdqs: ['refined_grains', 'eggs', 'fried_out']),
    Food('Vegetable fried rice', [PortionUnit(_cup, 330, max: 4, step: 0.5), PortionUnit(_serving, 460, max: 3)], groups: [_ce, _ov], pdqs: ['refined_grains', 'other_veg', 'fried_out']),
    Food('Kottu', [PortionUnit(_cup, 320, max: 4, step: 0.5), PortionUnit(_serving, 550, max: 3)], groups: [_ce, _ov], pdqs: ['refined_grains', 'fried_out']),
    Food('Chicken kottu', [PortionUnit(_cup, 380, max: 4, step: 0.5), PortionUnit(_serving, 650, max: 3)], groups: [_ce, _mt, _ov], pdqs: ['refined_grains', 'poultry', 'fried_out']),
    Food('Egg kottu', [PortionUnit(_cup, 360, max: 4, step: 0.5), PortionUnit(_serving, 600, max: 3)], groups: [_ce, _eg, _ov], pdqs: ['refined_grains', 'eggs', 'fried_out']),
    Food('Vegetable kottu', [PortionUnit(_cup, 300, max: 4, step: 0.5), PortionUnit(_serving, 500, max: 3)], groups: [_ce, _ov], pdqs: ['refined_grains', 'other_veg', 'fried_out']),
    Food('Biriyani', [PortionUnit(_cup, 350, max: 4, step: 0.5), PortionUnit(_serving, 550, max: 3)], groups: [_ce, _mt], pdqs: ['refined_grains', 'poultry']),
    Food('Yellow rice', [PortionUnit(_cup, 280, max: 4, step: 0.5), PortionUnit(_serving, 400, max: 3)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Noodles', [PortionUnit(_cup, 220, max: 4, step: 0.5), PortionUnit(_serving, 380, max: 3)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Instant noodles', [PortionUnit(_piece, 380, max: 3)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Pasta', [PortionUnit(_cup, 220, max: 4, step: 0.5), PortionUnit(_serving, 350, max: 3)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Milk rice', [PortionUnit(_piece, 130, max: 8), PortionUnit(_serving, 300, max: 3)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Steamed vegetables', [PortionUnit(_cup, 50, max: 4, step: 0.5), PortionUnit(_serving, 80, max: 3)], groups: [_ov], pdqs: ['other_veg', 'carrots']),
  ]),
  FoodCategory('Curries & Side Dishes', [
    Food('Dhal curry', [PortionUnit(_tbsp, 35, max: 12), PortionUnit(_cup, 280, max: 3, step: 0.5)], groups: [_pu], pdqs: ['legumes']),
    Food('Chickpea curry', [PortionUnit(_tbsp, 30, max: 12), PortionUnit(_cup, 230, max: 3, step: 0.5)], groups: [_pu], pdqs: ['legumes']),
    Food('Green gram curry', [PortionUnit(_tbsp, 28, max: 12), PortionUnit(_cup, 210, max: 3, step: 0.5)], groups: [_pu], pdqs: ['legumes']),
    Food('Soya meat curry', [PortionUnit(_tbsp, 30, max: 12), PortionUnit(_cup, 220, max: 3, step: 0.5)], groups: [_pu], pdqs: ['legumes']),
    Food('Potato curry', [PortionUnit(_tbsp, 30, max: 12), PortionUnit(_cup, 240, max: 3, step: 0.5)], groups: [_st], pdqs: ['potatoes']),
    Food('Polos (young jackfruit) curry', [PortionUnit(_tbsp, 22, max: 12), PortionUnit(_cup, 180, max: 3, step: 0.5)], groups: [_st]),
    Food('Breadfruit curry', [PortionUnit(_tbsp, 26, max: 12), PortionUnit(_cup, 220, max: 3, step: 0.5)], groups: [_st]),
    Food('Beans curry', [PortionUnit(_tbsp, 20, max: 12), PortionUnit(_cup, 160, max: 3, step: 0.5)], groups: [_ov], pdqs: ['other_veg']),
    Food('Pumpkin curry', [PortionUnit(_tbsp, 18, max: 12), PortionUnit(_cup, 140, max: 3, step: 0.5)], groups: [_ov], pdqs: ['other_veg']),
    Food('Carrot curry', [PortionUnit(_tbsp, 18, max: 12), PortionUnit(_cup, 140, max: 3, step: 0.5)], groups: [_ov], pdqs: ['carrots']),
    Food('Brinjal curry', [PortionUnit(_tbsp, 25, max: 12), PortionUnit(_cup, 200, max: 3, step: 0.5)], groups: [_ov], pdqs: ['other_veg']),
    Food('Beetroot curry', [PortionUnit(_tbsp, 20, max: 12), PortionUnit(_cup, 150, max: 3, step: 0.5)], groups: [_ov], pdqs: ['other_veg']),
    Food('Cabbage curry', [PortionUnit(_tbsp, 15, max: 12), PortionUnit(_cup, 110, max: 3, step: 0.5)], groups: [_ov], pdqs: ['cruciferous']),
    Food('Mushroom curry', [PortionUnit(_tbsp, 20, max: 12), PortionUnit(_cup, 150, max: 3, step: 0.5)], groups: [_ov], pdqs: ['other_veg']),
    Food('Chicken curry', [PortionUnit(_piece, 90, max: 6), PortionUnit(_tbsp, 40, max: 12)], groups: [_mt], pdqs: ['poultry']),
    Food('Fish curry', [PortionUnit(_piece, 80, max: 6), PortionUnit(_tbsp, 35, max: 12)], groups: [_fi], pdqs: ['fish']),
    Food('Beef curry', [PortionUnit(_piece, 110, max: 6), PortionUnit(_tbsp, 45, max: 12)], groups: [_mt], pdqs: ['red_meat']),
    Food('Egg curry', [PortionUnit(_egg, 90, max: 4), PortionUnit(_tbsp, 35, max: 12)], groups: [_eg], pdqs: ['eggs']),
    Food('Sprats', [PortionUnit(_tbsp, 25, max: 12)], groups: [_fi], pdqs: ['fish']),
    Food('Dry fish', [PortionUnit(_tbsp, 30, max: 12)], groups: [_fi], pdqs: ['fish']),
    Food('Papadam', [PortionUnit(_piece, 35, max: 8)]),
  ]),
  FoodCategory('Mallung, Sambol & Salads', [
    Food('Gotukola mallung', [PortionUnit(_tbsp, 15, max: 12), PortionUnit(_cup, 90, max: 3, step: 0.5)], groups: [_dl], pdqs: ['dark_leafy']),
    Food('Mukunuwenna mallung', [PortionUnit(_tbsp, 15, max: 12), PortionUnit(_cup, 90, max: 3, step: 0.5)], groups: [_dl], pdqs: ['dark_leafy']),
    Food('Kankun stir-fry', [PortionUnit(_tbsp, 18, max: 12), PortionUnit(_cup, 110, max: 3, step: 0.5)], groups: [_dl], pdqs: ['dark_leafy']),
    Food('Other leafy mallung', [PortionUnit(_tbsp, 15, max: 12), PortionUnit(_cup, 90, max: 3, step: 0.5)], groups: [_dl], pdqs: ['dark_leafy']),
    Food('Pol sambol', [PortionUnit(_tbsp, 45, max: 8)]),
    Food('Seeni sambol', [PortionUnit(_tbsp, 40, max: 8)]),
    Food('Lunu miris', [PortionUnit(_tbsp, 25, max: 8)]),
    Food('Vegetable salad', [PortionUnit(_tbsp, 10, max: 12), PortionUnit(_cup, 40, max: 3, step: 0.5)], groups: [_ov], pdqs: ['other_veg']),
    Food('Cucumber salad', [PortionUnit(_tbsp, 5, max: 12), PortionUnit(_cup, 20, max: 3, step: 0.5)], groups: [_ov], pdqs: ['other_veg']),
  ]),
  FoodCategory('Protein & Add-ons', [
    Food('Boiled egg', [PortionUnit(_egg, 78, max: 4)], groups: [_eg], pdqs: ['eggs']),
    Food('Fried egg', [PortionUnit(_egg, 90, max: 4)], groups: [_eg], pdqs: ['eggs']),
    Food('Omelette', [PortionUnit(_piece, 120, max: 3)], groups: [_eg], pdqs: ['eggs']),
    Food('Chicken', [PortionUnit(_piece, 150, max: 6)], groups: [_mt], pdqs: ['poultry']),
    Food('Fish', [PortionUnit(_piece, 120, max: 6)], groups: [_fi], pdqs: ['fish']),
    Food('Tinned fish', [PortionUnit(_tbsp, 30, max: 12)], groups: [_fi], pdqs: ['fish']),
    Food('Sausage', [PortionUnit(_piece, 110, max: 6)], groups: [_mt], pdqs: ['processed_meat']),
    Food('Soya meat', [PortionUnit(_tbsp, 30, max: 12), PortionUnit(_cup, 220, max: 3, step: 0.5)], groups: [_pu], pdqs: ['legumes']),
    Food('Boiled chickpeas', [PortionUnit(_tbsp, 30, max: 12), PortionUnit(_cup, 230, max: 3, step: 0.5)], groups: [_pu], pdqs: ['legumes']),
    Food('Boiled green gram', [PortionUnit(_tbsp, 28, max: 12), PortionUnit(_cup, 210, max: 3, step: 0.5)], groups: [_pu], pdqs: ['legumes']),
    Food('Peanuts', [PortionUnit(_tbsp, 55, max: 8)], groups: [_pu], pdqs: ['nuts']),
    Food('Cashew nuts', [PortionUnit(_tbsp, 50, max: 8)], groups: [_pu], pdqs: ['nuts']),
    Food('Sesame (thala) balls', [PortionUnit(_piece, 60, max: 6)], groups: [_pu], pdqs: ['nuts', 'sweets']),
  ]),
  FoodCategory('Dairy', [
    Food('Milk', [PortionUnit(_glass, 150, max: 3)], groups: [_da]),
    Food('Low-fat milk', [PortionUnit(_glass, 100, max: 3)], groups: [_da], pdqs: ['low_fat_dairy']),
    Food('Curd', [PortionUnit(_cup, 180, max: 3, step: 0.5)], groups: [_da]),
    Food('Yoghurt', [PortionUnit(_piece, 90, max: 4)], groups: [_da], pdqs: ['low_fat_dairy']),
    Food('Cheese', [PortionUnit(_slice, 70, max: 4)], groups: [_da]),
  ]),
  FoodCategory('Breakfast & Flour Foods', [
    Food('String hoppers', [PortionUnit(_piece, 35, max: 15)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Hoppers', [PortionUnit(_piece, 120, max: 6)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Egg hoppers', [PortionUnit(_piece, 170, max: 6)], groups: [_ce, _eg], pdqs: ['refined_grains', 'eggs']),
    Food('Roti', [PortionUnit(_piece, 140, max: 6)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Kurakkan roti', [PortionUnit(_piece, 130, max: 6)], groups: [_ce], pdqs: ['whole_grains']),
    Food('Paratha', [PortionUnit(_piece, 260, max: 6)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Chapati', [PortionUnit(_piece, 120, max: 6)], groups: [_ce], pdqs: ['whole_grains']),
    Food('Pittu', [PortionUnit(_cup, 240, max: 4, step: 0.5)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Oats porridge', [PortionUnit(_cup, 160, max: 3, step: 0.5)], groups: [_ce], pdqs: ['whole_grains']),
    Food('Boiled manioc (cassava)', [PortionUnit(_piece, 110, max: 8), PortionUnit(_cup, 320, max: 3, step: 0.5)], groups: [_st]),
    Food('Boiled sweet potato', [PortionUnit(_piece, 130, max: 4), PortionUnit(_cup, 180, max: 3, step: 0.5)], groups: [_st]),
    Food('Bread', [PortionUnit(_slice, 75, max: 10)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Wholemeal bread', [PortionUnit(_slice, 70, max: 10)], groups: [_ce], pdqs: ['whole_grains']),
    Food('Egg sandwich', [PortionUnit(_piece, 230, max: 4)], groups: [_ce, _eg], pdqs: ['refined_grains', 'eggs']),
    Food('Chicken sandwich', [PortionUnit(_piece, 260, max: 4)], groups: [_ce, _mt], pdqs: ['refined_grains', 'poultry']),
    Food('Vegetable sandwich', [PortionUnit(_piece, 200, max: 4)], groups: [_ce, _ov], pdqs: ['refined_grains', 'other_veg']),
    Food('Lawariya', [PortionUnit(_piece, 150, max: 6)], groups: [_ce], pdqs: ['refined_grains', 'sweets']),
    Food('Pancake', [PortionUnit(_piece, 150, max: 6)], groups: [_ce], pdqs: ['refined_grains', 'sweets']),
  ]),
  FoodCategory('Short Eats', [
    Food('Ulundu vadai', [PortionUnit(_piece, 110, max: 10)], groups: [_pu], pdqs: ['legumes', 'fried_out']),
    Food('Parippu vadai', [PortionUnit(_piece, 100, max: 10)], groups: [_pu], pdqs: ['legumes', 'fried_out']),
    Food('Fish bun', [PortionUnit(_piece, 250, max: 6)], groups: [_ce, _fi], pdqs: ['refined_grains', 'fish']),
    Food('Egg bun', [PortionUnit(_piece, 240, max: 6)], groups: [_ce, _eg], pdqs: ['refined_grains', 'eggs']),
    Food('Chicken bun', [PortionUnit(_piece, 260, max: 6)], groups: [_ce, _mt], pdqs: ['refined_grains', 'poultry']),
    Food('Fish roll', [PortionUnit(_piece, 220, max: 6)], groups: [_ce, _fi], pdqs: ['fried_out', 'fish']),
    Food('Vegetable roll', [PortionUnit(_piece, 200, max: 6)], groups: [_ce, _ov], pdqs: ['fried_out']),
    Food('Chicken roll', [PortionUnit(_piece, 230, max: 6)], groups: [_ce, _mt], pdqs: ['fried_out', 'poultry']),
    Food('Patties', [PortionUnit(_piece, 230, max: 6)], groups: [_ce], pdqs: ['fried_out']),
    Food('Samosa', [PortionUnit(_piece, 130, max: 8)], groups: [_ce], pdqs: ['fried_out']),
    Food('Fish cutlet', [PortionUnit(_piece, 120, max: 8)], groups: [_fi], pdqs: ['fried_out', 'fish']),
    Food('Pastry', [PortionUnit(_piece, 250, max: 6)], groups: [_ce], pdqs: ['refined_grains']),
    Food('Vegetable roti', [PortionUnit(_piece, 180, max: 6)], groups: [_ce, _ov], pdqs: ['refined_grains']),
    Food('Potato chips', [PortionUnit(_cup, 160, max: 4, step: 0.5)], groups: [_st], pdqs: ['potatoes', 'fried_out']),
  ]),
  FoodCategory('Bakery & Sweets', [
    Food('Cake', [PortionUnit(_slice, 300, max: 6)], pdqs: ['sweets']),
    Food('Chocolate cake', [PortionUnit(_slice, 350, max: 6)], pdqs: ['sweets']),
    Food('Cupcake', [PortionUnit(_piece, 180, max: 6)], pdqs: ['sweets']),
    Food('Doughnut', [PortionUnit(_piece, 250, max: 6)], pdqs: ['sweets']),
    Food('Biscuits', [PortionUnit(_piece, 25, max: 20)], pdqs: ['refined_grains']),
    Food('Chocolate', [PortionUnit(_piece, 55, max: 10)], pdqs: ['sweets']),
    Food('Ice cream', [PortionUnit(_cup, 270, max: 3, step: 0.5)], pdqs: ['sweets']),
    Food('Watalappam', [PortionUnit(_serving, 250, max: 3)], pdqs: ['sweets']),
    Food('Kavum or kokis', [PortionUnit(_piece, 120, max: 6)], pdqs: ['sweets', 'fried_out']),
  ]),
  FoodCategory('Drinks', [
    Food('Soft drink', [PortionUnit(_glass, 140, max: 4)], pdqs: ['ssb']),
    Food('Packet fruit juice', [PortionUnit(_glass, 120, max: 4)], pdqs: ['ssb']),
    Food('Fresh fruit juice', [PortionUnit(_glass, 90, max: 4)]),
    Food('King coconut water', [PortionUnit(_glass, 45, max: 4)]),
    Food('Plain tea', [PortionUnit(_glass, 5, max: 6)]),
    Food('Tea with sugar', [PortionUnit(_glass, 60, max: 6)], pdqs: ['ssb']),
    Food('Milk tea', [PortionUnit(_glass, 90, max: 4)], groups: [_da]),
    Food('Coffee', [PortionUnit(_glass, 5, max: 4)]),
    Food('Iced coffee', [PortionUnit(_glass, 180, max: 3)], groups: [_da], pdqs: ['ssb']),
    Food('Milo or malted drink', [PortionUnit(_glass, 180, max: 3)], groups: [_da], pdqs: ['ssb']),
    Food('Milkshake', [PortionUnit(_glass, 250, max: 3)], groups: [_da], pdqs: ['ssb']),
    Food('Flavoured milk', [PortionUnit(_glass, 180, max: 3)], groups: [_da], pdqs: ['ssb']),
  ]),
  FoodCategory('Fruits', [
    Food('Banana', [PortionUnit(_piece, 105, max: 6)], groups: [_fr], pdqs: ['other_fruit']),
    Food('Papaya', [PortionUnit(_cup, 55, max: 4, step: 0.5)], groups: [_fr], pdqs: ['other_fruit']),
    Food('Mango', [PortionUnit(_piece, 135, max: 4)], groups: [_fr], pdqs: ['other_fruit']),
    Food('Pineapple', [PortionUnit(_slice, 50, max: 8)], groups: [_fr], pdqs: ['other_fruit']),
    Food('Watermelon', [PortionUnit(_slice, 46, max: 8)], groups: [_fr], pdqs: ['other_fruit']),
    Food('Guava', [PortionUnit(_piece, 68, max: 4)], groups: [_fr], pdqs: ['other_fruit']),
    Food('Orange', [PortionUnit(_piece, 62, max: 4)], groups: [_fr], pdqs: ['citrus']),
    Food('Apple', [PortionUnit(_piece, 95, max: 4)], groups: [_fr], pdqs: ['other_fruit']),
    Food('Rambutan', [PortionUnit(_piece, 15, max: 15)], groups: [_fr], pdqs: ['other_fruit']),
    Food('Avocado', [PortionUnit(_piece, 160, max: 3)], groups: [_fr], pdqs: ['other_fruit']),
  ]),
];
