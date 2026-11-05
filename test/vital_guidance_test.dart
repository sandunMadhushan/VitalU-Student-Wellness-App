import 'package:flutter_test/flutter_test.dart';
import 'package:vitalu/data/vital_guidance.dart';

void main() {
  group('Blood pressure guidance', () {
    test('normal needs no action beyond a yearly check', () {
      expect(VitalGuidance.bp(110, 70).urgency, VitalUrgency.none);
    });

    test('elevated and stage 1 are routine', () {
      expect(VitalGuidance.bp(125, 75).urgency, VitalUrgency.routine);
      expect(VitalGuidance.bp(135, 78).urgency, VitalUrgency.routine);
      expect(VitalGuidance.bp(118, 82).urgency, VitalUrgency.routine);
    });

    test('stage 2 should be seen soon', () {
      expect(VitalGuidance.bp(145, 85).urgency, VitalUrgency.soon);
      expect(VitalGuidance.bp(128, 92).urgency, VitalUrgency.soon);
    });

    test('180/120 is urgent and points to 1990', () {
      for (final r in [(180, 100), (170, 120), (200, 130)]) {
        final a = VitalGuidance.bp(r.$1, r.$2);
        expect(a.urgent, isTrue, reason: '${r.$1}/${r.$2}');
        expect(a.action, contains('1990'));
      }
    });

    test('low readings are only flagged when nothing is high', () {
      expect(VitalGuidance.bp(85, 55).title, contains('low'));
      // Isolated systolic hypertension with a low diastolic is not "low".
      expect(VitalGuidance.bp(150, 55).urgency, VitalUrgency.soon);
    });
  });

  group('Glucose guidance', () {
    test('bands and thresholds', () {
      expect(VitalGuidance.glucose(90).urgency, VitalUrgency.none);
      expect(VitalGuidance.glucose(100).urgency, VitalUrgency.routine);
      expect(VitalGuidance.glucose(125).urgency, VitalUrgency.routine);
      expect(VitalGuidance.glucose(126).urgency, VitalUrgency.soon);
      expect(VitalGuidance.glucose(65).urgency, VitalUrgency.soon);
      expect(VitalGuidance.glucose(50).urgent, isTrue);
      expect(VitalGuidance.glucose(300).urgent, isTrue);
    });

    test('a single high reading is never called a diagnosis', () {
      expect(VitalGuidance.glucose(130).why, contains('not a diagnosis'));
    });
  });

  group('Triglyceride guidance', () {
    test('bands and thresholds', () {
      expect(VitalGuidance.triglycerides(149).urgency, VitalUrgency.none);
      expect(VitalGuidance.triglycerides(150).urgency, VitalUrgency.routine);
      expect(VitalGuidance.triglycerides(200).urgency, VitalUrgency.soon);
      expect(VitalGuidance.triglycerides(500).urgency, VitalUrgency.soon);
    });
  });
}
