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
      'nutrition' => (Symbols.nutrition_rounded, AppColors.nutrition),
      'sleep' => (Symbols.bedtime_rounded, AppColors.sleep),
      'stress' => (Symbols.self_improvement_rounded, AppColors.mind),
      'womens' => (Symbols.female_rounded, AppColors.cycle),
      _ => (Symbols.lightbulb_rounded, AppColors.warning),
    };

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
                        child: ListGroup(dividerIndent: 64, children: [
                          for (final a in hits)
                            _row(a, onTap: () {
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
          Expanded(child: Text(_savedOnly ? 'Your saved articles' : 'Short reads on health and student life', style: T.bodyMd.c(AppColors.onSurfaceVariant))),
          IconButton(tooltip: 'Search', icon: const Icon(Symbols.search_rounded), onPressed: _search),
          IconButton(
            tooltip: _savedOnly ? 'Show all articles' : 'Show saved',
            isSelected: _savedOnly,
            icon: const Icon(Symbols.bookmarks_rounded),
            selectedIcon: Icon(Symbols.bookmarks_rounded, fill: 1, color: AppColors.primary),
            onPressed: () => setState(() => _savedOnly = !_savedOnly),
          ),
        ]),
        FullBleed(
          child: ChipRow(children: [
            for (final t in libraryTopics) VChip(t.$2, selected: _topic == t.$1, onTap: () => setState(() => _topic = t.$1)),
          ]),
        ),
        if (_loading) const Loading(),
        if (!_loading && visible.isEmpty)
          EmptyState(
            icon: _savedOnly ? Symbols.bookmark_rounded : Symbols.menu_book_rounded,
            title: _savedOnly ? 'Nothing saved yet' : 'No articles in this topic yet',
            text: _savedOnly ? 'Tap the bookmark on any article to keep it here.' : 'New articles are added regularly.',
          ),
        if (featured != null) _featured(featured),
        if (rec.isNotEmpty) ListGroup(header: 'Recommended for you', dividerIndent: 64, children: [for (final a in rec) _row(a, onTap: () => _open(a))]),
        if (explore.isNotEmpty) ListGroup(header: rec.isEmpty && featured == null ? null : 'More articles', dividerIndent: 64, children: [for (final a in explore) _row(a, onTap: () => _open(a))]),
        ListGroup(header: 'Get help', children: [
          ListRow(icon: Symbols.lab_profile_rounded, color: AppColors.heart, title: 'Understand a blood report', subtitle: 'Plain-language notes on common lab values', onTap: () => context.push('/blood-report')),
          ListRow(icon: Symbols.stethoscope_rounded, color: AppColors.primary, title: 'Talk to a professional', subtitle: 'Campus medical officers and counsellors', onTap: () => context.push('/professionals')),
        ]),
      ],
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
    final (icon, c) = articleStyle(a['category']);
    return VCard(
      onTap: () => _open(a),
      padding: EdgeInsets.zero,
      clip: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 112,
          color: AppColors.tint(c),
          alignment: Alignment.center,
          child: Icon(icon, size: 48, color: c, fill: 1),
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

  Widget _row(Rec a, {VoidCallback? onTap}) {
    final (icon, c) = articleStyle(a['category']);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.md, 12, 4, 12),
        child: Row(children: [
          IconCircle(icon, size: 36, iconSize: 20, fg: c, radius: 10, fill: 1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a['title'], style: T.bodyLg, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('${a['category_label'] ?? ''} · ${a['read_minutes']} min', style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          _bookmark(a),
        ]),
      ),
    );
  }
}
