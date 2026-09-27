/// Supabase project "VitalU" (ap-southeast-1).
///
/// The publishable key is safe to ship in the client; all data is protected by
/// row-level security policies in the database.
class Env {
  Env._();
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://cfpuykmzxamkpjeqdemx.supabase.co');
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY', defaultValue: 'sb_publishable_ys85MJS1JSW_GyPNHJfF-A_Kx0hPJIi');

  /// Currency label used by the budget planner.
  static const currency = 'Rs.';
}
