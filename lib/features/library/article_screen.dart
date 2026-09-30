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
      text: '${a['title']}\n\n${_body['intro'] ?? a['subtitle'] ?? ''}\n\nShared from VitalU',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    return VPage(
      header: TitleHeader('', onLeading: () => goBack(context, '/library'), actions: [
        if (a != null) ...[
          IconButton(tooltip: _speaking ? 'Stop reading' : 'Read aloud', icon: Icon(_speaking ? Symbols.stop_circle_rounded : Symbols.volume_up_rounded), onPressed: _toggleSpeak),
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
