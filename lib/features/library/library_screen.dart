import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'learn_data.dart';

/// Icon and colour for an article's topic.
(IconData, Color) articleStyle(String? category) {
  final t = topicByKey(category);
  if (t != null) return (t.icon, t.color());
  return switch (category) {
    'nutrition' => (Symbols.restaurant_rounded, AppColors.nutrition),
    'stress' => (Symbols.self_improvement_rounded, AppColors.mind),
    'common' => (Symbols.healing_rounded, AppColors.body),
    _ => (Symbols.auto_stories_rounded, AppColors.primary),
  };
}

/// Cover picture for an article: the bundled illustration
/// (`assets/articles/<slug>.webp`), then a cover uploaded by an admin, then the
/// topic's colour and icon.
class ArticleCover extends StatelessWidget {
  const ArticleCover(this.article, {super.key, this.width, this.height, this.radius = 0, this.iconSize = 40, this.cacheWidth});
  final Rec article;
  final double? width;
  final double? height;
  final double radius;
  final double iconSize;

  /// Decode width in physical pixels; keeps list thumbnails light.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final (icon, c) = articleStyle(article['category']);
    final fallback = Container(
      width: width,
      height: height,
      color: AppColors.tint(c),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: c, fill: 1),
    );
    final url = article['cover_url'] as String?;
    Widget fromUrl() => url == null || url.isEmpty
        ? fallback
        : Image.network(url, width: width, height: height, fit: BoxFit.cover, cacheWidth: cacheWidth, errorBuilder: (_, _, _) => fallback);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/articles/${article['slug']}.webp',
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fromUrl(),
      ),
    );
  }
}

