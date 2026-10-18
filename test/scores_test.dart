import 'package:flutter_test/flutter_test.dart';
import 'package:vitalu/data/catalog.dart';
import 'package:vitalu/data/food_db.dart';
import 'package:vitalu/features/assessments/assessment_data.dart';
import 'package:vitalu/features/diet/diet_science.dart' show diversityByDay;
import 'package:vitalu/features/tools/activity_screen.dart' show Ipaq;
import 'package:vitalu/features/tools/psqi_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Periodic assessment', () {
    test('bundled questionnaire covers the ten areas plus clinical measurements', () async {
      final (domains, questions) = await bundledQuestionnaire();
      expect(domains.map((d) => d.id), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
      for (final d in domains) {
        expect(questions.any((q) => q.domain == d.id), isTrue, reason: 'domain ${d.id} has questions');
      }
      expect(questions.map((q) => q.id).toSet().length, questions.length, reason: 'ids are unique');
    });

    test('clinical questions are skipped without measurements', () async {
      final (_, questions) = await bundledQuestionnaire();
      final height = questions.firstWhere((q) => q.id == 'k_height');
      expect(height.visible({'k_source': 'health_centre'}), isTrue);
      expect(height.visible({'k_source': 'none'}), isFalse);
    });

    test('scores domains, BMI, WHR and PHQ-2', () async {
      final (_, questions) = await bundledQuestionnaire();
      final (scores, label) = scoreAssessment(questions, {
        'd_breakfast': '7',
        'd_sugary': '5-7',
        'e_phq1': '2',
        'e_phq2': '1',
        'k_source': 'health_centre',
        'k_height': 160,
        'k_weight': 64,
        'k_waist': 80,
        'k_hip': 100,
      });
      expect((scores['domains'] as Map)['2'], 50);
      expect(scores['bmi'], 25.0);
      expect(scores['whr'], 0.8);
      expect(scores['phq2'], 3);
      expect(scores['phq2_positive'], isTrue);
      expect(label, isNotEmpty);
    });
  });

  group('Sri Lankan dietary diversity score', () {
    test('has ten groups and a 5-group minimum', () {
      expect(foodGroups.length, 10);
      expect(minDietaryDiversity, 5);
    });

    test('every food in the database uses the current groups', () {
      for (final c in foodDatabase) {
        for (final f in c.foods) {
          for (final g in f.groups) {
            expect(foodGroups.any((x) => x.key == g), isTrue, reason: '${f.name}: $g');
          }
        }
      }
    });

    test('old MDD-W keys are mapped by food name', () {
      expect(legacyGroupKey('meat_fish', food: 'Fish curry'), 'fish');
      expect(legacyGroupKey('meat_fish', food: 'Chicken curry'), 'meat');
      expect(legacyGroupKey('grains', food: 'Potato curry'), 'starchy');
      expect(legacyGroupKey('grains', food: 'Red rice'), 'cereals');
      expect(legacyGroupKey('vita_veg_fruit', food: 'Papaya'), 'fruits');
      expect(legacyGroupKey('vita_veg_fruit', food: 'Carrot curry'), 'other_veg');
      expect(legacyGroupKey('nuts_seeds'), 'pulses');
      expect(legacyGroupKey('herbs_spices'), isNull);
    });

    test('a day counts each group once', () {
      final byDay = diversityByDay([
        {'log_date': '2026-10-18', 'food_group': 'meat_fish', 'food_name': 'Fish curry'},
        {'log_date': '2026-10-18', 'food_group': 'fish', 'food_name': 'Sprats'},
        {'log_date': '2026-10-18', 'food_group': 'cereals', 'food_name': 'Red rice'},
      ]);
      expect(byDay['2026-10-18'], {'fish', 'cereals'});
    });
  });

  group('Sleep quality score (Nurse\'s Diary, adapted from PSQI)', () {
    test('six questions of up to 20 points make 120', () {
      expect(Psqi.questions.length, 6);
      expect(Psqi.total(List.filled(6, 0)), 120);
      expect(Psqi.total(List.filled(6, 3)), 0);
    });

    test('score bands match the tool', () {
      expect(Psqi.tier(95).short, 'Excellent');
      expect(Psqi.tier(94).short, 'Good');
      expect(Psqi.tier(75).short, 'Good');
      expect(Psqi.tier(74).short, 'Poor');
      expect(Psqi.tier(50).short, 'Poor');
      expect(Psqi.tier(49).short, 'Severely deprived');
      // 15 + 15 + 10 + 15 + 15 + 10
      expect(Psqi.total([1, 1, 2, 1, 1, 2]), 80);
    });

    test('results saved on the old 0 to 21 scale are ignored', () {
      expect(Psqi.scoreOf({'score': 4, 'data': {}}), isNull);
      expect(Psqi.scoreOf({'score': 80, 'data': {'scale': 120}}), 80);
    });
  });

  group('IPAQ short form', () {
    test('7 days of any combination reaching 3000 MET-minutes is High', () {
      expect(Ipaq.category(vigDays: 2, vigMin: 90, modDays: 3, modMin: 90, walkDays: 2, walkMin: 90), 'High');
    });
    test('5 days of walking 30 minutes is Moderate', () {
      expect(Ipaq.category(vigDays: 0, vigMin: 0, modDays: 0, modMin: 0, walkDays: 5, walkMin: 30), 'Moderate');
    });
    test('little activity is Low', () {
      expect(Ipaq.category(vigDays: 0, vigMin: 0, modDays: 1, modMin: 20, walkDays: 2, walkMin: 10), 'Low');
    });
  });
}
