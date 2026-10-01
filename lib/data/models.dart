import 'dart:math' as math;

double? _d(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));
int? _i(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse(v.toString()));
List<String> _sl(dynamic v) => v == null ? <String>[] : List<String>.from((v as List).map((e) => e.toString()));

class Profile {
  Profile(this.raw);
  final Map<String, dynamic> raw;

  String get id => raw['id'] as String;
  String get fullName => (raw['full_name'] as String?)?.trim().isNotEmpty == true ? raw['full_name'] as String : 'Student';
  String get firstName => fullName.split(' ').first;
  String? get email => raw['email'] as String?;
  String? get avatarUrl => raw['avatar_url'] as String?;
  DateTime? get dob => raw['date_of_birth'] == null ? null : DateTime.tryParse(raw['date_of_birth']);
  int? get age {
    final d = dob;
    if (d == null) return null;
    final now = DateTime.now();
    var a = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) a--;
    return a;
  }

  String? get sex => raw['sex'] as String?;
  bool get isFemale => sex == 'female';
  String? get faculty => raw['faculty'] as String?;
  String? get academicYear => raw['academic_year'] as String?;
  String? get registrationNumber => raw['registration_number'] as String?;
  String? get nameWithInitials => raw['name_with_initials'] as String?;
  String? get username => raw['username'] as String?;

  /// Name shown on the profile card: the official initials form once set,
  /// otherwise the plain full name.
  String get displayName => (nameWithInitials?.trim().isNotEmpty ?? false) ? nameWithInitials! : fullName;

  /// Registration step 1 is mandatory: every field must be filled.
  bool get basicsComplete =>
      dob != null &&
      sex != null &&
      faculty != null &&
      academicYear != null &&
      (registrationNumber?.trim().isNotEmpty ?? false) &&
      (nameWithInitials?.trim().isNotEmpty ?? false) &&
      (username?.trim().isNotEmpty ?? false);

  /// Where a signed-in student should land: step 1 until it is complete, then
  /// the next unfinished registration step, then home.
  String get landingRoute {
    if (!basicsComplete) return '/register/1';
    if (onboardingCompleted) return '/home';
    return '/register/${(registrationStep + 1).clamp(2, 3)}';
  }
  double? get heightCm => _d(raw['height_cm']);
  double? get weightKg => _d(raw['weight_kg']);
  double? get waistCm => _d(raw['waist_cm']);
  double? get hipCm => _d(raw['hip_cm']);
  List<String> get conditions => _sl(raw['health_conditions']);
  List<String> get customConditions => _sl(raw['custom_conditions']);
  List<String> get allergies => _sl(raw['allergies']);
  List<Map<String, dynamic>> get medications => List<Map<String, dynamic>>.from((raw['medications'] ?? []) as List);
  List<Map<String, dynamic>> get familyHistory => List<Map<String, dynamic>>.from((raw['family_history'] ?? []) as List);
  String? get immunizations => raw['immunizations'] as String?;
  String get activityLevel => (raw['activity_level'] as String?) ?? 'Moderate Walking (Campus)';
  int get waterGoalMl => _i(raw['water_goal_ml']) ?? 2500;
  double get sleepGoalHours => _d(raw['sleep_goal_hours']) ?? 8;
  int get stepGoal => _i(raw['step_goal']) ?? 8000;
  int get calorieTarget => _i(raw['calorie_target']) ?? 2100;
  double get weeklyBudget => _d(raw['weekly_food_budget']) ?? 1500;
  bool get waterNudge => raw['water_nudge_enabled'] as bool? ?? true;
  bool get onboardingCompleted => raw['onboarding_completed'] as bool? ?? false;
  bool get researchConsent => raw['research_consent'] as bool? ?? false;
  int get registrationStep => _i(raw['registration_step']) ?? 0;
  DateTime? get measuredAt => raw['measured_at'] == null ? null : DateTime.tryParse(raw['measured_at']);
  String? get quietStart => raw['quiet_hours_start'] as String?;
  String? get quietEnd => raw['quiet_hours_end'] as String?;

  double? get bmi => Calc.bmi(heightCm, weightKg);
  double? get whr => Calc.whr(waistCm, hipCm);
}

class Calc {
  Calc._();
  static double? bmi(double? h, double? w) {
    if (h == null || w == null || h <= 0) return null;
    final m = h / 100;
    return w / (m * m);
  }

  static double? whr(double? waist, double? hip) {
    if (waist == null || hip == null || hip <= 0) return null;
    return waist / hip;
  }

  /// WHO adult BMI categories.
  static String bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal Weight';
    if (bmi < 30) return 'Overweight';
    return 'Obesity';
  }

  /// WHR thresholds (low / moderate / high). WHO flags substantially increased
  /// metabolic risk at ≥0.85 (female) and ≥0.90 (male).
  static (double, double) whrThresholds(String sex) => sex == 'male' ? (0.90, 1.00) : (0.80, 0.85);

  static (String, String) whrCategory(double whr, String sex) {
    final (low, high) = whrThresholds(sex);
    if (whr < low) return ('Low Risk', 'Healthy range');
    if (whr <= high) return ('Moderate Risk', 'Keep an eye on it');
    return ('High Risk', 'Worth a check-up');
  }

  /// Weight range (kg) that keeps a person of [heightCm] inside the normal
  /// BMI band (18.5–24.9), for setting a gain/loss target.
  static (double, double) normalWeightRangeFor(double heightCm) {
    final m2 = (heightCm / 100) * (heightCm / 100);
    return (18.5 * m2, 24.9 * m2);
  }

  /// Suggested daily water target (ml) ≈ 35 ml/kg, clamped to a sensible student range.
  static int waterTargetFor(double? weightKg) {
    if (weightKg == null) return 2500;
    final ml = ((weightKg * 35) / 100).round() * 100;
    return math.max(1800, math.min(ml, 4000));
  }

  /// Extra water (ml) worth suggesting on hot days, on top of the base target.
  static int heatAdjustmentMl(double? tempC) {
    if (tempC == null) return 0;
    if (tempC >= 34) return 750;
    if (tempC >= 32) return 500;
    if (tempC >= 30) return 300;
    return 0;
  }
}

class Fmt {
  Fmt._();
  static String litres(num ml) => (ml / 1000).toStringAsFixed(1);
  static String hm(int minutes) => '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
  static String thousands(num n) {
    final s = n.round().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  static String k(num n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : n.round().toString();
}
