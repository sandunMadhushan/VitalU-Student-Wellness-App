import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// BMI band the plan is written for.
enum BmiBand { underweight, normal, overweight, obese }

BmiBand bmiBand(double bmi) => bmi < 18.5
    ? BmiBand.underweight
    : bmi < 25
        ? BmiBand.normal
        : bmi < 30
            ? BmiBand.overweight
            : BmiBand.obese;

class PlanTip {
  const PlanTip(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;
}

class PlanSection {
  const PlanSection(this.icon, this.title, this.tips, {this.color});
  final IconData icon;
  final String title;
  final List<PlanTip> tips;
  final Color Function()? color;
}

class BmiPlan {
  const BmiPlan({required this.illustration, required this.headline, required this.intro, required this.sections, required this.goals, required this.meaningTitle, required this.meaning});
  final String illustration;
  final String headline;
  final String intro;
  final List<PlanSection> sections;

  /// Small, ticked-off goals for this week.
  final List<(IconData, String)> goals;
  final String meaningTitle;
  final List<String> meaning;
}

BmiPlan bmiPlanFor(BmiBand band) => switch (band) {
      BmiBand.obese => const BmiPlan(
          illustration: 'walking_outside',
          headline: "Let's start with small, steady steps",
          intro: 'You do not need a strict diet. A few swaps you can keep up, more water and a daily walk add up to real change over a semester.',
          sections: [
            PlanSection(Symbols.no_food_rounded, 'Ease off salty, oily and sugary foods', [
              PlanTip(Symbols.egg_alt_rounded, 'Go easy on salt', 'Cut back on instant noodle seasoning, papadam, salted dried fish and extra soy sauce. Taste before you add salt.'),
              PlanTip(Symbols.skillet_rounded, 'Fewer deep-fried foods', 'Limit rolls, patties, vadai and fried kottu to once or twice a week. Choose string hoppers, pittu or red rice with curries instead.'),
              PlanTip(Symbols.local_cafe_rounded, 'Cut the sugar', 'Swap soft drinks and sweet milk tea for plain tea, water or king coconut. Keep sweets like kavum and cake for special days.'),
            ]),
            PlanSection(Symbols.water_drop_rounded, 'Drink more water', [
              PlanTip(Symbols.local_drink_rounded, 'A glass before each meal', 'It helps you feel full sooner and replaces sugary drinks naturally.'),
              PlanTip(Symbols.water_bottle_large_rounded, 'Refill a bottle 3 to 4 times', 'Keep a 500 ml bottle in your bag and refill it between lectures.'),
            ]),
            PlanSection(Symbols.directions_walk_rounded, 'Move a little more every day', [
              PlanTip(Symbols.timer_rounded, 'Walk 30 minutes a day', 'Split it into three 10-minute walks if that is easier: to the canteen, the library and back to your hostel.'),
              PlanTip(Symbols.fitness_center_rounded, 'Beginner moves, 10 minutes', 'Try wall push-ups, chair squats, marching on the spot and gentle stair climbs. Rest whenever you need to.'),
              PlanTip(Symbols.stairs_rounded, 'Choose the stairs', 'Taking the stairs instead of the lift is easy daily movement that adds up.'),
            ]),
          ],
          goals: [
            (Symbols.directions_walk_rounded, 'Walk 30 minutes every day'),
            (Symbols.local_drink_rounded, 'Swap one sugary drink for water daily'),
            (Symbols.skillet_rounded, 'Deep-fried food no more than twice'),
            (Symbols.bedtime_rounded, 'Sleep 7 to 8 hours most nights'),
          ],
          meaningTitle: 'Your BMI is in the obesity range',
          meaning: [
            'A BMI of 30 or above means carrying more weight than is healthy for your height. Over time this can raise the risk of non-communicable diseases (NCDs) such as heart disease, high blood pressure, type 2 diabetes and joint pain.',
            'The encouraging part: losing even 5 to 10% of your body weight can lower these risks in a meaningful way. You do not need to get there quickly. Slow, steady changes are the ones that last.',
            'You are not alone in this, and a campus doctor or dietitian can help you make a plan that fits your lectures and canteen options.',
          ],
        ),
      BmiBand.overweight => const BmiPlan(
          illustration: 'healthy_options',
          headline: 'A few smart swaps go a long way',
          intro: 'You are close to the healthy range. Small changes to what is on your plate, how much you serve and how often you move can bring you there.',
          sections: [
            PlanSection(Symbols.restaurant_rounded, 'Healthier food choices', [
              PlanTip(Symbols.rice_bowl_rounded, 'Smarter carbs', 'Choose red rice, string hoppers or pittu over a big heap of white rice or fried rice.'),
              PlanTip(Symbols.set_meal_rounded, 'Grilled or curried, not fried', 'Pick fish curry, grilled chicken or dhal over fried chicken and devilled dishes.'),
              PlanTip(Symbols.nutrition_rounded, 'Snack on fruit', 'Reach for a banana, papaya or guava instead of biscuits or a bun between classes.'),
            ]),
            PlanSection(Symbols.pie_chart_rounded, 'Portion control', [
              PlanTip(Symbols.dinner_dining_rounded, 'Use the healthy plate', 'Fill half your plate with vegetables and gotukola or mallum, a quarter with rice and a quarter with fish, egg or dhal.'),
              PlanTip(Symbols.hourglass_bottom_rounded, 'Eat slowly', 'Take about 20 minutes per meal. It takes that long for your brain to notice you are full.'),
              PlanTip(Symbols.front_hand_rounded, 'Stop at comfortably full', 'Skip the second helping and stop before you feel stuffed.'),
            ]),
            PlanSection(Symbols.sprint_rounded, 'Get active your way', [
              PlanTip(Symbols.directions_walk_rounded, 'Brisk walks', 'Walk briskly for 30 minutes on at least 5 days a week. You should be able to talk, but not sing.'),
              PlanTip(Symbols.sports_tennis_rounded, 'Join something fun', 'Badminton, netball, swimming or a dance club makes moving feel less like a chore.'),
              PlanTip(Symbols.self_improvement_rounded, 'Two strength sessions', 'Squats, lunges and push-ups twice a week help your body burn more energy, even at rest.'),
            ]),
          ],
          goals: [
            (Symbols.dinner_dining_rounded, 'Build a healthy plate at lunch'),
            (Symbols.directions_walk_rounded, 'Brisk walk on 5 days'),
            (Symbols.nutrition_rounded, 'Fruit instead of a sweet snack'),
            (Symbols.water_drop_rounded, 'Water with every meal'),
          ],
          meaningTitle: 'Your BMI is in the overweight range',
          meaning: [
            'A BMI between 25 and 29.9 means your weight is a little above the healthy range for your height. Over the years this may raise the risk of non-communicable diseases (NCDs) such as cardiovascular disease and type 2 diabetes.',
            'South Asian adults tend to develop these conditions at lower BMI levels than some other groups, which is why it is worth acting early, while it is easier.',
            'You are in a great position to turn this around. Moving towards a healthy BMI through steady, enjoyable changes protects your health for decades to come.',
          ],
        ),
      BmiBand.normal => const BmiPlan(
          illustration: 'winners',
          headline: 'Great news: you are in the healthy range',
          intro: 'Your habits are working. The goal now is to keep this balance through busy semesters and exam weeks.',
          sections: [
            PlanSection(Symbols.restaurant_rounded, 'Balanced nutrition', [
              PlanTip(Symbols.palette_rounded, 'Eat the rainbow', 'Aim for 5 or more food groups a day: grains, pulses, vegetables, fruit, and fish, egg or meat.'),
              PlanTip(Symbols.bakery_dining_rounded, 'Keep breakfast', 'A regular breakfast keeps your energy steady and stops mid-morning snacking.'),
            ]),
            PlanSection(Symbols.directions_run_rounded, 'Regular physical activity', [
              PlanTip(Symbols.timer_rounded, '150 minutes a week', 'Around 30 minutes, 5 days a week, of walking, cycling or sport keeps your heart strong.'),
              PlanTip(Symbols.fitness_center_rounded, 'Add strength twice a week', 'Bodyweight moves like squats and push-ups keep your muscles and bones healthy.'),
            ]),
            PlanSection(Symbols.bedtime_rounded, 'Rest and recharge', [
              PlanTip(Symbols.nights_stay_rounded, 'Sleep 7 to 9 hours', 'A steady bedtime, even around exams, helps your appetite and mood stay balanced.'),
              PlanTip(Symbols.spa_rounded, 'Manage stress', 'Stress can change eating patterns. Short breaks and a breathing exercise help.'),
            ]),
            PlanSection(Symbols.favorite_rounded, 'Other healthy habits', [
              PlanTip(Symbols.water_drop_rounded, 'Stay hydrated', 'Water first, sugary drinks rarely.'),
              PlanTip(Symbols.event_repeat_rounded, 'Check in each semester', 'Recheck your BMI and waist measurement now and then to stay on track.'),
            ]),
          ],
          goals: [
            (Symbols.palette_rounded, 'Eat from 5 food groups today'),
            (Symbols.directions_run_rounded, 'Move for 30 minutes on 5 days'),
            (Symbols.bedtime_rounded, 'Keep a steady bedtime'),
            (Symbols.water_drop_rounded, 'Reach your water goal'),
          ],
          meaningTitle: 'Your BMI is in the healthy range',
          meaning: [
            'A BMI between 18.5 and 24.9 is linked with the lowest risk of weight-related non-communicable diseases (NCDs) such as heart disease and type 2 diabetes.',
            'For South Asian adults, health risks can start to rise from a BMI of about 23, so if you are near the upper end, keeping up these habits matters even more.',
            'Well done for looking after yourself. Keep enjoying good food, movement and rest.',
          ],
        ),
      BmiBand.underweight => const BmiPlan(
          illustration: 'eating_pasta',
          headline: 'Nourish your body, one meal at a time',
          intro: 'The aim is to gain weight gently and healthily, through foods packed with energy and nutrients, not junk food.',
          sections: [
            PlanSection(Symbols.egg_rounded, 'Nutrient-rich foods to add', [
              PlanTip(Symbols.egg_rounded, 'Protein at every meal', 'Eggs, dhal, chickpeas (kadala), fish and chicken help build muscle, not just fat.'),
              PlanTip(Symbols.water_full_rounded, 'Milk, curd and yoghurt', 'A glass of milk or a bowl of curd adds energy, protein and calcium for strong bones.'),
              PlanTip(Symbols.nest_eco_leaf_rounded, 'Healthy fats', 'Peanuts, cashews, avocado and a spoon of peanut butter add energy in small, easy portions.'),
              PlanTip(Symbols.nutrition_rounded, 'Energy-rich fruit', 'Bananas, mangoes and dates make quick, filling snacks.'),
            ]),
            PlanSection(Symbols.schedule_rounded, 'Eat more often', [
              PlanTip(Symbols.restaurant_rounded, '3 meals and 2 to 3 snacks', 'Smaller, frequent meals are easier than forcing big plates.'),
              PlanTip(Symbols.blender_rounded, 'Snack ideas', 'Try a banana milkshake, peanut butter on bread, boiled kadala or an egg sandwich between classes.'),
              PlanTip(Symbols.local_drink_rounded, 'Drink after, not before', 'Have drinks after meals so they do not fill you up first.'),
            ]),
            PlanSection(Symbols.fitness_center_rounded, 'Healthy habits', [
              PlanTip(Symbols.fitness_center_rounded, 'Strength training', 'Squats, push-ups and resistance exercises 2 to 3 times a week turn extra food into muscle.'),
              PlanTip(Symbols.bakery_dining_rounded, 'Never skip breakfast', 'Breakfast is the easiest meal to lose on busy mornings. Keep something ready to grab.'),
              PlanTip(Symbols.bedtime_rounded, 'Rest well', 'Good sleep helps your body recover and build.'),
            ]),
          ],
          goals: [
            (Symbols.egg_rounded, 'Protein with every meal'),
            (Symbols.blender_rounded, 'Two healthy snacks a day'),
            (Symbols.bakery_dining_rounded, 'Breakfast every morning'),
            (Symbols.fitness_center_rounded, 'Two strength sessions'),
          ],
          meaningTitle: 'Your BMI is in the underweight range',
          meaning: [
            'A BMI below 18.5 can mean your body is not getting all the energy and nutrients it needs. Over time this may lead to tiredness, lower immunity, anaemia, weaker bones and, for women, irregular periods.',
            'Gaining weight slowly with nourishing foods and strength exercise helps your body build strength rather than just fat.',
            'If you have lost weight without trying, have a poor appetite or feel unwell, please talk to a campus doctor. There may be a simple reason that is easy to treat.',
          ],
        ),
    };

/// Friendly header for the plan: an illustration and a short message.
class PlanHero extends StatelessWidget {
  const PlanHero({super.key, required this.plan, required this.color});
  final BmiPlan plan;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Rad.xl),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
          Color.alphaBlend(color.withValues(alpha: dark ? 0.28 : 0.16), AppColors.surfaceContainerLowest),
          Color.alphaBlend(color.withValues(alpha: dark ? 0.10 : 0.04), AppColors.surfaceContainerLowest),
        ]),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your personal plan', style: T.labelSm.c(color).w(FontWeight.w800).tracking(0.3)),
        const SizedBox(height: 4),
        Text(plan.headline, style: T.headlineMd),
        const SizedBox(height: 6),
        Text(plan.intro, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: 10),
        Center(child: SizedBox(height: 130, child: SvgPicture.asset('assets/illustrations/${plan.illustration}.svg', fit: BoxFit.contain, alignment: Alignment.bottomCenter))),
      ]),
    );
  }
}

