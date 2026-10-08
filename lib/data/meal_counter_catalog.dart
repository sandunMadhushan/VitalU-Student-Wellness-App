/// Initial food database for the Meal Calorie Counter, built mainly around
/// foods commonly eaten by Sri Lankan university students (canteen, hostel
/// and short-eat staples). Every value is an estimate — actual energy
/// content varies with ingredients, recipe and preparation — and the list
/// is designed so more foods can be appended under an existing or new
/// category without touching the counter screen itself.
library;

/// A practical way to measure a portion of a food (a tablespoon, a cup, a
/// whole piece, and so on), with the estimated kcal for exactly one of that
/// unit and a sensible range for the quantity stepper.
class PortionUnit {
  const PortionUnit(this.label, this.kcalPerUnit, {this.min = 1, this.max = 20, this.step = 1});
  final String label;
  final double kcalPerUnit;
  final double min;
  final double max;
  final double step;
}

class MealCounterFood {
  const MealCounterFood(this.name, this.units);
  final String name;
  final List<PortionUnit> units;
}

class MealCounterCategory {
  const MealCounterCategory(this.name, this.foods);
  final String name;
  final List<MealCounterFood> foods;
}

const _tbsp = 'tablespoon';
const _cup = 'cup';
const _piece = 'piece';
const _slice = 'slice';
const _egg = 'egg';
const _glass = 'glass';
const _serving = 'serving';

