import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import '../support/professionals_screen.dart' show callNumber;
import 'learn_data.dart';
import 'library_screen.dart';
import 'lungs_animation.dart';
import 'read_aloud.dart';

/// An article's body in the current format. Older articles (intro,
/// highlight, tips, quote, cta) are mapped onto it.
class ArticleBody {
  ArticleBody(Map<String, dynamic> b)
      : hook = (b['hook'] ?? b['intro']) as String?,
        sections = [
          for (final s in (b['sections'] as List? ?? const [])) Map<String, dynamic>.from(s as Map),
          if (b['sections'] == null && (b['tips'] as List?)?.isNotEmpty == true)
            {
              'heading': b['tips_title'] ?? 'What you can do',
              'bullets': [for (final t in b['tips'] as List) '${t['title']}. ${t['text']}'],
            },
        ],
        keyPoint = (b['key_point'] ?? (b['highlight'] as Map?)?['text']) as String?,
        myths = [for (final m in (b['myths'] as List? ?? const [])) Map<String, dynamic>.from(m as Map)],
        takeaway = (b['takeaway'] ?? b['quote']) as String?,
        tryThis = b['try_this'] as String?,
        seekHelp = b['seek_help'] as String?,
        tools = [
          for (final t in (b['tools'] as List? ?? const [])) Map<String, dynamic>.from(t as Map),
          if (b['tools'] == null && (b['cta'] as Map?)?['route'] != null) {'label': (b['cta'] as Map)['label'] ?? 'Open', 'route': (b['cta'] as Map)['route']},
        ],
        referral = b['referral'] == null ? null : Map<String, dynamic>.from(b['referral'] as Map),
        animation = b['animation'] as String?,
        references = [for (final r in (b['references'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];

  final String? hook;
  final List<Map<String, dynamic>> sections;
  final String? keyPoint;
  final List<Map<String, dynamic>> myths;
  final String? takeaway;
  final String? tryThis;
  final String? seekHelp;
  final List<Map<String, dynamic>> tools;
  final Map<String, dynamic>? referral;
  final String? animation;
  final List<Map<String, dynamic>> references;

  /// Everything a listener should hear, in reading order.
  String plainText(String title) => [
        title,
        hook,
        for (final s in sections) ...[s['heading'], s['text'], ...List<String>.from(s['bullets'] ?? const [])],
        if (keyPoint != null) 'Key point. $keyPoint',
        for (final m in myths) 'Myth: ${m['myth']} Fact: ${m['fact']}',
        if (takeaway != null) 'Key takeaway. $takeaway',
        if (tryThis != null) 'Try this. $tryThis',
        if (seekHelp != null) 'When to get help. $seekHelp',
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join('\n\n');
}

class ArticleScreen extends StatefulWidget {
  const ArticleScreen({super.key, required this.slug});
  final String slug;
  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  Rec? _a;
  List<Rec> _related = [];
  bool _loading = true;
  bool _saved = false;
  bool _helpful = false;
  bool _helpfulInitially = false;
  bool _readMarked = false;
  bool _showRefs = false;
  final _reader = ReadAloud();
  final _sectionKeys = <GlobalKey>[];

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
    if (_reader.finished) _markRead();
    if (_reader.open != _playerOpen && mounted) setState(() => _playerOpen = _reader.open);
  }

  Future<void> _load() async {
    try {
      final all = await loadArticles();
      final a = all.where((x) => x['slug'] == widget.slug).firstOrNull;
      if (a != null) {
        _related = all.where((x) => x['category'] == a['category'] && x['slug'] != a['slug']).take(3).toList();
        final id = a['id'] as String?;
        if (id != null) {
          try {
            final r = await Future.wait([Repo.bookmarkIds(), Repo.isHelpful(id)]);
            _saved = (r[0] as Set<String>).contains(id);
            _helpful = _helpfulInitially = r[1] as bool;
          } catch (_) {}
        }
      }
      _a = a;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  ArticleBody get _body => ArticleBody(Map<String, dynamic>.from((_a?['body'] as Map?) ?? {}));

  /// Counts the article as read once the student reaches the end (or
  /// listens to the end), for the Curious Learner badge.
  void _markRead() {
    final id = _a?['id'] as String?;
    if (_readMarked || id == null) return;
    _readMarked = true;
    Repo.markArticleRead(id);
  }

  void _listen() {
    HapticFeedback.selectionClick();
    _reader.open ? _reader.toggle() : _reader.start(_body.plainText(_a?['title'] ?? ''));
  }

  Future<void> _toggleSave() async {
    final id = _a?['id'] as String?;
    if (id == null) return toast(context, 'This article can be saved once the library has synced.');
    final on = !_saved;
    setState(() => _saved = on);
    try {
      await Repo.setBookmark(id, on);
      if (mounted) toast(context, on ? 'Saved to your library' : 'Removed from saved');
    } catch (_) {
      setState(() => _saved = !on);
    }
  }

  Future<void> _toggleHelpful() async {
    final id = _a?['id'] as String?;
    if (id == null) return;
    final on = !_helpful;
    setState(() => _helpful = on);
    try {
      await Repo.setHelpful(id, on);
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
      text: '${a['title']}\n\n${_body.hook ?? a['subtitle'] ?? ''}\n\nShared from VitalU',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final a = _a;
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 400 && n.metrics.pixels > 200) _markRead();
        return false;
      },
      child: VPage(
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
            EmptyState(icon: Symbols.menu_book_rounded, title: 'Article not found', text: 'It may have been moved or updated.', action: SoftButton('Back to Learn', expand: false, onTap: () => context.go('/library'))),
          if (a != null) ..._content(a),
        ],
      ),
    );
  }

  List<Widget> _content(Rec a) {
    final b = _body;
    final (icon, c) = articleStyle(a['category']);
    final body = T.bodyLg.c(AppColors.onSurface).lh(1.6);
    while (_sectionKeys.length < b.sections.length) {
      _sectionKeys.add(GlobalKey());
    }
    return [
      AspectRatio(
        aspectRatio: 16 / 9,
        child: Hero(tag: 'article-cover-${a['slug']}', child: ArticleCover(a, radius: Rad.lg, iconSize: 56)),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: topicByKey(a['category']) == null ? null : () => context.push('/library/topic/${a['category']}'),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: c, fill: 1),
            const SizedBox(width: 6),
            Flexible(child: Text(topicByKey(a['category'])?.title ?? a['category_label'] ?? '', style: T.labelMd.semi.c(c))),
          ]),
        ),
        const SizedBox(height: 10),
        Text(a['title'], style: T.headlineLg.lh(1.2)),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 4, children: [
          _meta(Symbols.schedule_rounded, '${a['read_minutes']} min read'),
          _meta(Symbols.verified_rounded, a['author'] ?? 'VitalU health team'),
          if (b.references.isNotEmpty) _meta(Symbols.menu_book_rounded, '${b.references.length} ${b.references.length == 1 ? 'source' : 'sources'}'),
        ]),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topLeft,
          child: _playerOpen
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Sp.md),
                  child: SoftButton('Listen to this article', icon: Symbols.headphones_rounded, expand: false, height: 40, color: AppColors.tint(AppColors.primary), fg: AppColors.primary, onTap: _listen),
                ),
        ),
      ]),
      if (b.hook != null)
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(color: AppColors.tint(c), borderRadius: BorderRadius.circular(Rad.lg)),
          child: Text(b.hook!, style: T.bodyLg.w(FontWeight.w600).lh(1.5)),
        ),
      if (b.sections.length > 1) _contents(b, c),
      for (int i = 0; i < b.sections.length; i++) ...[
        Column(key: _sectionKeys[i], crossAxisAlignment: CrossAxisAlignment.start, children: [
          if ((b.sections[i]['heading'] ?? '').toString().isNotEmpty) ...[
            Text('${i + 1}. ${b.sections[i]['heading']}', style: T.headlineMd),
            const SizedBox(height: 8),
          ],
          if ((b.sections[i]['text'] ?? '').toString().isNotEmpty) Text(b.sections[i]['text'], style: body),
          for (final bullet in List<String>.from(b.sections[i]['bullets'] ?? const []))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 9), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle))),
                const SizedBox(width: 10),
                Expanded(child: Text(bullet, style: T.bodyLg.lh(1.5))),
              ]),
            ),
        ]),
        if (i == 0 && b.animation == 'lungs') const LungsAnimation(),
      ],
      if (b.keyPoint != null) _callout(Symbols.lightbulb_rounded, AppColors.warning, 'Key point', b.keyPoint!),
      if (b.myths.isNotEmpty) _myths(b.myths),
      if (b.takeaway != null) _callout(Symbols.flag_rounded, c, 'Key takeaway', b.takeaway!),
      if (b.tryThis != null) _callout(Symbols.directions_run_rounded, AppColors.tertiary, 'Try this', b.tryThis!),
      if (b.seekHelp != null) _callout(Symbols.medical_services_rounded, AppColors.error, 'When to get help', b.seekHelp!),
      if (b.referral != null) _referral(b.referral!),
      if (b.tools.isNotEmpty)
        ListGroup(header: 'Try it in VitalU', children: [
          for (final t in b.tools) ListRow(icon: Symbols.arrow_outward_rounded, color: AppColors.primary, title: t['label'] ?? 'Open', onTap: t['route'] == null ? null : () => context.push(t['route'])),
        ]),
      if (_related.isNotEmpty)
        ListGroup(header: 'Related reads', dividerIndent: Sp.md + 64 + 12, children: [
          for (final r in _related) ArticleRow(r, hero: false, onTap: () => context.pushReplacement('/library/article/${r['slug']}')),
        ]),
      if (b.references.isNotEmpty) _references(b.references),
      const Divider(height: Sp.lg),
      Row(children: [
        Expanded(child: Text('Was this helpful?', style: T.bodyLg)),
        _helpful
            ? FilledButton.tonalIcon(style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: _toggleHelpful, icon: const Icon(Symbols.thumb_up_rounded, fill: 1, size: 18), label: Text('Yes · $_helpfulCount'))
            : OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                onPressed: _a?['id'] == null ? null : _toggleHelpful,
                icon: const Icon(Symbols.thumb_up_rounded, size: 18),
                label: Text(_helpfulCount > 0 ? 'Yes · $_helpfulCount' : 'Yes'),
              ),
      ]),
      const PrivacyNote('General health education, not a diagnosis. Speak to a health professional about your own situation.'),
    ];
  }

  Widget _meta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(text, style: T.bodySm.c(AppColors.onSurfaceVariant)),
      ]);

  /// "In this article": a numbered list that jumps to each section.
  Widget _contents(ArticleBody b, Color c) => VCard(
        color: AppColors.surfaceContainerLow,
        flat: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('In this article', style: T.labelLg.semi.c(c)),
          const SizedBox(height: 6),
          for (int i = 0; i < b.sections.length; i++)
            if ((b.sections[i]['heading'] ?? '').toString().isNotEmpty)
              InkWell(
                onTap: () {
                  final ctx = _sectionKeys[i].currentContext;
                  if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic, alignment: 0.05);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SizedBox(width: 22, child: Text('${i + 1}.', style: T.bodyMd.c(c).w(FontWeight.w700))),
                    Expanded(child: Text(b.sections[i]['heading'], style: T.bodyMd)),
                  ]),
                ),
              ),
          if (b.keyPoint != null || b.takeaway != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(children: [
                SizedBox(width: 22, child: Icon(Symbols.flag_rounded, size: 16, color: c, fill: 1)),
                Expanded(child: Text('Key takeaways', style: T.bodyMd)),
              ]),
            ),
        ]),
      );

  Widget _callout(IconData icon, Color color, String title, String text) => Container(
        padding: const EdgeInsets.all(Sp.md),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: AppColors.isDark ? 0.16 : 0.08), AppColors.surfaceContainerLowest),
          borderRadius: BorderRadius.circular(Rad.lg),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 22, color: color, fill: 1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: T.labelLg.semi.c(color)),
              const SizedBox(height: 4),
              Text(text, style: T.bodyLg.lh(1.5)),
            ]),
          ),
        ]),
      );

  Widget _myths(List<Map<String, dynamic>> myths) => VCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Symbols.fact_check_rounded, color: AppColors.mind, fill: 1),
            const SizedBox(width: 8),
            Text('Myths and facts', style: T.headlineSm),
          ]),
          const SizedBox(height: 10),
          for (final m in myths)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TagPill('Myth', bg: AppColors.tint(AppColors.error), fg: AppColors.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m['myth'] ?? '', style: T.bodyMd.c(AppColors.onSurfaceVariant).copyWith(decoration: TextDecoration.lineThrough, decorationColor: AppColors.outline))),
                ]),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TagPill('Fact', bg: AppColors.tint(AppColors.tertiary), fg: AppColors.tertiary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m['fact'] ?? '', style: T.bodyMd.w(FontWeight.w600))),
                ]),
              ]),
            ),
        ]),
      );

  /// Where to go for confidential care, for example the STD clinic.
  Widget _referral(Map<String, dynamic> r) => VCard(
        color: AppColors.tint(AppColors.primary),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconCircle(Symbols.stethoscope_rounded, size: 46, iconSize: 24, fg: AppColors.primary, fill: 1),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Talk to a medical officer', style: T.labelSm.c(AppColors.primary).w(FontWeight.w800)),
                Text(r['title'] ?? '', style: T.headlineSm),
                const SizedBox(height: 4),
                Text(r['text'] ?? '', style: T.bodyMd.lh(1.45)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          if (r['phone'] != null) PrimaryButton(r['label'] ?? 'Call', leadingIcon: Symbols.call_rounded, onTap: () => callNumber(context, r['phone'])),
          const SizedBox(height: 8),
          SoftButton('Ask the health centre anonymously', icon: Symbols.lock_rounded, onTap: () => context.push('/consult')),
        ]),
      );

  Widget _references(List<Map<String, dynamic>> refs) => VCard(
        color: AppColors.surfaceContainerLow,
        flat: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: () => setState(() => _showRefs = !_showRefs),
            child: Row(children: [
              Icon(Symbols.menu_book_rounded, size: 20, color: AppColors.primary, fill: 1),
              const SizedBox(width: 8),
              Expanded(child: Text('References (${refs.length})', style: T.labelLg.semi)),
              Icon(_showRefs ? Symbols.expand_less_rounded : Symbols.expand_more_rounded, color: AppColors.onSurfaceVariant),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            alignment: Alignment.topCenter,
            child: !_showRefs
                ? const SizedBox(width: double.infinity)
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SizedBox(height: 8),
                    for (int i = 0; i < refs.length; i++)
                      InkWell(
                        onTap: refs[i]['url'] == null ? null : () => launchUrl(Uri.parse(refs[i]['url']), mode: LaunchMode.externalApplication),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            SizedBox(width: 22, child: Text('${i + 1}.', style: T.bodySm.c(AppColors.onSurfaceVariant))),
                            Expanded(child: Text(refs[i]['label'] ?? '', style: T.bodySm.c(refs[i]['url'] == null ? AppColors.onSurfaceVariant : AppColors.primary).lh(1.4))),
                          ]),
                        ),
                      ),
                  ]),
          ),
        ]),
      );
}
