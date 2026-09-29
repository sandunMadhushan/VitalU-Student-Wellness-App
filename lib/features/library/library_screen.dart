import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/app_state.dart';
import '../../data/repo.dart';
import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

/// Illustration used for an article, picked by slug then category.
String articleImage(Rec a) => switch (a['slug']) {
      'heart-rate-exam-stress' => 'heart_desk',
      'nourish-exam-season' => 'open_wellness_book',
      'heart-health-basics' => 'heart_pulse',
      'iron-deficiency' => 'nourishment_bowl',
      'hydration-2pm' || 'electrolytes-vs-water' => 'water_bottle',
      _ => switch (a['category']) {
          'heart' => 'heart_embrace',
          'nutrition' => 'healthy_plate',
          'sleep' => 'moon_cloud',
          'stress' => 'meditating_student',
          'womens' => 'lotus_moon',
          _ => 'study_desk_tea',
        },
    };

/// (background, foreground) tone for an article category.
(Color, Color) articleTone(String? category) => switch (category) {
      'heart' || 'womens' => (AppColors.secondaryFixed, AppColors.secondary),
      'nutrition' => (AppColors.primaryFixed, AppColors.primary),
      'sleep' => (AppColors.primaryFixed, AppColors.onPrimaryFixedVariant),
      'stress' => (AppColors.tertiaryFixed, AppColors.tertiary),
      _ => (AppColors.surfaceContainerHighest, AppColors.onPrimaryFixedVariant),
    };

