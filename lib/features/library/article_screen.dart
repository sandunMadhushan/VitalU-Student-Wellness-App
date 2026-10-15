import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/catalog.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'library_screen.dart';
import 'read_aloud.dart';

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
  final _reader = ReadAloud();

  @override
  void initState() {
    super.initState();
    _reader.addListener(_onReader);
    _load();
  }

  @override
  void dispose() {
    _reader.removeListener(_onReader);
    _reader.dispose();
    super.dispose();
  }

  /// Rebuilds only when the player opens or closes; the player listens itself.
  bool _playerOpen = false;
  void _onReader() {
    if (_reader.open != _playerOpen && mounted) setState(() => _playerOpen = _reader.open);
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

  void _listen() {
    HapticFeedback.selectionClick();
    _reader.open ? _reader.toggle() : _reader.start(_plainText);
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
      text: '${a['title']}\n\n${_body['intro'] ?? a['subtitle'] ?? ''}\n\nShared from VitalU',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    return VPage(
      floating: AnimatedSwitcher(
        duration: const Duration(milliseconds: 320),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, anim) => SizeTransition(
          sizeFactor: anim,
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim), child: FadeTransition(opacity: anim, child: child)),
        ),
        child: _playerOpen && a != null ? ReadAloudPlayer(controller: _reader, article: a) : const SizedBox(width: double.infinity),
      ),
      header: TitleHeader('', onLeading: () => goBack(context, '/library'), actions: [
        if (a != null) ...[
          IconButton(tooltip: _playerOpen ? 'Play or pause' : 'Listen', icon: Icon(Symbols.headphones_rounded, fill: _playerOpen ? 1 : 0, color: _playerOpen ? AppColors.primary : null), onPressed: _listen),
          IconButton(
            tooltip: _saved ? 'Remove from saved' : 'Save',
            icon: Icon(Symbols.bookmark_rounded, fill: _saved ? 1 : 0, color: _saved ? AppColors.primary : null),
            onPressed: _toggleSave,
          ),
          IconButton(tooltip: 'Share', icon: const Icon(Symbols.share_rounded), onPressed: _share),
        ],
      ]),
      children: [
        if (_loading) const Loading(),
        if (!_loading && a == null)
          EmptyState(icon: Symbols.menu_book_rounded, title: 'Article not found', text: 'It may have been moved or updated.', action: SoftButton('Back to library', expand: false, onTap: () => context.go('/library'))),
        if (a != null) ..._content(a),
      ],
    );
  }

  List<Widget> _content(Rec a) {
    final b = _body;
    final hl = b['highlight'] as Map?;
    final tips = List<Map>.from(b['tips'] as List? ?? []);
    final cta = b['cta'] as Map?;
    final (icon, c) = articleStyle(a['category']);
    final body = T.bodyLg.c(AppColors.onSurface).lh(1.55);
    return [
      AspectRatio(
        aspectRatio: 16 / 9,
        child: Hero(tag: 'article-cover-${a['slug']}', child: ArticleCover(a, radius: Rad.lg, iconSize: 56)),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: c, fill: 1),
          const SizedBox(width: 6),
          Flexible(child: Text(a['category_label'] ?? '', style: T.labelMd.semi.c(c))),
        ]),
        const SizedBox(height: 10),
        Text(a['title'], style: T.headlineLg.lh(1.2)),
        const SizedBox(height: 10),
        Text(
          [
            '${a['read_minutes']} min read',
            if (a['author'] != null) 'Reviewed by ${a['author']}',
          ].join(' · '),
          style: T.bodySm.c(AppColors.onSurfaceVariant),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topLeft,
          child: _playerOpen
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Sp.md),
                  child: SoftButton(
                    'Listen to this article',
                    icon: Symbols.headphones_rounded,
                    expand: false,
                    height: 40,
                    color: AppColors.tint(AppColors.primary),
                    fg: AppColors.primary,
                    onTap: _listen,
                  ),
                ),
        ),
        if (b['intro'] != null) ...[
          const SizedBox(height: Sp.lg),
          Text(b['intro'], style: body),
        ],
      ]),
      if (hl != null)
        VCard(
          color: AppColors.tint(c),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(iconByName(hl['icon']), size: 22, color: c, fill: 1),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hl['title'] ?? '', style: T.headlineSm),
                const SizedBox(height: 4),
                Text(hl['text'] ?? '', style: T.bodyMd.lh(1.5)),
              ]),
            ),
          ]),
        ),
      if (tips.isNotEmpty)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(b['tips_title'] ?? 'What you can do', style: T.headlineMd),
          const SizedBox(height: Sp.md),
          for (int i = 0; i < tips.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.md),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppColors.tint(c), shape: BoxShape.circle),
                  child: Text('${i + 1}', style: T.labelMd.semi.c(c)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tips[i]['title'] ?? '', style: T.labelLg.semi),
                    const SizedBox(height: 2),
                    Text(tips[i]['text'] ?? '', style: T.bodyMd.c(AppColors.onSurfaceVariant).lh(1.5)),
                  ]),
                ),
              ]),
            ),
        ]),
      if (b['quote'] != null)
        Container(
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(border: Border(left: BorderSide(color: c, width: 3))),
          child: Text(b['quote'], style: T.bodyLg.c(AppColors.onSurfaceVariant).lh(1.5).copyWith(fontStyle: FontStyle.italic)),
        ),
      if (cta != null)
        VCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(cta['title'] ?? '', style: T.headlineSm),
            const SizedBox(height: 4),
            Text(cta['text'] ?? '', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
            const SizedBox(height: Sp.md),
            SoftButton(cta['label'] ?? 'Open', trailingIcon: Symbols.arrow_forward_rounded, onTap: cta['route'] == null ? null : () => context.push(cta['route'])),
          ]),
        ),
      const Divider(height: Sp.lg),
      Row(children: [
        Expanded(child: Text('Was this helpful?', style: T.bodyLg)),
        _helpful
            ? FilledButton.tonalIcon(style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: _toggleHelpful, icon: const Icon(Symbols.thumb_up_rounded, fill: 1, size: 18), label: Text('Yes · $_helpfulCount'))
            : OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: _toggleHelpful,
                icon: const Icon(Symbols.thumb_up_rounded, size: 18),
                label: Text(_helpfulCount > 0 ? 'Yes · $_helpfulCount' : 'Yes'),
              ),
      ]),
    ];
  }
}
