import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'library_screen.dart';

/// Voice pitch presets offered as "tone".
enum ReadTone {
  warm('Warm', 0.86),
  natural('Natural', 1.0),
  bright('Bright', 1.18);

  const ReadTone(this.label, this.pitch);
  final String label;
  final double pitch;
}

/// An installed voice with a readable label.
class ReadVoice {
  const ReadVoice(this.name, this.locale, this.label);
  final String name;
  final String locale;
  final String label;
  String get key => '$name|$locale';
}

/// Splits article text into short chunks of roughly a sentence each, so
/// pausing, skipping and changing speed or tone restart close to where the
/// listener was.
List<String> splitForSpeech(String text) {
  final out = <String>[];
  for (final para in text.split(RegExp(r'\n\s*\n'))) {
    var buf = '';
    for (final s in para.trim().split(RegExp(r'(?<=[.!?])\s+'))) {
      final t = s.trim();
      if (t.isEmpty) continue;
      buf = buf.isEmpty ? t : '$buf $t';
      // Very short sentences ride along with the next one to avoid choppy gaps.
      if (buf.length >= 60) {
        out.add(buf);
        buf = '';
      }
    }
    if (buf.isNotEmpty) out.add(buf);
  }
  return out;
}

/// Text-to-speech session for one article: plays chunk by chunk and applies
/// speed, tone and voice changes immediately, even mid-sentence.
class ReadAloud extends ChangeNotifier {
  static const speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  final _tts = FlutterTts();
  List<String> _chunks = const [];
  int index = 0;
  bool playing = false;
  bool open = false;
  bool finished = false;
  double speed = 1.0;
  ReadTone tone = ReadTone.natural;
  List<ReadVoice> voices = const [];
  ReadVoice? voice;

  /// Bumped whenever playback is interrupted, so a stale loop stops itself.
  int _run = 0;
  bool _ready = false;
  bool _disposed = false;

  int get total => _chunks.length;
  String get current => total == 0 ? '' : _chunks[index.clamp(0, total - 1)];
  double get progress => total == 0 ? 0 : (finished ? 1 : index / total);

  Future<void> start(String text) async {
    _chunks = splitForSpeech(text);
    if (_chunks.isEmpty) return;
    index = 0;
    finished = false;
    open = true;
    _notify();
    await _init();
    play();
  }

  void play() {
    if (total == 0) return;
    if (finished) {
      index = 0;
      finished = false;
    }
    playing = true;
    _notify();
    _loop();
  }

  Future<void> pause() async {
    _run++;
    playing = false;
    _notify();
    await _tts.stop();
  }

  void toggle() => playing ? pause() : play();

  Future<void> close() async {
    await pause();
    open = false;
    index = 0;
    finished = false;
    _notify();
  }

  void skip(int delta) {
    if (total == 0) return;
    index = (index + delta).clamp(0, total - 1);
    finished = false;
    _notify();
    if (playing) _restart();
  }

  void setSpeed(double v) {
    speed = v;
    _changed();
  }

  void cycleSpeed() => setSpeed(speeds[(speeds.indexOf(speed) + 1) % speeds.length]);

  void setTone(ReadTone t) {
    tone = t;
    _changed();
  }

  void setVoice(ReadVoice v) {
    voice = v;
    _changed();
  }

  void _changed() {
    _notify();
    _save();
    // Re-read the current sentence with the new settings.
    if (playing) _restart();
  }

  Future<void> _restart() async {
    _run++;
    await _tts.stop();
    _loop();
  }

  Future<void> _loop() async {
    final run = ++_run;
    // Let a previous stop settle; the web engine drops a speak issued mid-cancel.
    await Future.delayed(Duration(milliseconds: kIsWeb ? 220 : 60));
    if (run != _run) return;
    await _apply();
    while (run == _run) {
      await _tts.speak(_chunks[index]);
      if (run != _run) return;
      if (index + 1 >= total) break;
      index++;
      _notify();
    }
    playing = false;
    finished = true;
    _notify();
  }