/// One themed group of tips with a coloured header.
class PlanSectionCard extends StatelessWidget {
  const PlanSectionCard({super.key, required this.section, required this.color, required this.index});
  final PlanSection section;
  final Color color;
  final int index;

  @override
  Widget build(BuildContext context) {
    return VCard(
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          color: AppColors.tint(color),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text('${index + 1}', style: T.labelMd.c(AppColors.isDark ? AppColors.surface : Colors.white).w(FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(section.title, style: T.headlineSm)),
            Icon(section.icon, color: color, fill: 1, size: 22),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Column(children: [
            for (final t in section.tips)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  IconCircle(t.icon, size: 38, iconSize: 20, fg: color, radius: 12, fill: 1),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.title, style: T.labelLg),
                      const SizedBox(height: 2),
                      Text(t.text, style: T.bodySm.c(AppColors.onSurfaceVariant)),
                    ]),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// This week's mini goals. Ticks are kept on the device for the current
/// week, so a student can come back and check things off.
class WeeklyGoals extends StatefulWidget {
  const WeeklyGoals({super.key, required this.band, required this.goals, required this.color});
  final BmiBand band;
  final List<(IconData, String)> goals;
  final Color color;
  @override
  State<WeeklyGoals> createState() => _WeeklyGoalsState();
}

class _WeeklyGoalsState extends State<WeeklyGoals> {
  Set<int> _done = {};
  String get _key => 'bmi_goals_${widget.band.name}_${isoDate(weekStart(DateTime.now()))}';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final saved = p.getStringList(_key) ?? const [];
      if (mounted) setState(() => _done = saved.map(int.parse).toSet());
    }).catchError((_) {});
  }

