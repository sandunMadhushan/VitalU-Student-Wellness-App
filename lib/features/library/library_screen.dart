import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Icon and colour for an article category.
(IconData, Color) articleStyle(String? category) => switch (category) {
      'heart' => (Symbols.cardiology_rounded, AppColors.heart),
      'nutrition' => (Symbols.restaurant_rounded, AppColors.nutrition),
      'sleep' => (Symbols.bedtime_rounded, AppColors.sleep),
      'stress' => (Symbols.self_improvement_rounded, AppColors.mind),
      'womens' => (Symbols.menstrual_health_rounded, AppColors.cycle),
      _ => (Symbols.healing_rounded, AppColors.body),
    };

/// Cover illustration for an article, bundled under assets/articles by slug.
/// Articles without one fall back to their category colour and icon.
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/articles/${article['slug']}.webp',
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}

const libraryTopics = [
  ('all', 'All'),
  ('heart', 'Heart'),
  ('nutrition', 'Nutrition'),
  ('sleep', 'Sleep'),
  ('stress', 'Stress'),
  ('womens', "Women's health"),
  ('common', 'Common concerns'),
];

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _loading = true;
  List<Rec> _all = [];
  Set<String> _saved = {};
  String _topic = 'all';
  bool _savedOnly = false;

  /// List thumbnail size, and the divider inset that lines up with its text.
  static const _thumb = 64.0;
  static const _rowIndent = Sp.md + _thumb + 12;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait([Repo.articles(), Repo.bookmarkIds()]);
      _all = r[0] as List<Rec>;
      _saved = r[1] as Set<String>;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(Rec a) async {
    final id = a['id'] as String;
    final on = !_saved.contains(id);
    setState(() => on ? _saved.add(id) : _saved.remove(id));
    try {
      await Repo.setBookmark(id, on);
      if (mounted) toast(context, on ? 'Saved' : 'Removed from saved');
    } catch (_) {
      setState(() => on ? _saved.remove(id) : _saved.add(id));
    }
  }

  Future<void> _open(Rec a) async {
    await context.push('/library/article/${a['slug']}');
    _load();
  }

  bool _inTopic(Rec a) => _topic == 'all' || a['category'] == _topic || (a['tags'] as List? ?? []).contains(_topic);

  List<Rec> get _recommended {
    final conds = AppState.instance.profile?.conditions ?? const <String>[];
    return _all.where((a) {
      if (a['is_featured'] == true) return false;
      final c = List<String>.from(a['conditions'] ?? const []);
      return a['is_recommended'] == true || c.any(conds.contains);
    }).toList();
  }

  Future<void> _search() async {
    final q = TextEditingController();
    await showVSheet(context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
          final term = q.text.trim().toLowerCase();
          final hits = _all
              .where((a) => term.isEmpty || '${a['title']} ${a['subtitle']} ${a['category_label']} ${(a['tags'] as List? ?? []).join(' ')}'.toLowerCase().contains(term))
              .toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              VTextField(controller: q, hint: 'Search articles', icon: Symbols.search_rounded, onChanged: (_) => set(() {})),
              const SizedBox(height: Sp.md),
              Expanded(
                child: hits.isEmpty
                    ? const EmptyState(icon: Symbols.search_off_rounded, title: 'No matches', text: 'Try "sleep", "iron" or "stress".')
                    : SingleChildScrollView(
                        child: ListGroup(dividerIndent: _rowIndent, children: [
                          for (final a in hits)
                            _row(a, hero: false, onTap: () {
                              Navigator.pop(ctx);
                              _open(a);
                            }),
                        ]),
                      ),
              ),
            ]),
          );
        }));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _all.where(_inTopic).where((a) => !_savedOnly || _saved.contains(a['id'])).toList();
    final featured = visible.where((a) => a['is_featured'] == true).firstOrNull ?? (_topic == 'all' && !_savedOnly ? null : visible.firstOrNull);
    final rec = _recommended.where(_inTopic).where((a) => !_savedOnly || _saved.contains(a['id'])).where((a) => a != featured).toList();
    final explore = visible.where((a) => a != featured && !rec.contains(a)).toList();

    return VPage(
      header: const MainHeader('Learn'),
      nav: NavTab.library,
      topPadding: 0,
      onRefresh: _load,
      children: [
        Row(children: [
          Expanded(child: _searchField()),
          const SizedBox(width: Sp.sm),
          _savedToggle(),
        ]),
        FullBleed(
          child: ChipRow(children: [
            for (final t in libraryTopics) VChip(t.$2, selected: _topic == t.$1, onTap: () => setState(() => _topic = t.$1)),
          ]),
        ),
        if (_loading) const Loading(),
        if (!_loading && visible.isEmpty)
          EmptyState(
            icon: _savedOnly ? Symbols.bookmark_rounded : Symbols.auto_stories_rounded,
            title: _savedOnly ? 'Nothing saved yet' : 'No articles in this topic yet',
            text: _savedOnly ? 'Tap the bookmark on any article to keep it here.' : 'New articles are added regularly.',
          ),
        if (featured != null) _featured(featured),
        if (rec.isNotEmpty) ListGroup(header: 'Recommended for you', dividerIndent: _rowIndent, children: [for (final a in rec) _row(a, onTap: () => _open(a))]),
        if (explore.isNotEmpty)
          ListGroup(
            header: rec.isEmpty && featured == null ? null : 'More articles',
            dividerIndent: _rowIndent,
            children: [for (final a in explore) _row(a, onTap: () => _open(a))],
          ),
        ListGroup(header: 'Get help', children: [
          ListRow(icon: Symbols.bloodtype_rounded, color: AppColors.heart, title: 'Understand a blood report', subtitle: 'Plain-language notes on common lab values', onTap: () => context.push('/blood-report')),
          ListRow(icon: Symbols.stethoscope_rounded, color: AppColors.primary, title: 'Talk to a professional', subtitle: 'Campus medical officers and counsellors', onTap: () => context.push('/professionals')),
        ]),
      ],
    );
  }

  Widget _searchField() => Semantics(
        button: true,
        label: 'Search articles',
        child: Pressable(
          onTap: _search,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(Rad.full)),
            child: Row(children: [
              Icon(Symbols.search_rounded, size: 20, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: ExcludeSemantics(
                  child: Text('Search sleep, iron, stress…', style: T.bodyMd.c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ),
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

  Widget _bookmark(Rec a) {
    final on = _saved.contains(a['id']);
    return IconButton(
      tooltip: on ? 'Remove from saved' : 'Save',
      icon: Icon(Symbols.bookmark_rounded, fill: on ? 1 : 0, color: on ? AppColors.primary : AppColors.onSurfaceVariant),
      onPressed: () => _toggle(a),
    );
  }

  Widget _featured(Rec a) {
    final (_, c) = articleStyle(a['category']);
    return VCard(
      onTap: () => _open(a),
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            Hero(tag: 'article-cover-${a['slug']}', child: ArticleCover(a, iconSize: 48)),
            if (a['is_featured'] == true)
              Positioned(
                left: 12,
                top: 12,
                child: TagPill('Featured', icon: Symbols.star_rounded, fill: 1, bg: Colors.white.withValues(alpha: 0.92), fg: const Color(0xFF1D1F23), iconColor: AppColors.warning),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Sp.md, 14, 4, Sp.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${a['category_label'] ?? 'Featured'} · ${a['read_minutes']} min read', style: T.labelMd.c(c)),
                const SizedBox(height: 6),
                Text(a['title'], style: T.headlineMd.lh(1.25)),
                if (a['subtitle'] != null) ...[
                  const SizedBox(height: 6),
                  Text(a['subtitle'], style: T.bodyMd.c(AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Text(a['author'] ?? 'VitalU', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ),
            _bookmark(a),
          ]),
        ),
      ]),
    );
  }

  Widget _row(Rec a, {VoidCallback? onTap, bool hero = true}) {
    final (icon, c) = articleStyle(a['category']);
    Widget thumb = ArticleCover(a, width: _thumb, height: _thumb, radius: 12, iconSize: 26, cacheWidth: (_thumb * 2 * MediaQuery.devicePixelRatioOf(context)).round());
    if (hero) thumb = Hero(tag: 'article-cover-${a['slug']}', child: thumb);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 12, 4, 12),
        child: Row(children: [
          thumb,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['title'], style: T.bodyLg.semi.lh(1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                Icon(icon, size: 14, color: c, fill: 1),
                const SizedBox(width: 4),
                Flexible(child: Text(a['category_label'] ?? '', style: T.bodySm.semi.c(c), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text('  ·  ${a['read_minutes']} min', style: T.bodySm.c(AppColors.onSurfaceVariant)),
              ]),
            ]),
          ),
          _bookmark(a),
        ]),
      ),
    );
  }
}
