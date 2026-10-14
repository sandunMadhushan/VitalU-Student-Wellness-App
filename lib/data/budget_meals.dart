/// Low-cost, balanced meal combinations for the Budget planner, built from
/// foods in the shared food database so their energy and food groups match
/// what students log.
///
/// Prices are rough Sri Lankan campus estimates in rupees (canteen price,
/// or the cost of ingredients for one portion when cooked at the hostel or
/// boarding place). They vary by area and season.
library;

import 'food_db.dart';

enum MealSlot { breakfast, main, snack }

enum MealKind { canteen, quick, batch }

String slotLabel(MealSlot s) => switch (s) {
      MealSlot.breakfast => 'Breakfast',
      MealSlot.main => 'Lunch or dinner',
      MealSlot.snack => 'Snack',
    };

String kindLabel(MealKind k) => switch (k) {
      MealKind.canteen => 'Canteen',
      MealKind.quick => '10-min prep',
      MealKind.batch => 'Batch cook',
    };

class BudgetMeal {
  const BudgetMeal(this.id, this.name, this.slot, this.kind, this.price, this.items, {this.ingredients = const [], this.note});
  final String id;
  final String name;
  final MealSlot slot;
  final MealKind kind;

  /// Estimated price of one portion, in rupees.
  final int price;

  /// (food name, unit label, quantity) from the food database.
  final List<(String, String, double)> items;

  /// What to buy, for meals made at home.
  final List<String> ingredients;
  final String? note;

  List<LoggedItem> get logged => [
        for (final (name, unit, qty) in items)
          if (foodByName(name) case final f?) LoggedItem.of(f, unitOf(f, unit), qty),
      ];

  int get kcal => logged.fold(0, (a, i) => a + i.kcal);
  Set<String> get groups => {for (final i in logged) ...i.groups};
}