  Future<void> _toggle(int i) async {
    setState(() => _done.contains(i) ? _done.remove(i) : _done.add(i));
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_key, [for (final d in _done) '$d']);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final n = _done.length, total = widget.goals.length;
    return VCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Symbols.flag_rounded, size: 20, color: c, fill: 1),
          const SizedBox(width: 8),
          Expanded(child: Text("This week's mini goals", style: T.headlineSm)),
          Text('$n of $total', style: T.labelMd.c(AppColors.onSurfaceVariant)),
        ]),
        const SizedBox(height: 4),
        Text(n == total ? 'All done this week. Brilliant!' : 'Tap a goal when you have done it.', style: T.bodySm.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: Sp.sm),
        Bar(value: total == 0 ? 0 : n / total, color: c),
        const SizedBox(height: Sp.sm),
        for (int i = 0; i < total; i++)
          InkWell(
            borderRadius: BorderRadius.circular(Rad.base),
            onTap: () => _toggle(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: _done.contains(i) ? c : Colors.transparent, border: Border.all(color: _done.contains(i) ? c : AppColors.outline, width: 2)),
                  child: _done.contains(i) ? Icon(Symbols.check_rounded, size: 16, color: AppColors.isDark ? AppColors.surface : Colors.white, weight: 700) : null,
                ),
                const SizedBox(width: 12),
                Icon(widget.goals[i].$1, size: 20, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.goals[i].$2,
                      style: T.bodyMd.c(_done.contains(i) ? AppColors.onSurfaceVariant : AppColors.onSurface).copyWith(decoration: _done.contains(i) ? TextDecoration.lineThrough : null)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// Closing explanation of what the category means for health, written to
/// support rather than alarm.
class BmiMeaningCard extends StatelessWidget {
  const BmiMeaningCard({super.key, required this.plan, required this.color, required this.bmi});
  final BmiPlan plan;
  final Color color;
  final double bmi;

  @override
  Widget build(BuildContext context) {
    return VCard(
      border: Border.all(color: color.withValues(alpha: 0.35)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconCircle(Symbols.info_rounded, size: 36, iconSize: 20, fg: color, fill: 1),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('What your BMI of ${bmi.toStringAsFixed(1)} means', style: T.labelSm.c(color).w(FontWeight.w800)),
              Text(plan.meaningTitle, style: T.headlineSm),
            ]),
          ),
        ]),
        const SizedBox(height: Sp.md),
        for (final p in plan.meaning) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(p, style: T.bodyMd.c(AppColors.onSurfaceVariant))),
        Text('BMI is a screening measure, not a diagnosis. It does not account for muscle, bone or where fat is stored.', style: T.bodySm.c(AppColors.outline)),
      ]),
    );
  }
}
