import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _soundPrefKey = 'sound_effects';

/// Short sound effects (water pour, badge fanfare) and the looping calm
/// music used by the Anxiety tracker and the cycle tracker's self-care tips.
///
/// Effects respect the student's "Sound effects" preference; the calm music
/// only ever starts from an explicit tap, so it is not gated by it.
///
/// Audio: "Water Glass Pour", "Quick Win Success Fanfare" and "Peaceful Spa
/// Bells" by BudgetPixel (budgetpixel.com), licensed CC BY 4.0.
class Sfx {
  Sfx._();

  static final enabled = ValueNotifier<bool>(true);
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_soundPrefKey) ?? true;
    } catch (_) {}
  }

  static Future<void> setEnabled(bool on) async {
    enabled.value = on;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_soundPrefKey, on);
    } catch (_) {}
  }

  static Future<void> _play(String asset, {double volume = 0.6}) async {
    await load();
    if (!enabled.value) return;
    try {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.release);
      // Mix with whatever else is playing rather than pausing it.
      await p.setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
      p.onPlayerComplete.listen((_) => p.dispose());
      await p.play(AssetSource(asset), volume: volume);
    } catch (_) {}
  }

  static Future<void> pour() => _play('sounds/water_pour.mp3', volume: 0.45);
  static Future<void> fanfare() => _play('sounds/badge_fanfare.mp3', volume: 0.6);
}

/// A single, app-wide calm music loop with a play/pause state any screen
/// can listen to.
class CalmMusic {
  CalmMusic._();

  static final playing = ValueNotifier<bool>(false);
  static AudioPlayer? _player;

  static Future<void> toggle() => playing.value ? stop() : play();

  static Future<void> play() async {
    try {
      final p = _player ??= AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(AssetSource('sounds/calm_bells.mp3'), volume: 0.7);
      playing.value = true;
    } catch (_) {
      playing.value = false;
    }
  }

  static Future<void> stop() async {
    playing.value = false;
    try {
      await _player?.stop();
    } catch (_) {}
  }
}