  Future<void> _apply() async {
    // Android and iOS treat 0.5 as normal speed; the web uses 1.0.
    await _tts.setSpeechRate(kIsWeb ? speed : speed * 0.5);
    await _tts.setPitch(tone.pitch);
    final v = voice;
    if (v != null) await _tts.setVoice({'name': v.name, 'locale': v.locale});
  }

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    await _tts.awaitSpeakCompletion(true);
    String? savedVoice;
    try {
      final p = await SharedPreferences.getInstance();
      speed = speeds.contains(p.getDouble('tts_speed')) ? p.getDouble('tts_speed')! : 1.0;
      tone = ReadTone.values.asNameMap()[p.getString('tts_tone')] ?? ReadTone.natural;
      savedVoice = p.getString('tts_voice');
    } catch (_) {}
    unawaited(_loadVoices(savedVoice));
  }

  Future<void> _loadVoices(String? saved) async {
    try {
      var raw = await _tts.getVoices as List? ?? const [];
      // Browsers fill their voice list lazily.
      if (raw.isEmpty && kIsWeb) {
        await Future.delayed(const Duration(milliseconds: 600));
        raw = await _tts.getVoices as List? ?? const [];
      }
      voices = _englishVoices(raw);
      voice = voices.where((v) => v.key == saved).firstOrNull;
      if (voice == null && !kIsWeb) {
        final d = await _tts.getDefaultVoice;
        if (d is Map) voice = voices.where((v) => v.name == d['name']).firstOrNull;
      }
      _notify();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('tts_speed', speed);
      await p.setString('tts_tone', tone.name);
      if (voice != null) await p.setString('tts_voice', voice!.key);
    } catch (_) {}
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _run++;
    _tts.stop();
    super.dispose();
  }
}

const _regions = {
  'US': 'US',
  'GB': 'UK',
  'IN': 'Indian',
  'LK': 'Sri Lankan',
  'AU': 'Australian',
  'CA': 'Canadian',
  'IE': 'Irish',
  'NZ': 'NZ',
  'ZA': 'South African',
  'SG': 'Singapore',
};

/// Up to ten English voices, offline ones first, with friendly labels.
List<ReadVoice> _englishVoices(List raw) {
  final list = <({String name, String locale})>[];
  for (final v in raw) {
    if (v is! Map) continue;
    final name = '${v['name'] ?? ''}';
    final locale = '${v['locale'] ?? ''}'.replaceAll('_', '-');
    if (name.isEmpty || !locale.toLowerCase().startsWith('en')) continue;
    if (name.contains('network') || '${v['network_required']}' == '1') continue;
    list.add((name: name, locale: locale));
  }
  int rank(String locale) {
    final i = const ['en-us', 'en-gb', 'en-in', 'en-au'].indexOf(locale.toLowerCase());
    return i < 0 ? 9 : i;
  }

  list.sort((a, b) => rank(a.locale).compareTo(rank(b.locale)));

  final counts = <String, int>{};
  final out = <ReadVoice>[];
  for (final v in list.take(10)) {
    final region = v.locale.split('-').length > 1 ? v.locale.split('-')[1].toUpperCase() : '';
    final place = _regions[region] ?? region;
    // Desktop and iOS voices have names; Android ones are codes like en-us-x-iob-local.
    final coded = v.name.toLowerCase().startsWith(v.locale.toLowerCase()) || v.name.contains('-x-') || v.name.contains('#');
    String label;
    if (coded) {
      final n = counts[place] = (counts[place] ?? 0) + 1;
      label = '$place $n';
    } else {
      label = v.name
          .replaceFirst(RegExp(r'^(Microsoft|Google|Apple)\s+'), '')
          .replaceFirst(RegExp(r'\s*[-–(].*$'), '')
          .replaceFirst(RegExp(r'\s+Online.*$'), '')
          .trim();
      if (label.isEmpty) label = place;
    }
    out.add(ReadVoice(v.name, v.locale, label));
  }
  return out;
}

/// Compact floating player shown over an article while it is read aloud.
class ReadAloudPlayer extends StatefulWidget {
  const ReadAloudPlayer({super.key, required this.controller, required this.article});
  final ReadAloud controller;
  final Rec article;
  @override
  State<ReadAloudPlayer> createState() => _ReadAloudPlayerState();
}

class _ReadAloudPlayerState extends State<ReadAloudPlayer> {
  bool _tune = false;