/// Learn home: search, picks for you, and the topics to explore.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _loading = true;
  List<Rec> _all = [];
  Set<String> _saved = {};
  List<Pick> _picks = [];
  bool _savedOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _all = await loadArticles();
    try {
      _saved = await Repo.bookmarkIds();
    } catch (_) {}
    try {
      _picks = await personalPicks();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Rec? _bySlug(String slug) => _all.where((a) => a['slug'] == slug).firstOrNull;

  Future<void> _open(Rec a) async {
    await context.push('/library/article/${a['slug']}');
    _load();
  }

  Future<void> _toggle(Rec a) async {
    final id = a['id'] as String?;
    if (id == null) return toast(context, 'This article can be saved once the library has synced.');
    final on = !_saved.contains(id);
    setState(() => on ? _saved.add(id) : _saved.remove(id));
    try {
      await Repo.setBookmark(id, on);
      if (mounted) toast(context, on ? 'Saved' : 'Removed from saved');
    } catch (_) {
      setState(() => on ? _saved.remove(id) : _saved.add(id));
    }
  }

  Future<void> _search() async {
    final q = TextEditingController();
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          final term = q.text.trim().toLowerCase();
          final topics = term.isEmpty ? const <LearnTopic>[] : learnTopics.where((t) => t.title.toLowerCase().contains(term)).toList();
          final hits = _all
              .where((a) => term.isEmpty || '${a['title']} ${a['subtitle']} ${a['category_label']} ${(a['tags'] as List? ?? []).join(' ')}'.toLowerCase().contains(term))
              .toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              VTextField(controller: q, hint: 'Search topics, e.g. PCOS, sleep, sugar', icon: Symbols.search_rounded, onChanged: (_) => set(() {})),
              const SizedBox(height: Sp.md),
              Expanded(
                child: hits.isEmpty && topics.isEmpty
                    ? const EmptyState(icon: Symbols.search_off_rounded, title: 'No matches', text: 'Try "sleep", "iron" or "stress".')
                    : SingleChildScrollView(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (topics.isNotEmpty)
                            ListGroup(header: 'Topics', children: [
                              for (final t in topics)
                                ListRow(icon: t.icon, color: t.color(), title: t.title, onTap: () {
                                  Navigator.pop(ctx);
                                  context.push('/library/topic/${t.key}');
                                }),
                            ]),
                          if (hits.isNotEmpty)
                            ListGroup(header: 'Articles', dividerIndent: Sp.md + 64 + 12, children: [
                              for (final a in hits)
                                ArticleRow(a, hero: false, onTap: () {
                                  Navigator.pop(ctx);
                                  _open(a);
                                }),
                            ]),
                        ]),
                      ),
              ),
            ]),
          );
        }));
  }

  @override
  Widget build(BuildContext context) {
    final picks = [for (final p in _picks) if (_bySlug(p.slug) != null) (p, _bySlug(p.slug)!)];
    final featured = _all.where((a) => a['is_featured'] == true).toList();
    final carousel = picks.isNotEmpty ? picks.take(6).toList() : [for (final a in featured.take(6)) (const Pick('', 'Featured read'), a)];
    final saved = _all.where((a) => _saved.contains(a['id'])).toList();

    return VPage(
      header: const MainHeader('Learn'),
      nav: NavTab.library,
      topPadding: 0,
      onRefresh: _load,
      children: [
        Text('Small steps. A healthier, happier you.', style: T.bodyLg.c(AppColors.onSurfaceVariant)),
        Row(children: [
          Expanded(child: _searchField()),
          const SizedBox(width: Sp.sm),
          _savedToggle(),
        ]),
        if (_loading) const Loading(),
        if (!_loading && _savedOnly) ...[
          if (saved.isEmpty)
            const EmptyState(icon: Symbols.bookmark_rounded, title: 'Nothing saved yet', text: 'Tap the bookmark on any article to keep it here.')
          else
            ListGroup(header: 'Your saved articles', dividerIndent: Sp.md + 64 + 12, children: [for (final a in saved) ArticleRow(a, saved: true, onTap: () => _open(a), onBookmark: () => _toggle(a))]),
        ],
        if (!_loading && !_savedOnly) ...[
          if (carousel.isNotEmpty) ...[
            SectionHeader(picks.isNotEmpty ? 'Recommended for you' : 'Start here', subtitle: picks.isNotEmpty ? 'Picked from your own logs and checks' : null),
            FullBleed(
              child: SizedBox(
                height: 236,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: Sp.margin),
                  itemCount: carousel.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _PickCard(article: carousel[i].$2, reason: carousel[i].$1.reason, onTap: () => _open(carousel[i].$2)),
                ),
              ),
            ),
          ],
          const SectionHeader('Explore by topic'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.32,
            children: [
              for (final t in learnTopics)
                TopicCard(topic: t, count: _all.where((a) => a['category'] == t.key).length, onTap: () async {
                  await context.push('/library/topic/${t.key}');
                  _load();
                }),
            ],
          ),
          ListGroup(header: 'Get help', children: [
            ListRow(icon: Symbols.bloodtype_rounded, color: AppColors.heart, title: 'Understand a blood report', subtitle: 'Plain-language notes on common lab values', onTap: () => context.push('/blood-report')),
            ListRow(icon: Symbols.stethoscope_rounded, color: AppColors.primary, title: 'Talk to a professional', subtitle: 'Campus medical officers and counsellors', onTap: () => context.push('/professionals')),
          ]),
        ],
      ],
    );
  }

  Widget _searchField() => Semantics(
        button: true,
        label: 'Search topics',
        child: Pressable(
          onTap: _search,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(Rad.full)),
            child: Row(children: [
              Icon(Symbols.search_rounded, size: 20, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(child: ExcludeSemantics(child: Text('Search topics (e.g. PCOS, sleep, sugar)', style: T.bodyMd.c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis))),
            ]),
          ),
        ),
      );

  Widget _savedToggle() {
    final on = _savedOnly;
    final fg = on ? AppColors.onPrimary : AppColors.onSurface;
    return Tooltip(
      message: on ? 'Show all articles' : 'Show saved',
      child: Semantics(
        button: true,
        selected: on,
        label: 'Saved articles',
        child: Pressable(
          scale: 0.94,
          onTap: () => setState(() => _savedOnly = !on),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: on ? AppColors.primary : AppColors.surfaceContainer, borderRadius: BorderRadius.circular(Rad.full)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Symbols.bookmarks_rounded, size: 20, fill: on ? 1 : 0, color: fg),
              if (on || _saved.isNotEmpty) ...[
                const SizedBox(width: 6),
                ExcludeSemantics(child: Text(on ? 'Saved' : '${_saved.length}', style: T.labelMd.tnum.c(fg))),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// A recommended article in the carousel, with why it was picked.
class _PickCard extends StatelessWidget {
  const _PickCard({required this.article, required this.reason, required this.onTap});
  final Rec article;
  final String reason;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, c) = articleStyle(article['category']);
    return SizedBox(
      width: 232,
      child: VCard(
        onTap: onTap,
        padding: EdgeInsets.zero,
        clip: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 120, child: Hero(tag: 'article-cover-${article['slug']}', child: ArticleCover(article, iconSize: 40, cacheWidth: 700))),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 13, color: c, fill: 1),
                const SizedBox(width: 4),
                Expanded(child: Text(reason, style: T.labelSm.c(c).w(FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              Text(article['title'], style: T.labelLg.w(FontWeight.w700).lh(1.25), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text('${article['read_minutes']} min read', style: T.labelSm.c(AppColors.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A topic tile with its illustration and article count.
class TopicCard extends StatelessWidget {
  const TopicCard({super.key, required this.topic, required this.count, required this.onTap});
  final LearnTopic topic;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = topic.color();
    final dark = AppColors.isDark;
    return Material(
      color: Color.alphaBlend(c.withValues(alpha: dark ? 0.2 : 0.1), AppColors.surfaceContainerLowest),
      borderRadius: BorderRadius.circular(Rad.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(children: [
          Positioned(
            right: -6,
            bottom: -6,
            width: 72,
            height: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(topic.image, fit: BoxFit.cover, cacheWidth: 220, errorBuilder: (_, _, _) => Icon(topic.icon, size: 44, color: c.withValues(alpha: 0.5), fill: 1)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(topic.icon, size: 20, color: c, fill: 1),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 56),
                child: Text(topic.short, style: T.labelMd.w(FontWeight.w800).lh(1.2), maxLines: 3),
              ),
              const Spacer(),
              Text(topic.key == 'habits' ? 'For you' : '$count ${count == 1 ? 'read' : 'reads'}', style: T.labelSm.c(c).w(FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// An article in a list: cover thumbnail, title, topic and reading time.
class ArticleRow extends StatelessWidget {
  const ArticleRow(this.article, {super.key, this.onTap, this.hero = true, this.saved = false, this.onBookmark, this.reason});
  final Rec article;
  final VoidCallback? onTap;
  final bool hero;
  final bool saved;
  final VoidCallback? onBookmark;

  /// Why it was recommended, shown instead of the topic.
  final String? reason;

  static const thumb = 64.0;

  @override
  Widget build(BuildContext context) {
    final a = article;
    final (icon, c) = articleStyle(a['category']);
    Widget cover = ArticleCover(a, width: thumb, height: thumb, radius: 12, iconSize: 26, cacheWidth: (thumb * 2 * MediaQuery.devicePixelRatioOf(context)).round());
    if (hero) cover = Hero(tag: 'article-cover-${a['slug']}', child: cover);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(Sp.md, 12, onBookmark == null ? Sp.md : 4, 12),
        child: Row(children: [
          cover,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['title'], style: T.bodyLg.semi.lh(1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
              if (a['subtitle'] != null && reason == null) ...[
                const SizedBox(height: 2),
                Text(a['subtitle'], style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 4),
              Row(children: [
                Icon(reason == null ? Symbols.schedule_rounded : icon, size: 13, color: reason == null ? AppColors.onSurfaceVariant : c, fill: 1),
                const SizedBox(width: 4),
                Flexible(child: Text(reason ?? '${a['read_minutes']} min read', style: T.bodySm.c(reason == null ? AppColors.onSurfaceVariant : c).w(FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
            ]),
          ),
          if (onBookmark != null)
            IconButton(
              tooltip: saved ? 'Remove from saved' : 'Save',
              icon: Icon(Symbols.bookmark_rounded, fill: saved ? 1 : 0, color: saved ? AppColors.primary : AppColors.onSurfaceVariant),
              onPressed: onBookmark,
            )
          else
            Icon(Symbols.chevron_right_rounded, color: AppColors.outline),
        ]),
      ),
    );
  }
}

/// A topic: its picture and introduction, then its articles. "Your Habits,
/// Your Health" also lists reads picked from the student's own logs.
class LearnTopicScreen extends StatefulWidget {
  const LearnTopicScreen({super.key, required this.topicKey});
  final String topicKey;
  @override
  State<LearnTopicScreen> createState() => _LearnTopicScreenState();
}

class _LearnTopicScreenState extends State<LearnTopicScreen> {
  bool _loading = true;
  List<Rec> _all = [];
  List<Pick> _picks = [];

  LearnTopic get _topic => topicByKey(widget.topicKey) ?? learnTopics.last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _all = await loadArticles();
    if (widget.topicKey == 'habits') {
      try {
        _picks = await personalPicks();
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(Rec a) async {
    await context.push('/library/article/${a['slug']}');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = _topic;
    final c = t.color();
    final articles = _all.where((a) => a['category'] == t.key).toList();
    final picks = [for (final p in _picks) if (_all.any((a) => a['slug'] == p.slug)) (p, _all.firstWhere((a) => a['slug'] == p.slug))];
    return VPage(
      header: TitleHeader('', onLeading: () => goBack(context, '/library')),
      topPadding: 0,
      onRefresh: _load,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Rad.xl),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset(t.image, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: AppColors.tint(c), child: Icon(t.icon, size: 72, color: c, fill: 1))),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54], stops: [0.5, 1]))),
              Positioned(
                left: 16,
                right: 16,
                bottom: 14,
                child: Text(t.title, style: T.headlineMd.c(Colors.white)),
              ),
            ]),
          ),
        ),
        Text(t.intro, style: T.bodyLg.c(AppColors.onSurfaceVariant).lh(1.45)),
        if (_loading) const Loading(),
        if (!_loading && t.key == 'habits')
          picks.isEmpty
              ? VCard(
                  color: AppColors.tint(c),
                  flat: true,
                  child: Row(children: [
                    Icon(Symbols.insights_rounded, color: c, fill: 1),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Log your water, meals, activity and sleep for a few days, and VitalU will pick reads that match your habits here.', style: T.bodyMd)),
                  ]),
                )
              : ListGroup(header: 'Picked for you', dividerIndent: Sp.md + 64 + 12, children: [for (final p in picks) ArticleRow(p.$2, reason: p.$1.reason, hero: false, onTap: () => _open(p.$2))]),
        if (!_loading && articles.isNotEmpty) ListGroup(header: 'Topics in this category', dividerIndent: Sp.md + 64 + 12, children: [for (final a in articles) ArticleRow(a, onTap: () => _open(a))]),
        if (!_loading && articles.isEmpty && t.key != 'habits') const EmptyState(icon: Symbols.auto_stories_rounded, title: 'New reads coming soon', text: 'Articles in this topic are being prepared.'),
        const PrivacyNote('General health education, not a diagnosis. Speak to a health professional about your own situation.'),
      ],
    );
  }
}
