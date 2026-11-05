/// What to do next after a blood pressure, fasting glucose or triglyceride
/// reading. Pure Dart so it can be unit-tested.
///
/// These are educational next steps, not a diagnosis: a single reading never
/// confirms a condition, and the wording says so. Bands follow [VitalBands]
/// (adult ranges, ACC/AHA blood pressure categories, ADA glucose categories).
library;

/// How soon a reading needs attention. Ordered from least to most pressing.
enum VitalUrgency { none, routine, soon, urgent }

class VitalAdvice {
  const VitalAdvice({required this.title, required this.urgency, required this.action, this.why});

  /// Short heading, for example "Blood pressure: stage 2 range".
  final String title;
  final VitalUrgency urgency;

  /// The one thing to do next, in plain language.
  final String action;

  /// Optional extra context or lifestyle tip.
  final String? why;

  bool get urgent => urgency == VitalUrgency.urgent;
}

class VitalGuidance {
  VitalGuidance._();

  static const _notDiagnosis = 'One reading is not a diagnosis.';

  /// Blood pressure in mmHg.
  static VitalAdvice bp(num sys, num dia) {
    if (sys >= 180 || dia >= 120) {
      return const VitalAdvice(
        title: 'Blood pressure: very high',
        urgency: VitalUrgency.urgent,
        action: 'Sit and rest for 5 minutes, then measure again. If it is still this high, or you have chest pain, '
            'shortness of breath, a severe headache, weakness, confusion or trouble speaking, call 1990 now. '
            'Otherwise see a doctor today.',
      );
    }
    if (sys >= 140 || dia >= 90) {
      return const VitalAdvice(
        title: 'Blood pressure: stage 2 range',
        urgency: VitalUrgency.soon,
        action: 'Measure again after 5 minutes of rest. If it is still in this range, see a doctor within a week. '
            'Take your reading and, if you can, a few readings from different days.',
        why: 'Cutting salt and fried or packaged food, being active and sleeping well all help. $_notDiagnosis',
      );
    }
    if (sys >= 130 || dia >= 80) {
      return const VitalAdvice(
        title: 'Blood pressure: stage 1 range',
        urgency: VitalUrgency.routine,
        action: 'Check again on two or three different days this week, seated and rested. '
            'If it stays at this level, book a visit with the campus medical centre.',
        why: 'Less salt, more fruit and vegetables and 150 minutes of activity a week lower blood pressure. $_notDiagnosis',
      );
    }
    if (sys >= 120) {
      return const VitalAdvice(
        title: 'Blood pressure: elevated',
        urgency: VitalUrgency.routine,
        action: 'Keep going with healthy habits and check again in 3 to 6 months.',
        why: 'Going easy on salt and staying active keeps it from rising.',
      );
    }
    if (sys < 90 || dia < 60) {
      return const VitalAdvice(
        title: 'Blood pressure: low',
        urgency: VitalUrgency.routine,
        action: 'If you feel dizzy or faint, sit or lie down, drink some water and tell someone. '
            'If this happens often, see a doctor.',
        why: 'Some people naturally run low and feel fine. $_notDiagnosis',
      );
    }
    return const VitalAdvice(
      title: 'Blood pressure: normal',
      urgency: VitalUrgency.none,
      action: 'Great. Check again at least once a year.',
    );
  }

  /// Fasting blood glucose in mg/dL.
  static VitalAdvice glucose(num v) {
    if (v >= 300) {
      return const VitalAdvice(
        title: 'Fasting glucose: very high',
        urgency: VitalUrgency.urgent,
        action: 'See a doctor today. If you are very thirsty, vomiting, breathing fast or feel confused, '
            'call 1990 or go to the nearest hospital.',
      );
    }
    if (v < 54) {
      return const VitalAdvice(
        title: 'Fasting glucose: very low',
        urgency: VitalUrgency.urgent,
        action: 'If you feel shaky, sweaty or confused, eat or drink something sugary now (juice, a few sweets) '
            'and get help. If it keeps happening, see a doctor the same day.',
      );
    }
    if (v < 70) {
      return const VitalAdvice(
        title: 'Fasting glucose: low',
        urgency: VitalUrgency.soon,
        action: 'Eat something now if you feel shaky or sweaty. If you get low readings repeatedly, see a doctor.',
        why: _notDiagnosis,
      );
    }
    if (v >= 126) {
      return const VitalAdvice(
        title: 'Fasting glucose: in the diabetes range',
        urgency: VitalUrgency.soon,
        action: 'See a doctor within a week to confirm with a repeat fasting test or an HbA1c.',
        why: 'Diabetes is only diagnosed with a repeat test. $_notDiagnosis',
      );
    }
    if (v >= 100) {
      return const VitalAdvice(
        title: 'Fasting glucose: in the prediabetes range',
        urgency: VitalUrgency.routine,
        action: 'Repeat a fasting test or HbA1c with a doctor in the next month or two.',
        why: 'Fewer sugary drinks and sweets, less white rice and refined flour, and daily movement can bring this back down. $_notDiagnosis',
      );
    }
    return const VitalAdvice(
      title: 'Fasting glucose: normal',
      urgency: VitalUrgency.none,
      action: 'Great. Re-check every year or two, sooner if you have a family history of diabetes.',
    );
  }

  /// Triglycerides in mg/dL.
  static VitalAdvice triglycerides(num v) {
    if (v >= 500) {
      return const VitalAdvice(
        title: 'Triglycerides: very high',
        urgency: VitalUrgency.soon,
        action: 'See a doctor within a few days. If you have severe stomach pain, get medical help straight away.',
        why: 'Very high triglycerides can inflame the pancreas.',
      );
    }
    if (v >= 200) {
      return const VitalAdvice(
        title: 'Triglycerides: high',
        urgency: VitalUrgency.soon,
        action: 'Book a visit to go over your full lipid profile.',
        why: 'Sugary drinks, sweets, fried food, refined starch and alcohol raise triglycerides; cutting them back and being active lowers them.',
      );
    }
    if (v >= 150) {
      return const VitalAdvice(
        title: 'Triglycerides: borderline high',
        urgency: VitalUrgency.routine,
        action: 'Cut back on sugary drinks and fried food, move more, and repeat the test in 3 months.',
        why: _notDiagnosis,
      );
    }
    return const VitalAdvice(
      title: 'Triglycerides: normal',
      urgency: VitalUrgency.none,
      action: 'Great. Re-check every few years, or as your doctor advises.',
    );
  }
}