  String _speedLabel(double s) => '${s == s.roundToDouble() ? s.toStringAsFixed(0) : s.toString()}×';

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    final dark = AppColors.isDark;
    final radius = BorderRadius.circular(Rad.xl);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, math.max(inset, 12) + 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.45 : 0.14), blurRadius: 30, offset: const Offset(0, 10), spreadRadius: -6),
            BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: radius,
                color: dark ? const Color(0xFF1C1E22).withValues(alpha: 0.86) : Colors.white.withValues(alpha: 0.88),
                border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.05), width: 0.8),
              ),
              child: ListenableBuilder(listenable: widget.controller, builder: (context, _) => _content()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content() {
    final r = widget.controller;
    final status = r.finished ? 'Finished' : (r.playing ? 'Reading aloud' : 'Paused');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 10),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ArticleCover(widget.article, width: 44, height: 44, radius: 10, iconSize: 20, cacheWidth: 160),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                if (r.playing) ...[Equalizer(color: AppColors.primary, bars: 3, height: 11, barWidth: 3), const SizedBox(width: 6)],
                Text(status, style: T.labelSm.c(AppColors.primary)),
                Text('  ·  ${math.min(r.index + 1, r.total)} of ${r.total}', style: T.labelSm.tnum.c(AppColors.onSurfaceVariant)),
              ]),
              const SizedBox(height: 3),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, ?cur]),
                child: SizedBox(
                  key: ValueKey(r.index),
                  width: double.infinity,
                  // Fixed two-line height, so the player never jumps between sentences.
                  height: 36,
                  child: Text(r.current, style: T.bodySm.c(AppColors.onSurface).lh(1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ),
            ]),
          ),
          IconButton(
            tooltip: 'Close player',
            visualDensity: VisualDensity.compact,
            icon: Icon(Symbols.close_rounded, size: 20, color: AppColors.onSurfaceVariant),
            onPressed: r.close,
          ),
        ]),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: r.progress),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(value: v, minHeight: 4, color: AppColors.primary, backgroundColor: AppColors.surfaceContainerHigh),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _pill(
                  label: _speedLabel(r.speed),
                  icon: Symbols.speed_rounded,
                  tooltip: 'Speed (tap to change)',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    r.cycleSpeed();
                  },
                ),
              ),
            ),
            IconButton(
              tooltip: 'Previous sentence',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Symbols.skip_previous_rounded, fill: 1),
              onPressed: r.index > 0 ? () => r.skip(-1) : null,
            ),
            const SizedBox(width: 4),
            _playButton(r),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Next sentence',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Symbols.skip_next_rounded, fill: 1),
              onPressed: r.index < r.total - 1 ? () => r.skip(1) : null,
            ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _pill(
                  label: 'Voice',
                  icon: Symbols.tune_rounded,
                  tooltip: _tune ? 'Hide voice settings' : 'Voice settings',
                  selected: _tune,
                  onTap: () => setState(() => _tune = !_tune),
                ),
              ),
            ),
          ]),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _tune ? _settings(r) : const SizedBox(width: double.infinity),
        ),
      ]),
    );
  }

  Widget _playButton(ReadAloud r) {
    final label = r.playing ? 'Pause' : (r.finished ? 'Play again' : 'Play');
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Pressable(
          scale: 0.92,
          onTap: () {
            HapticFeedback.lightImpact();
            r.toggle();
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: c)),
              child: Icon(
                r.playing ? Symbols.pause_rounded : (r.finished ? Symbols.replay_rounded : Symbols.play_arrow_rounded),
                key: ValueKey('${r.playing}${r.finished}'),
                size: 30,
                fill: 1,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill({required String label, required IconData icon, required String tooltip, required VoidCallback onTap, bool selected = false}) {
    final fg = selected ? AppColors.primary : AppColors.onSurface;
    return Tooltip(
      message: tooltip,
      child: Pressable(
        scale: 0.94,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(maxWidth: 84),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.tint(AppColors.primary) : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(Rad.full),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: fg),
            const SizedBox(width: 5),
            Flexible(child: Text(label, style: T.labelMd.tnum.c(fg), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }

  Widget _settings(ReadAloud r) {
    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(t, style: T.labelSm.c(AppColors.onSurfaceVariant)),
        );
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 6),
        Divider(height: 1, color: AppColors.outlineVariant),
        title('Speed'),
        ChipRow(padding: EdgeInsets.zero, children: [
          for (final s in ReadAloud.speeds) VChip(_speedLabel(s), dense: true, height: 32, selected: r.speed == s, selectedColor: AppColors.primary, onTap: () => r.setSpeed(s)),
        ]),
        title('Tone'),
        Row(children: [
          for (final t in ReadTone.values) ...[
            if (t != ReadTone.values.first) const SizedBox(width: 8),
            VChip(t.label, dense: true, height: 32, selected: r.tone == t, selectedColor: AppColors.primary, onTap: () => r.setTone(t)),
          ],
        ]),
        if (r.voices.length > 1) ...[
          title('Voice'),
          ChipRow(padding: EdgeInsets.zero, children: [
            for (final v in r.voices) VChip(v.label, dense: true, height: 32, selected: r.voice?.key == v.key, selectedColor: AppColors.primary, onTap: () => r.setVoice(v)),
          ]),
        ],
      ]),
    );
  }
}