const budgetMeals = <BudgetMeal>[
  // Breakfast
  BudgetMeal('sh_dhal', 'String hoppers, dhal and pol sambol', MealSlot.breakfast, MealKind.canteen, 160,
      [('String hoppers', 'piece', 10), ('Dhal curry', 'tablespoon', 4), ('Pol sambol', 'tablespoon', 1)]),
  BudgetMeal('bread_dhal_egg', 'Bread, dhal and a boiled egg', MealSlot.breakfast, MealKind.quick, 140,
      [('Wholemeal bread', 'slice', 3), ('Dhal curry', 'tablespoon', 4), ('Boiled egg', 'egg', 1)],
      ingredients: ['Wholemeal bread', 'Red lentils (dhal)', 'Eggs'], note: 'Cook a pot of dhal for three days.'),
  BudgetMeal('oats_banana', 'Oats with milk and a banana', MealSlot.breakfast, MealKind.quick, 150,
      [('Oats porridge', 'cup', 1), ('Milk', 'glass', 0.5), ('Banana', 'piece', 1)], ingredients: ['Oats', 'Milk powder', 'Bananas']),
  BudgetMeal('kurakkan_egg', 'Kurakkan roti, egg and lunu miris', MealSlot.breakfast, MealKind.canteen, 170,
      [('Kurakkan roti', 'piece', 2), ('Boiled egg', 'egg', 1), ('Lunu miris', 'tablespoon', 1)]),
  BudgetMeal('green_gram', 'Boiled green gram and a banana', MealSlot.breakfast, MealKind.batch, 110,
      [('Boiled green gram', 'cup', 1), ('Banana', 'piece', 1)], ingredients: ['Green gram (mung)', 'Bananas'], note: 'Soak overnight, boil in the morning.'),
  BudgetMeal('chickpea_bf', 'Boiled chickpeas and plain tea', MealSlot.breakfast, MealKind.canteen, 120, [('Boiled chickpeas', 'cup', 1), ('Plain tea', 'glass', 1)]),
  BudgetMeal('hoppers', 'Hoppers, egg hopper and seeni sambol', MealSlot.breakfast, MealKind.canteen, 220,
      [('Hoppers', 'piece', 2), ('Egg hoppers', 'piece', 1), ('Seeni sambol', 'tablespoon', 1)]),

  // Lunch or dinner
  BudgetMeal('rc_veg', 'Vegetable rice and curry', MealSlot.main, MealKind.canteen, 220,
      [('Red rice', 'serving', 1), ('Dhal curry', 'tablespoon', 4), ('Beans curry', 'tablespoon', 4), ('Gotukola mallung', 'tablespoon', 3)]),
  BudgetMeal('rc_egg', 'Rice and curry with egg', MealSlot.main, MealKind.canteen, 270,
      [('Red rice', 'serving', 1), ('Egg curry', 'egg', 1), ('Dhal curry', 'tablespoon', 3), ('Pumpkin curry', 'tablespoon', 3), ('Cabbage curry', 'tablespoon', 3)]),
  BudgetMeal('rc_fish', 'Rice and curry with fish', MealSlot.main, MealKind.canteen, 330,
      [('Red rice', 'serving', 1), ('Fish curry', 'piece', 1), ('Dhal curry', 'tablespoon', 3), ('Mukunuwenna mallung', 'tablespoon', 3), ('Beans curry', 'tablespoon', 3)]),
  BudgetMeal('rc_chicken', 'Rice and curry with chicken', MealSlot.main, MealKind.canteen, 380,
      [('Red rice', 'serving', 1), ('Chicken curry', 'piece', 2), ('Dhal curry', 'tablespoon', 3), ('Carrot curry', 'tablespoon', 3), ('Gotukola mallung', 'tablespoon', 3)]),
  BudgetMeal('dhal_kankun', 'Rice, dhal and kankun', MealSlot.main, MealKind.batch, 150,
      [('Red rice', 'cup', 1.5), ('Dhal curry', 'cup', 0.5), ('Kankun stir-fry', 'cup', 0.5)],
      ingredients: ['Red rice', 'Red lentils (dhal)', 'Kankun', 'Onions and garlic'], note: 'Dhal keeps for 2 to 3 days in a closed box.'),
  BudgetMeal('soya_rice', 'Soya meat curry, rice and salad', MealSlot.main, MealKind.batch, 170,
      [('Red rice', 'cup', 1.5), ('Soya meat curry', 'cup', 0.5), ('Pumpkin curry', 'cup', 0.5), ('Cucumber salad', 'cup', 1)],
      ingredients: ['Red rice', 'Soya meat', 'Pumpkin', 'Cucumber and tomato']),
  BudgetMeal('tinned_fish', 'Tinned fish curry, rice and cabbage', MealSlot.main, MealKind.batch, 210,
      [('Red rice', 'cup', 1.5), ('Tinned fish', 'tablespoon', 4), ('Cabbage curry', 'cup', 0.5), ('Carrot curry', 'cup', 0.5)],
      ingredients: ['Red rice', 'Tinned mackerel', 'Cabbage', 'Carrots'], note: 'One tin makes about three portions.'),
  BudgetMeal('sprats_rice', 'Sprats, rice and gotukola', MealSlot.main, MealKind.batch, 180,
      [('Red rice', 'cup', 1.5), ('Sprats', 'tablespoon', 3), ('Dhal curry', 'tablespoon', 3), ('Gotukola mallung', 'tablespoon', 4)],
      ingredients: ['Red rice', 'Dried sprats', 'Red lentils (dhal)', 'Gotukola']),
  BudgetMeal('chickpea_roti', 'Chapati, chickpea curry and salad', MealSlot.main, MealKind.batch, 170,
      [('Chapati', 'piece', 2), ('Chickpea curry', 'cup', 0.5), ('Vegetable salad', 'cup', 1)],
      ingredients: ['Atta flour', 'Chickpeas (kadala)', 'Carrots, tomato and lettuce']),
  BudgetMeal('egg_rice_home', 'Egg fried rice with vegetables', MealSlot.main, MealKind.quick, 180,
      [('Egg fried rice', 'cup', 1.5), ('Vegetable salad', 'cup', 1)], ingredients: ['Rice', 'Eggs', 'Carrots, leeks and cabbage'], note: 'Use leftover rice from the night before.'),
  BudgetMeal('noodles_egg', 'Noodles with egg and vegetables', MealSlot.main, MealKind.quick, 170,
      [('Instant noodles', 'piece', 1), ('Boiled egg', 'egg', 1), ('Steamed vegetables', 'cup', 1)],
      ingredients: ['Instant noodles', 'Eggs', 'Carrots and beans'], note: 'Use half the flavour sachet to cut the salt.'),
  BudgetMeal('veg_kottu', 'Vegetable kottu', MealSlot.main, MealKind.canteen, 300, [('Vegetable kottu', 'serving', 1)]),
  BudgetMeal('chicken_kottu', 'Chicken kottu', MealSlot.main, MealKind.canteen, 450, [('Chicken kottu', 'serving', 1)]),

  // Snacks
  BudgetMeal('banana', 'A banana', MealSlot.snack, MealKind.quick, 40, [('Banana', 'piece', 1)], ingredients: ['Bananas']),
  BudgetMeal('papaya', 'A cup of papaya', MealSlot.snack, MealKind.quick, 60, [('Papaya', 'cup', 1)], ingredients: ['Papaya']),
  BudgetMeal('peanuts_guava', 'Peanuts and a guava', MealSlot.snack, MealKind.quick, 80, [('Peanuts', 'tablespoon', 2), ('Guava', 'piece', 1)], ingredients: ['Peanuts', 'Guava']),
  BudgetMeal('curd', 'A cup of curd', MealSlot.snack, MealKind.canteen, 120, [('Curd', 'cup', 0.5)]),
  BudgetMeal('milk', 'A glass of milk', MealSlot.snack, MealKind.quick, 90, [('Milk', 'glass', 1)], ingredients: ['Milk powder']),
  BudgetMeal('vadai_tea', 'Parippu vadai and plain tea', MealSlot.snack, MealKind.canteen, 90, [('Parippu vadai', 'piece', 2), ('Plain tea', 'glass', 1)]),
];