const mealCounterCatalog = <MealCounterCategory>[
  MealCounterCategory('Rice & Main Meals', [
    MealCounterFood('White rice', [PortionUnit(_tbsp, 25, max: 16), PortionUnit(_cup, 260, max: 4, step: 0.5), PortionUnit(_serving, 390, max: 3)]),
    MealCounterFood('Red rice', [PortionUnit(_tbsp, 24, max: 16), PortionUnit(_cup, 250, max: 4, step: 0.5), PortionUnit(_serving, 370, max: 3)]),
    MealCounterFood('Fried rice', [PortionUnit(_cup, 340, max: 4, step: 0.5), PortionUnit(_serving, 450, max: 3)]),
    MealCounterFood('Chicken fried rice', [PortionUnit(_cup, 380, max: 4, step: 0.5), PortionUnit(_serving, 520, max: 3)]),
    MealCounterFood('Egg fried rice', [PortionUnit(_cup, 360, max: 4, step: 0.5), PortionUnit(_serving, 500, max: 3)]),
    MealCounterFood('Vegetable fried rice', [PortionUnit(_cup, 330, max: 4, step: 0.5), PortionUnit(_serving, 460, max: 3)]),
    MealCounterFood('Kottu', [PortionUnit(_cup, 320, max: 4, step: 0.5), PortionUnit(_serving, 550, max: 3)]),
    MealCounterFood('Chicken kottu', [PortionUnit(_cup, 380, max: 4, step: 0.5), PortionUnit(_serving, 650, max: 3)]),
    MealCounterFood('Egg kottu', [PortionUnit(_cup, 360, max: 4, step: 0.5), PortionUnit(_serving, 600, max: 3)]),
    MealCounterFood('Vegetable kottu', [PortionUnit(_cup, 300, max: 4, step: 0.5), PortionUnit(_serving, 500, max: 3)]),
    MealCounterFood('Rice & curry', [PortionUnit(_serving, 650, max: 3)]),
    MealCounterFood('Biriyani', [PortionUnit(_cup, 350, max: 4, step: 0.5), PortionUnit(_serving, 550, max: 3)]),
    MealCounterFood('Yellow rice', [PortionUnit(_cup, 280, max: 4, step: 0.5), PortionUnit(_serving, 400, max: 3)]),
    MealCounterFood('Pasta', [PortionUnit(_cup, 220, max: 4, step: 0.5), PortionUnit(_serving, 350, max: 3)]),
    MealCounterFood('Milk Rice', [PortionUnit(_piece, 130, max: 8), PortionUnit(_serving, 300, max: 3)]),
    MealCounterFood('Steamed vegetables', [PortionUnit(_cup, 50, max: 4, step: 0.5), PortionUnit(_serving, 80, max: 3)]),
  ]),
  MealCounterCategory('Curries & Side Dishes', [
    MealCounterFood('Dhal curry', [PortionUnit(_tbsp, 35, max: 12), PortionUnit(_cup, 280, max: 3, step: 0.5)]),
    MealCounterFood('Potato curry', [PortionUnit(_tbsp, 30, max: 12), PortionUnit(_cup, 240, max: 3, step: 0.5)]),
    MealCounterFood('Beans curry', [PortionUnit(_tbsp, 20, max: 12), PortionUnit(_cup, 160, max: 3, step: 0.5)]),
    MealCounterFood('Pumpkin curry', [PortionUnit(_tbsp, 18, max: 12), PortionUnit(_cup, 140, max: 3, step: 0.5)]),
    MealCounterFood('Brinjal curry', [PortionUnit(_tbsp, 25, max: 12), PortionUnit(_cup, 200, max: 3, step: 0.5)]),
    MealCounterFood('Carrot curry', [PortionUnit(_tbsp, 18, max: 12), PortionUnit(_cup, 140, max: 3, step: 0.5)]),
    MealCounterFood('Beetroot curry', [PortionUnit(_tbsp, 20, max: 12), PortionUnit(_cup, 150, max: 3, step: 0.5)]),
    MealCounterFood('Cabbage curry', [PortionUnit(_tbsp, 15, max: 12), PortionUnit(_cup, 110, max: 3, step: 0.5)]),
    MealCounterFood('Mushroom curry', [PortionUnit(_tbsp, 20, max: 12), PortionUnit(_cup, 150, max: 3, step: 0.5)]),
    MealCounterFood('Soya meat curry', [PortionUnit(_tbsp, 30, max: 12), PortionUnit(_cup, 220, max: 3, step: 0.5)]),
    MealCounterFood('Chicken curry', [PortionUnit(_piece, 90, max: 6), PortionUnit(_tbsp, 40, max: 12)]),
    MealCounterFood('Fish curry', [PortionUnit(_piece, 80, max: 6), PortionUnit(_tbsp, 35, max: 12)]),
    MealCounterFood('Egg curry', [PortionUnit(_egg, 90, max: 4), PortionUnit(_tbsp, 35, max: 12)]),
    MealCounterFood('Chickpea curry', [PortionUnit(_tbsp, 30, max: 12), PortionUnit(_cup, 230, max: 3, step: 0.5)]),
    MealCounterFood('Green gram curry', [PortionUnit(_tbsp, 28, max: 12), PortionUnit(_cup, 210, max: 3, step: 0.5)]),
    MealCounterFood('Sprats', [PortionUnit(_tbsp, 25, max: 12)]),
    MealCounterFood('Dry fish', [PortionUnit(_tbsp, 30, max: 12)]),
    MealCounterFood('Papadam', [PortionUnit(_piece, 35, max: 8)]),
  ]),
  MealCounterCategory('Mallung, Sambol & Salads', [
    MealCounterFood('Gotukola mallung', [PortionUnit(_tbsp, 15, max: 12), PortionUnit(_cup, 90, max: 3, step: 0.5)]),
    MealCounterFood('Mukunuwenna mallung', [PortionUnit(_tbsp, 15, max: 12), PortionUnit(_cup, 90, max: 3, step: 0.5)]),
    MealCounterFood('Other leafy mallung', [PortionUnit(_tbsp, 15, max: 12), PortionUnit(_cup, 90, max: 3, step: 0.5)]),
    MealCounterFood('Coconut sambol / Pol sambol', [PortionUnit(_tbsp, 45, max: 8)]),
    MealCounterFood('Seeni sambol', [PortionUnit(_tbsp, 40, max: 8)]),
    MealCounterFood('Lunu miris', [PortionUnit(_tbsp, 25, max: 8)]),
    MealCounterFood('Vegetable salad', [PortionUnit(_tbsp, 10, max: 12), PortionUnit(_cup, 40, max: 3, step: 0.5)]),
    MealCounterFood('Cucumber salad', [PortionUnit(_tbsp, 5, max: 12), PortionUnit(_cup, 20, max: 3, step: 0.5)]),
  ]),
  MealCounterCategory('Protein / Add-ons', [
    MealCounterFood('Boiled egg', [PortionUnit(_egg, 78, max: 4)]),
    MealCounterFood('Fried egg', [PortionUnit(_egg, 90, max: 4)]),
    MealCounterFood('Omelette', [PortionUnit(_piece, 120, max: 3), PortionUnit(_egg, 120, max: 4)]),
    MealCounterFood('Chicken', [PortionUnit(_piece, 150, max: 6)]),
    MealCounterFood('Fish', [PortionUnit(_piece, 120, max: 6)]),
    MealCounterFood('Sprats (add-on)', [PortionUnit(_tbsp, 25, max: 12)]),
    MealCounterFood('Soya meat', [PortionUnit(_tbsp, 30, max: 12), PortionUnit(_cup, 220, max: 3, step: 0.5)]),
    MealCounterFood('Chickpeas', [PortionUnit(_tbsp, 30, max: 12), PortionUnit(_cup, 230, max: 3, step: 0.5)]),
    MealCounterFood('Green gram', [PortionUnit(_tbsp, 28, max: 12), PortionUnit(_cup, 210, max: 3, step: 0.5)]),
    MealCounterFood('Dry fish (add-on)', [PortionUnit(_tbsp, 30, max: 12)]),
  ]),
  MealCounterCategory('Breakfast & Flour-Based Foods', [
    MealCounterFood('String hoppers', [PortionUnit(_piece, 35, max: 12)]),
    MealCounterFood('Hoppers', [PortionUnit(_piece, 120, max: 6)]),
    MealCounterFood('Egg hoppers', [PortionUnit(_piece, 170, max: 6)]),
    MealCounterFood('Roti', [PortionUnit(_piece, 140, max: 6)]),
    MealCounterFood('Paratha', [PortionUnit(_piece, 260, max: 6)]),
    MealCounterFood('Chapati', [PortionUnit(_piece, 120, max: 6)]),
    MealCounterFood('Pittu', [PortionUnit(_cup, 240, max: 4, step: 0.5), PortionUnit(_serving, 240, max: 3)]),
    MealCounterFood('Bread', [PortionUnit(_slice, 75, max: 10)]),
    MealCounterFood('Sandwich', [PortionUnit(_piece, 200, max: 4)]),
    MealCounterFood('Egg sandwich', [PortionUnit(_piece, 230, max: 4)]),
    MealCounterFood('Chicken sandwich', [PortionUnit(_piece, 260, max: 4)]),
    MealCounterFood('Lawariya', [PortionUnit(_piece, 150, max: 6)]),
    MealCounterFood('Pancake', [PortionUnit(_piece, 150, max: 6)]),
    MealCounterFood('Halapa', [PortionUnit(_piece, 130, max: 6)]),
  ]),
  MealCounterCategory('Short Eats', [
    MealCounterFood('Vade / Ulundu vade', [PortionUnit(_piece, 110, max: 10)]),
    MealCounterFood('Parippu vade', [PortionUnit(_piece, 100, max: 10)]),
    MealCounterFood('Fish bun', [PortionUnit(_piece, 250, max: 6)]),
    MealCounterFood('Fish roll', [PortionUnit(_piece, 220, max: 6)]),
    MealCounterFood('Vegetable roll', [PortionUnit(_piece, 200, max: 6)]),
    MealCounterFood('Chicken roll', [PortionUnit(_piece, 230, max: 6)]),
    MealCounterFood('Patties', [PortionUnit(_piece, 230, max: 6)]),
    MealCounterFood('Samosa', [PortionUnit(_piece, 130, max: 8)]),
    MealCounterFood('Cutlet', [PortionUnit(_piece, 120, max: 8)]),
    MealCounterFood('Pastry', [PortionUnit(_piece, 250, max: 6)]),
    MealCounterFood('Vegetable pastry', [PortionUnit(_piece, 220, max: 6)]),
    MealCounterFood('Egg bun', [PortionUnit(_piece, 240, max: 6)]),
    MealCounterFood('Chicken bun', [PortionUnit(_piece, 260, max: 6)]),
    MealCounterFood('Chinese roll', [PortionUnit(_piece, 210, max: 6)]),
    MealCounterFood('Vegetable roti', [PortionUnit(_piece, 180, max: 6)]),
  ]),
  MealCounterCategory('Bakery & Sweet Items', [
    MealCounterFood('Cake', [PortionUnit(_slice, 300, max: 6)]),
    MealCounterFood('Chocolate cake', [PortionUnit(_slice, 350, max: 6)]),
    MealCounterFood('Cream cake', [PortionUnit(_slice, 380, max: 6)]),
    MealCounterFood('Cupcake', [PortionUnit(_piece, 180, max: 6)]),
    MealCounterFood('Swiss roll', [PortionUnit(_slice, 150, max: 6)]),
    MealCounterFood('Doughnut', [PortionUnit(_piece, 250, max: 6)]),
    MealCounterFood('Muffin', [PortionUnit(_piece, 300, max: 6)]),
    MealCounterFood('Biscuits', [PortionUnit(_piece, 25, max: 20)]),
    MealCounterFood('Chocolate', [PortionUnit(_piece, 55, max: 10)]),
    MealCounterFood('Watalappam / other desserts', [PortionUnit(_serving, 250, max: 3)]),
  ]),
  MealCounterCategory('Beverages', [
    MealCounterFood('Coca-Cola', [PortionUnit(_glass, 140, max: 4)]),
    MealCounterFood('Pepsi', [PortionUnit(_glass, 140, max: 4)]),
    MealCounterFood('Sprite', [PortionUnit(_glass, 130, max: 4)]),
    MealCounterFood('Fanta', [PortionUnit(_glass, 140, max: 4)]),
    MealCounterFood('Cream soda', [PortionUnit(_glass, 130, max: 4)]),
    MealCounterFood('Ginger beer', [PortionUnit(_glass, 120, max: 4)]),
    MealCounterFood('Fruit juice', [PortionUnit(_glass, 120, max: 4)]),
    MealCounterFood('Fresh fruit juice', [PortionUnit(_glass, 90, max: 4)]),
    MealCounterFood('Milkshake', [PortionUnit(_glass, 250, max: 3)]),
    MealCounterFood('Iced coffee', [PortionUnit(_glass, 180, max: 3)]),
    MealCounterFood('Coffee', [PortionUnit(_glass, 5, max: 4)]),
    MealCounterFood('Plain tea', [PortionUnit(_glass, 5, max: 4)]),
    MealCounterFood('Milk tea', [PortionUnit(_glass, 90, max: 4)]),
    MealCounterFood('Tea with sugar', [PortionUnit(_glass, 60, max: 4)]),
    MealCounterFood('Milo / malted drinks', [PortionUnit(_glass, 180, max: 3)]),
    MealCounterFood('Drinking yoghurt', [PortionUnit(_glass, 150, max: 3)]),
    MealCounterFood('Flavoured milk', [PortionUnit(_glass, 180, max: 3)]),
  ]),
  MealCounterCategory('Fruits', [
    MealCounterFood('Banana', [PortionUnit(_piece, 105, max: 6)]),
    MealCounterFood('Papaya', [PortionUnit(_cup, 55, max: 4, step: 0.5), PortionUnit(_serving, 120, max: 3)]),
    MealCounterFood('Pineapple', [PortionUnit(_slice, 50, max: 8), PortionUnit(_cup, 80, max: 4, step: 0.5)]),
    MealCounterFood('Watermelon', [PortionUnit(_slice, 46, max: 8), PortionUnit(_cup, 46, max: 4, step: 0.5)]),
    MealCounterFood('Mango', [PortionUnit(_piece, 135, max: 4)]),
    MealCounterFood('Guava', [PortionUnit(_piece, 68, max: 4)]),
    MealCounterFood('Orange', [PortionUnit(_piece, 62, max: 4)]),
    MealCounterFood('Apple', [PortionUnit(_piece, 95, max: 4)]),
    MealCounterFood('Rambutan', [PortionUnit(_piece, 15, max: 15)]),
    MealCounterFood('Avocado', [PortionUnit(_piece, 160, max: 3)]),
  ]),
];