const libraryTopics = [
  ('all', '', 'All For You'),
  ('heart', '❤️', 'Heart Health'),
  ('nutrition', '🥗', 'Nutrition'),
  ('sleep', '🌙', 'Sleep'),
  ('stress', '🧘', 'Stress'),
  ('womens', '🌸', "Women's Health"),
  ('common', '💡', 'Common Concerns'),
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
      if (mounted) toast(context, on ? 'Saved to your library' : 'Removed from saved');
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
              Text('Search the library', style: T.headlineMd),
              const SizedBox(height: Sp.sm),
              VTextField(controller: q, hint: 'Try "sleep", "iron" or "stress"', icon: Symbols.search, onChanged: (_) => set(() {})),
              const SizedBox(height: Sp.sm),
              Expanded(
                child: hits.isEmpty
                    ? const EmptyState(icon: Symbols.search_off, title: 'No matches yet', text: 'Try a different word.')
                    : ListView.separated(
                        itemCount: hits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _row(hits[i], onTap: () {
                          Navigator.pop(ctx);
                          _open(hits[i]);
                        }),
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
      header: const MainHeader('VitalU Health Education Library'),
      nav: NavTab.library,
      navVariantLibrary: true,
      spacing: Sp.lg - 4,
      onRefresh: _load,
      children: [
        Row(children: [
          CircleButton(Symbols.arrow_back, size: 40, iconSize: 20, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, shadow: Shadows.tiny, onTap: () => goBack(context)),
          const Spacer(),
          Pressable(
            onTap: () => setState(() => _savedOnly = !_savedOnly),
            child: Pill(
              color: _savedOnly ? AppColors.secondary : AppColors.secondaryFixed,
              shadow: Shadows.tiny,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Symbols.bookmark, size: 16, fill: 1, color: _savedOnly ? AppColors.onSecondary : AppColors.onSecondaryFixed),
                const SizedBox(width: 6),
                Text('${_saved.length} Saved', style: T.labelSm.c(_savedOnly ? AppColors.onSecondary : AppColors.onSecondaryFixed)),
              ]),
            ),
          ),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Health Education', style: T.headlineLg),
          const SizedBox(height: 4),
          Text(_savedOnly ? 'Your saved reads' : 'Short reads, just for you', style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Pill(color: AppColors.surfaceContainerHigh, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), child: Text('📚 Evidence-based • 2–4 min bites', style: T.labelSm.c(AppColors.onSurfaceVariant))),
        ]),
        FullBleed(
          child: ChipRow(children: [
            for (final t in libraryTopics)
              Pressable(
                onTap: () => setState(() => _topic = t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: _topic == t.$1 ? AppColors.primary : AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(Rad.full),
                    boxShadow: _topic == t.$1 ? Shadows.tiny : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (t.$1 == 'all') Icon(Symbols.arrow_back_ios_new, size: 14, color: _topic == t.$1 ? AppColors.onPrimary : AppColors.onSurfaceVariant) else Text(t.$2),
                    const SizedBox(width: 6),
                    Text(t.$3, style: T.labelMd.c(_topic == t.$1 ? AppColors.onPrimary : AppColors.onSurfaceVariant)),
                  ]),
                ),
              ),
          ]),
        ),
        if (_loading) const Loading(),
        if (!_loading && visible.isEmpty)
          EmptyState(
            icon: _savedOnly ? Symbols.bookmark : Symbols.menu_book,
            title: _savedOnly ? 'Nothing saved yet' : 'No reads in this topic yet',
            text: _savedOnly ? 'Tap the bookmark on any article to keep it here.' : 'Check back soon — new bites are added regularly.',
          ),
        if (featured != null) _featured(featured),
        if (rec.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Recommended for you', style: T.headlineSm)),
              GestureDetector(onTap: _search, child: Text('See All', style: T.labelMd.c(AppColors.primary))),
            ]),
            const SizedBox(height: Sp.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(children: [
                for (final a in rec) ...[_recCard(a), const SizedBox(width: 14)],
              ]),
            ),
          ]),
        if (explore.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Explore Bite-Sized Reads', style: T.headlineSm)),
              Text('Updated today', style: T.labelSm.c(AppColors.onSurfaceVariant).w(FontWeight.w400)),
            ]),
            const SizedBox(height: Sp.sm),
            for (final a in explore) Padding(padding: const EdgeInsets.only(bottom: 10), child: _row(a, onTap: () => _open(a))),
          ]),
        VCard(
          shadow: Shadows.card,
          onTap: () => context.push('/blood-report'),
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const SizedBox(width: 64, height: 64, child: AssetImg('lab_report', radius: 32)),
            const SizedBox(width: Sp.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('CAMPUS HEALTH COMPANION', style: T.labelSm.c(AppColors.tertiary).tracking(0.6)),
                Text('Understand Your Blood Report', style: T.labelLg),
                Text('Plain-English insights for routine lab panels', style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Icon(Symbols.chevron_right, color: AppColors.outlineVariant),
          ]),
        ),
        VCard(
          color: AppColors.primaryFixed,
          shadow: Shadows.tiny,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              IconCircle(Symbols.support_agent, size: 40, iconSize: 22, shadow: Shadows.tiny),
              const SizedBox(width: Sp.sm),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Have questions about your health?', style: T.headlineSm.c(AppColors.onPrimaryFixed).lh(1.25)),
                  const SizedBox(height: 2),
                  Text('Campus nurses and wellness peer guides are available for confidential consultations.', style: T.bodySm.c(AppColors.onPrimaryFixedVariant)),
                ]),
              ),
            ]),
            const SizedBox(height: Sp.sm),
            Row(children: [
              Expanded(child: PrimaryButton('Ask Health Center', leadingIcon: Symbols.chat, height: 44, textStyle: T.labelMd.c(AppColors.onPrimary), onTap: () => context.push('/professionals'))),
              const SizedBox(width: 8),
              SoftButton('Search', icon: Symbols.search, height: 44, expand: false, color: AppColors.surfaceContainerLowest, style: T.labelMd, onTap: _search),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _bookmarkBtn(Rec a, {double size = 32, Color? bg}) {
    final bg0 = bg ?? AppColors.surfaceContainerLowest;
    final on = _saved.contains(a['id']);
    return GestureDetector(
      onTap: () => _toggle(a),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg0, shape: BoxShape.circle, boxShadow: bg0 == Colors.transparent ? null : Shadows.tiny),
        child: Icon(Symbols.bookmark, size: size * 0.5, fill: on ? 1 : 0, color: on ? AppColors.primary : AppColors.onSurfaceVariant),
      ),
    );
  }

  Widget _featured(Rec a) => Pressable(
        onTap: () => _open(a),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.lg), boxShadow: Shadows.tiny),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              height: 208,
              child: Stack(fit: StackFit.expand, children: [
                AssetImg(articleImage(a)),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [AppColors.surfaceContainerLow, Colors.transparent, Color(0x33000000)],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Pill(
                    color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
                    child: Text(a['badge'] ?? '${a['emoji'] ?? '🌿'} ${a['category_label']}', style: T.labelSm.c(AppColors.tertiary)),
                  ),
                ),
                Positioned(top: 12, right: 12, child: _bookmarkBtn(a, size: 36, bg: AppColors.surfaceContainerLowest.withValues(alpha: 0.9))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(Sp.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Symbols.schedule, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Flexible(child: Text('${a['read_minutes']} min read • ${a['category_label']}', style: T.labelSm.c(AppColors.primary))),
                ]),
                const SizedBox(height: 8),
                Text(a['title'], style: T.headlineMd.lh(1.3)),
                const SizedBox(height: 8),
                Text(a['subtitle'] ?? '', style: T.bodySm.c(AppColors.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: Sp.sm),
                Row(children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.primaryFixed, shape: BoxShape.circle),
                    child: Text('VU', style: T.labelSm.s(10).bold.c(AppColors.onPrimaryFixed)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a['author'] ?? 'VitalU', style: T.labelSm.c(AppColors.onSurfaceVariant))),
                  Icon(Symbols.arrow_forward, size: 20, color: AppColors.primary),
                ]),
              ]),
            ),
          ]),
        ),
      );

  Widget _recCard(Rec a) {
    final (bg, fg) = articleTone(a['category']);
    return Pressable(
      onTap: () => _open(a),
      child: Container(
        width: 240,
        height: 196,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(Rad.lg), boxShadow: Shadows.tiny),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle, boxShadow: Shadows.tiny),
              child: Text(a['emoji'] ?? '📘', style: const TextStyle(fontSize: 18)),
            ),
            const Spacer(),
            _bookmarkBtn(a),
          ]),
          const SizedBox(height: 10),
          Pill(color: bg.withValues(alpha: 0.6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2), child: Text(a['category_label'] ?? '', style: T.labelSm.c(fg))),
          const SizedBox(height: 8),
          Text(a['title'], style: T.headlineSm.s(16).lh(1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
          const Spacer(),
          Row(children: [
            Text('⏱️ ${a['read_minutes']} min read', style: T.labelSm.c(AppColors.onSurfaceVariant).w(FontWeight.w500)),
            const Spacer(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(a['author'] ?? '', style: T.labelSm.c(AppColors.onSurfaceVariant).w(FontWeight.w500), overflow: TextOverflow.ellipsis),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _row(Rec a, {VoidCallback? onTap}) {
    final (bg, fg) = articleTone(a['category']);
    return VCard(
      padding: const EdgeInsets.all(14),
      shadow: Shadows.tiny,
      onTap: onTap,
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle, boxShadow: Shadows.tiny),
          child: Text(a['emoji'] ?? '📘', style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a['title'], style: T.labelLg.s(14), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(a['subtitle'] ?? '', style: T.bodySm.s(12).c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Flexible(child: Text(a['category_label'] ?? '', style: T.labelSm.c(fg).w(FontWeight.w500), overflow: TextOverflow.ellipsis)),
              Text('  •  ', style: T.labelSm.s(10).c(AppColors.outline)),
              Text('${a['read_minutes']} min read', style: T.labelSm.c(AppColors.onSurfaceVariant).w(FontWeight.w500)),
            ]),
          ]),
        ),
        _bookmarkBtn(a, bg: Colors.transparent),
      ]),
    );
  }
}