BudgetMeal? budgetMealById(String id) {
  for (final m in budgetMeals) {
    if (m.id == id) return m;
  }
  return null;
}

/// Meals in a week the planner aims to cover.
const slotTargets = {MealSlot.breakfast: 7, MealSlot.main: 14, MealSlot.snack: 7};

/// Share of the weekly budget for each kind of meal.
const _slotShare = {MealSlot.breakfast: 0.22, MealSlot.main: 0.63, MealSlot.snack: 0.15};

/// A varied week within [budget]: for each kind of meal it picks the most
/// varied options that fit that meal's share of the budget, rotates between
/// them, then swaps the dearest servings for cheaper ones until the week
/// fits. Returns meal id → times a week.
Map<String, int> suggestBudgetPlan(double budget) {
  final plan = <String, int>{};
  for (final slot in MealSlot.values) {
    final n = slotTargets[slot]!;
    final cap = budget * _slotShare[slot]! / n;
    final all = budgetMeals.where((m) => m.slot == slot).toList()
      ..sort((a, b) {
        final g = b.groups.length.compareTo(a.groups.length);
        return g != 0 ? g : a.price.compareTo(b.price);
      });
    var pick = all.where((m) => m.price <= cap).toList();
    if (pick.isEmpty) pick = ([...all]..sort((a, b) => a.price.compareTo(b.price))).take(2).toList();
    pick = pick.take(slot == MealSlot.main ? 5 : 3).toList();
    for (int i = 0; i < n; i++) {
      final m = pick[i % pick.length];
      plan[m.id] = (plan[m.id] ?? 0) + 1;
    }
  }
  int total() => plan.entries.fold(0, (a, e) => a + budgetMealById(e.key)!.price * e.value);
  var guard = 0;
  while (total() > budget && guard++ < 60) {
    final dear = plan.keys.map(budgetMealById).whereType<BudgetMeal>().reduce((a, b) => a.price >= b.price ? a : b);
    final cheaper = budgetMeals.where((m) => m.slot == dear.slot && m.price < dear.price).toList()..sort((a, b) => a.price.compareTo(b.price));
    if (cheaper.isEmpty) break;
    final swap = cheaper.firstWhere((m) => plan.containsKey(m.id), orElse: () => cheaper.first);
    plan[dear.id] = plan[dear.id]! - 1;
    if (plan[dear.id] == 0) plan.remove(dear.id);
    plan[swap.id] = (plan[swap.id] ?? 0) + 1;
  }
  return plan;
}
