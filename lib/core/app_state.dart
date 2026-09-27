import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models.dart';

SupabaseClient get db => Supabase.instance.client;
String? get uid => db.auth.currentUser?.id;

/// Global session + profile state.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  Profile? profile;
  int unreadCount = 0;
  StreamSubscription<AuthState>? _sub;

  bool get signedIn => db.auth.currentSession != null;

  Future<void> init() async {
    _sub?.cancel();
    _sub = db.auth.onAuthStateChange.listen((event) async {
      if (event.event == AuthChangeEvent.signedOut) {
        profile = null;
        unreadCount = 0;
        notifyListeners();
      } else if (event.session != null && (event.event == AuthChangeEvent.signedIn || event.event == AuthChangeEvent.initialSession)) {
        await loadProfile();
      }
    });
    if (signedIn) await loadProfile();
  }

  Future<Profile?> loadProfile() async {
    final id = uid;
    if (id == null) return null;
    try {
      var row = await db.from('profiles').select().eq('id', id).maybeSingle();
      if (row == null) {
        // Trigger normally creates it; fall back for safety.
        final u = db.auth.currentUser!;
        row = await db.from('profiles').upsert({'id': id, 'email': u.email, 'full_name': u.userMetadata?['full_name']}).select().single();
      }
      profile = Profile(row);
      await refreshUnread();
      notifyListeners();
    } catch (e) {
      debugPrint('loadProfile failed: $e');
    }
    return profile;
  }

  Future<void> updateProfile(Map<String, dynamic> values) async {
    final id = uid;
    if (id == null) return;
    final row = await db.from('profiles').update(values).eq('id', id).select().single();
    profile = Profile(row);
    notifyListeners();
  }

  Future<void> refreshUnread() async {
    final id = uid;
    if (id == null) return;
    try {
      final rows = await db
          .from('notifications')
          .select('id')
          .eq('user_id', id)
          .isFilter('read_at', null)
          .lte('scheduled_for', DateTime.now().toUtc().toIso8601String());
      unreadCount = (rows as List).length;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> signOut() async {
    await db.auth.signOut();
  }
}
