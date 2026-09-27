import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'library_screen.dart';

class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key, required this.slug});
  final String slug;
  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  Rec? _a;
  bool _loading = true;
  bool _saved = false;
  bool _helpful = false;
  bool _helpfulInitially = false;
  bool _speaking = false;
  final _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _load();
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final a = await Repo.article(widget.slug);
      if (a != null) {
        final r = await Future.wait([Repo.bookmarkIds(), Repo.isHelpful(a['id'])]);
        _saved = (r[0] as Set<String>).contains(a['id']);
        _helpful = _helpfulInitially = r[1] as bool;
      }
      _a = a;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Map<String, dynamic> get _body => Map<String, dynamic>.from((_a?['body'] as Map?) ?? {});

  String get _plainText {
    final b = _body;
    final hl = b['highlight'] as Map?;
    return [
      _a?['title'],
      b['intro'],
      if (hl != null) '${hl['title']}. ${hl['text']}',
      if (b['tips_title'] != null) b['tips_title'],
      for (final t in (b['tips'] as List? ?? [])) '${t['title']}. ${t['text']}',
      b['quote'],
    ].whereType<String>().join('\n\n');
  }

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await _tts.setSpeechRate(0.45);
    await _tts.speak(_plainText);
  }

  Future<void> _toggleSave() async {
    final on = !_saved;
    setState(() => _saved = on);
    try {
      await Repo.setBookmark(_a!['id'], on);
      if (mounted) toast(context, on ? 'Saved to your library' : 'Removed from saved');
    } catch (_) {
      setState(() => _saved = !on);
    }
  }

  Future<void> _toggleHelpful() async {
    final on = !_helpful;
    setState(() => _helpful = on);
    try {
      await Repo.setHelpful(_a!['id'], on);
    } catch (_) {
      setState(() => _helpful = !on);
    }
  }

  int get _helpfulCount {
    final base = (_a?['helpful_count'] as num?)?.toInt() ?? 0;
    return base + (_helpful && !_helpfulInitially ? 1 : 0) - (!_helpful && _helpfulInitially ? 1 : 0);
  }

  void _share() {
    final a = _a!;
    SharePlus.instance.share(ShareParams(
      subject: a['title'],
      text: '${a['title']}\n\n${_body['intro'] ?? a['subtitle'] ?? ''}\n\n— shared from VitalU Health Education Library',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    return VPage(
      header: const MainHeader('Vitalu Health Education Library'),
      nav: NavTab.library,
      navVariantLibrary: true,
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, onTap: () => goBack(context, '/library')),
          const SizedBox(width: Sp.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HEALTH EDUCATION', style: T.labelSm.c(AppColors.onSurfaceVariant).tracking(0.8)),
              Text('Study Season Sanctuary', style: T.labelMd),
            ]),
          ),
          if (a != null) ...[
            CircleButton(_speaking ? Symbols.stop_circle : Symbols.volume_up,
                size: 40, iconSize: 20, bg: AppColors.primaryFixed, fg: AppColors.primary, onTap: _toggleSpeak),
            const SizedBox(width: 8),
            CircleButton(Symbols.bookmark, size: 40, iconSize: 20, bg: AppColors.secondaryFixed, fg: _saved ? AppColors.secondary : AppColors.onSecondaryFixedVariant, onTap: _toggleSave)
                .withFill(_saved),
          ],
        ]),
        if (_loading) const Loading(),
        if (!_loading && a == null)
          EmptyState(icon: Symbols.menu_book, title: 'Article not found', text: 'It may have been moved or updated.', action: SoftButton('Back to library', expand: false, onTap: () => context.go('/library'))),
        if (a != null) ..._content(a),
      ],
    );
  }

  List<Widget> _content(Rec a) {
    final b = _body;
    final hl = b['highlight'] as Map?;
    final tips = List<Map>.from(b['tips'] as List? ?? []);
    final cta = b['cta'] as Map?;
    return [
      ClipRRect(
        borderRadius: BorderRadius.circular(Rad.md),
        child: SizedBox(
          height: 224,
          child: Stack(fit: StackFit.expand, children: [
            AssetImg(articleImage(a)),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Pill(
                  color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
                  shadow: Shadows.tiny,
                  child: Text('🌿 Reviewed by ${a['author'] ?? 'Campus Wellness Team'}', style: T.labelSm, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
          ]),
        ),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill(color: AppColors.tertiaryFixed, child: Text('${a['emoji'] ?? '📘'} ${a['category_label']}', style: T.labelSm.c(AppColors.onTertiaryFixedVariant))),
          Pill(color: AppColors.surfaceContainerHigh, child: Text('⏱️ ${a['read_minutes']} min read', style: T.labelSm.c(AppColors.onSurfaceVariant))),
          if (a['badge'] != null) Pill(color: AppColors.primaryFixed, child: Text(a['badge'], style: T.labelSm.c(AppColors.onPrimaryFixedVariant))),
        ]),
        const SizedBox(height: Sp.sm),
        Text(a['title'], style: T.headlineMd.lh(1.3)),
        if (b['intro'] != null) ...[
          const SizedBox(height: Sp.sm),
          Text(b['intro'], style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.7)),
        ],
      ]),
      if (hl != null)
        VCard(
          color: AppColors.tertiaryFixed.withValues(alpha: 0.35),
          shadow: Shadows.tiny,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconCircle(iconByName(hl['icon']), size: 36, iconSize: 20, fg: AppColors.tertiary),
              const SizedBox(width: Sp.sm),
              Expanded(child: Text(hl['title'] ?? '', style: T.headlineSm)),
            ]),
            const SizedBox(height: Sp.sm),
            Text(hl['text'] ?? '', style: T.bodySm.c(AppColors.onSurfaceVariant).lh(1.6)),
          ]),
        ),
      if (tips.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Symbols.spa, size: 22, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(b['tips_title'] ?? 'Gentle tips', style: T.headlineSm)),
          ]),
          const SizedBox(height: Sp.sm),
          for (final t in tips)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: VCard(
                color: AppColors.surfaceContainerLow,
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t['emoji'] ?? '•', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: Sp.sm),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t['title'] ?? '', style: T.labelMd),
                      const SizedBox(height: 2),
                      Text(t['text'] ?? '', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                    ]),
                  ),
                ]),
              ),
            ),
        ]),
      if (b['quote'] != null)
        VCard(
          color: AppColors.surfaceContainer,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Symbols.eco, size: 20, color: AppColors.primary),
            const SizedBox(width: Sp.sm),
            Expanded(child: Text('"${b['quote']}"', style: T.bodySm.c(AppColors.onSurfaceVariant).copyWith(fontStyle: FontStyle.italic).lh(1.6))),
          ]),
        ),
      if (cta != null)
        VCard(
          shadow: Shadows.card,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconCircle(Symbols.favorite, size: 44, bg: AppColors.secondaryFixed, fg: AppColors.secondary, radius: 14),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('CURIOUS ABOUT YOUR NUMBERS?', style: T.labelSm.c(AppColors.secondary).tracking(0.6)),
                  Text(cta['title'] ?? '', style: T.headlineSm.lh(1.3)),
                  const SizedBox(height: 2),
                  Text(cta['text'] ?? '', style: T.bodySm.c(AppColors.onSurfaceVariant)),
                ]),
              ),
            ]),
            const SizedBox(height: Sp.md),
            PrimaryButton(cta['label'] ?? 'Open', icon: Symbols.arrow_forward, onTap: cta['route'] == null ? null : () => context.push(cta['route'])),
          ]),
        ),
      Column(children: [
        Text('Was this mindful guide helpful?', style: T.labelMd.c(AppColors.onSurfaceVariant)),
        const SizedBox(height: Sp.sm),
        Row(children: [
          Expanded(
            child: SoftButton('Helpful ($_helpfulCount)',
                icon: Symbols.favorite,
                height: 48,
                color: _helpful ? AppColors.secondaryFixed : AppColors.surfaceContainerLow,
                iconColor: AppColors.secondary,
                style: T.labelMd,
                onTap: _toggleHelpful),
          ),
          const SizedBox(width: Sp.sm),
          Expanded(child: SoftButton('Share with peer', icon: Symbols.send, height: 48, iconColor: AppColors.primary, style: T.labelMd, onTap: _share)),
        ]),
      ]),
    ];
  }
}

extension on CircleButton {
  /// CircleButton has no fill parameter; wrap to render a filled icon when active.
  Widget withFill(bool filled) => filled
      ? Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: GestureDetector(onTap: onTap, child: Icon(icon, size: iconSize, color: fg, fill: 1)),
        )
      : this;
}
