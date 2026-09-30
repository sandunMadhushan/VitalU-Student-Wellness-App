import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/app_state.dart';
import 'text.dart';
import 'tokens.dart';

// ---------------------------------------------------------------------------
// Images
// ---------------------------------------------------------------------------

class Img {
  Img._();
  static String p(String name) => 'assets/images/$name.png';
}

/// The app icon presented as a rounded tile, like on a home screen.
class AppIconTile extends StatelessWidget {
  const AppIconTile({super.key, this.size = 52});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.23),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Image.asset(Img.p('app_icon'), fit: BoxFit.cover),
      );
}

/// Circular avatar of the signed-in student (uploaded photo, or a gender
/// placeholder icon when none has been uploaded yet).
class Avatar extends StatelessWidget {
  const Avatar({super.key, this.size = 32, this.ring = true, this.onTap});
  final double size;
  final bool ring;
  final VoidCallback? onTap;

  Widget _placeholder() {
    final isFemale = AppState.instance.profile?.isFemale ?? false;
    final c = isFemale ? AppColors.cycle : AppColors.water;
    return Container(
      width: size,
      height: size,
      color: AppColors.tint(c),
      alignment: Alignment.center,
      child: Icon(isFemale ? Symbols.woman_rounded : Symbols.man_rounded, size: size * 0.6, color: c, fill: 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = AppState.instance.profile?.avatarUrl;
    final child = ClipOval(
      child: url != null && url.isNotEmpty
          ? Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder())
          : _placeholder(),
    );
    return GestureDetector(
      onTap: onTap ?? () => context.push('/profile'),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, border: ring ? Border.all(color: AppColors.outlineVariant, width: 1) : null),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Containers
// ---------------------------------------------------------------------------

/// Content card. Light mode lifts it off the grey ground with a soft two-layer
/// shadow; dark mode separates it with a faint hairline instead.
class VCard extends StatelessWidget {
  const VCard({
    super.key,
    required this.child,
    this.color,
    this.radius = Rad.lg,
    this.padding = const EdgeInsets.all(Sp.md),
    this.shadow,
    this.gradient,
    this.border,
    this.onTap,
    this.margin,
    this.clip = false,
    this.flat = false,
  });
  final Widget child;
  final Color? color;
  final double radius;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow>? shadow;
  final Gradient? gradient;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final bool clip;

  /// Skip the elevation, e.g. for tinted callouts.
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final raised = !flat && color == null && gradient == null;
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) content = InkWell(onTap: onTap, child: content);
    if (gradient != null) content = Ink(decoration: BoxDecoration(gradient: gradient, borderRadius: r), child: content);
    final side = border is Border
        ? (border as Border).top
        : (raised && AppColors.isDark ? BorderSide(color: Colors.white.withValues(alpha: 0.06)) : BorderSide.none);
    Widget card = Material(
      color: gradient == null ? (color ?? AppColors.surfaceContainerLowest) : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: r, side: side),
      clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
      child: content,
    );
    if (raised && !AppColors.isDark) {
      card = DecoratedBox(decoration: BoxDecoration(borderRadius: r, boxShadow: shadow ?? Shadows.card), child: card);
    }
    if (margin != null) card = Padding(padding: margin!, child: card);
    return card;
  }
}

/// Icon on a soft tinted disc. Pass [radius] for a rounded square instead.
class IconCircle extends StatelessWidget {
  const IconCircle(this.icon, {super.key, this.size = 40, this.iconSize = 20, this.bg, this.fg, this.fill = 0, this.shadow, this.radius});
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? bg;
  final Color? fg;
  final double fill;
  final List<BoxShadow>? shadow;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final fg0 = fg ?? AppColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? AppColors.tint(fg0),
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius == null ? null : BorderRadius.circular(radius!),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: fg0, fill: fill),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.child, this.color, this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4), this.border, this.shadow});
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color ?? AppColors.surfaceContainer, borderRadius: BorderRadius.circular(Rad.full), border: border),
        child: child,
      );
}

/// Small status badge with an optional icon.
class TagPill extends StatelessWidget {
  const TagPill(this.label, {super.key, this.icon, this.bg, this.fg, this.iconColor, this.upper = false, this.fill = 0});
  final String label;
  final IconData? icon;
  final Color? bg;
  final Color? fg;
  final Color? iconColor;
  final bool upper;
  final double fill;
  @override
  Widget build(BuildContext context) {
    final fg0 = fg ?? AppColors.onSurfaceVariant;
    return Pill(
      color: bg ?? AppColors.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: iconColor ?? fg0, fill: fill), const SizedBox(width: 4)],
        Flexible(child: Text(label, style: T.labelSm.c(fg0), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.98});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 120), curve: Curves.easeOut, child: widget.child),
    );
  }
}

/// Filled primary action.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, this.onTap, this.icon, this.leadingIcon, this.color, this.fg, this.height = 52, this.loading = false, this.shadowColor, this.expand = true, this.textStyle});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? leadingIcon;
  final Color? color;
  final Color? fg;
  final double height;
  final bool loading;
  final Color? shadowColor;
  final bool expand;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? AppColors.primary;
    final fg0 = fg ?? (color == null ? AppColors.onPrimary : Colors.white);
    final btn = FilledButton(
      onPressed: loading ? () {} : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg0,
        disabledBackgroundColor: AppColors.surfaceContainerHigh,
        disabledForegroundColor: AppColors.outline,
        minimumSize: Size(expand ? double.infinity : 64, height),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: textStyle ?? T.labelLg.semi,
      ),
      child: loading
          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg0))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (leadingIcon != null) ...[Icon(leadingIcon, size: 20), const SizedBox(width: 8)],
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
              if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 20)],
            ]),
    );
    return btn;
  }
}

/// Secondary action on a neutral tonal fill.
class SoftButton extends StatelessWidget {
  const SoftButton(this.label, {super.key, this.onTap, this.icon, this.trailingIcon, this.color, this.fg, this.iconColor, this.height = 48, this.border, this.expand = true, this.style});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color? color;
  final Color? fg;
  final Color? iconColor;
  final double height;
  final BoxBorder? border;
  final bool expand;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final fg0 = fg ?? AppColors.onSurface;
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color ?? AppColors.surfaceContainer,
        foregroundColor: fg0,
        minimumSize: Size(expand ? double.infinity : 48, height),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        textStyle: style ?? T.labelLg.semi,
        side: border is Border ? (border as Border).top : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 20, color: iconColor ?? fg0), const SizedBox(width: 8)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (trailingIcon != null) ...[const SizedBox(width: 6), Icon(trailingIcon, size: 18, color: iconColor ?? fg0)],
      ]),
    );
  }
}

class TextLinkButton extends StatelessWidget {
  const TextLinkButton(this.label, {super.key, this.onTap, this.icon, this.color, this.leading});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? leading;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final color0 = color ?? AppColors.primary;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(foregroundColor: color0, padding: const EdgeInsets.symmetric(horizontal: 12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (leading != null) ...[Icon(leading, size: 18), const SizedBox(width: 6)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (icon != null) ...[const SizedBox(width: 4), Icon(icon, size: 18)],
      ]),
    );
  }
}

/// Icon-only button with a 44px+ touch target.
class CircleButton extends StatelessWidget {
  const CircleButton(this.icon, {super.key, this.onTap, this.size = 44, this.bg = Colors.transparent, this.fg, this.iconSize = 24, this.shadow, this.badge = false});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color bg;
  final Color? fg;
  final double iconSize;
  final List<BoxShadow>? shadow;
  final bool badge;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: math.max(size, 44),
        height: math.max(size, 44),
        child: Center(
          child: Material(
            color: bg,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: Badge(
                    isLabelVisible: badge,
                    smallSize: 8,
                    backgroundColor: AppColors.error,
                    child: Icon(icon, size: iconSize, color: fg ?? AppColors.onSurface),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// Pill filter chip: outlined when idle, solid in the accent when selected.
class VChip extends StatelessWidget {
  const VChip(this.label, {super.key, this.selected = false, this.onTap, this.icon, this.emoji, this.selectedColor, this.selectedFg, this.color, this.fg, this.height = 36});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? emoji;
  final Color? selectedColor;
  final Color? selectedFg;
  final Color? color;
  final Color? fg;
  final double height;

  @override
  Widget build(BuildContext context) {
    final accent = selectedColor ?? AppColors.onSurface;
    final onAccent = selectedFg ?? (AppColors.isDark ? AppColors.surface : Colors.white);
    final c = selected ? onAccent : (fg ?? AppColors.onSurface);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: ShapeDecoration(
        color: selected ? accent : (color ?? AppColors.surfaceContainerLowest),
        shape: StadiumBorder(side: BorderSide(color: selected ? accent : AppColors.outlineVariant)),
      ),
      child: Material(
        type: MaterialType.transparency,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 17, color: c, fill: selected ? 1 : 0), const SizedBox(width: 6)],
              Flexible(child: Text(label, style: T.labelMd.c(c), overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ),
      ),
    );
  }
}

class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: Sp.margin)});
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        child: Row(children: [for (int i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 8), children[i]]]),
      );
}

// ---------------------------------------------------------------------------
// Progress
// ---------------------------------------------------------------------------

class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, this.size = 56, this.stroke = 6, this.color, this.track, this.child, this.gradient});
  final double value;
  final double size;
  final double stroke;
  final Color? color;
  final Color? track;
  final Widget? child;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => CustomPaint(
          painter: _RingPainter(v, stroke, c, track ?? c.withValues(alpha: AppColors.isDark ? 0.22 : 0.16)),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.color, this.track);
  final double v;
  final double stroke;
  final Color color;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final r = (math.min(size.width, size.height) - stroke) / 2;
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track);
    if (v <= 0) return;
    canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * v,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v || old.color != color || old.track != track;
}

class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.height = 6, this.color, this.track, this.gradient});
  final double value;
  final double height;
  final Color? color;
  final Color? track;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          color: c,
          backgroundColor: track ?? c.withValues(alpha: AppColors.isDark ? 0.2 : 0.14),
        ),
      ),
    );
  }
}

/// Standard Material slider tinted with [color].
class VSlider extends StatelessWidget {
  const VSlider({super.key, required this.value, required this.min, required this.max, required this.onChanged, this.divisions, this.color});
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: c,
        thumbColor: c,
        inactiveTrackColor: c.withValues(alpha: 0.18),
        overlayColor: c.withValues(alpha: 0.12),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
      ),
      child: Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
    );
  }
}

// ---------------------------------------------------------------------------
// Page scaffold, app bars & bottom navigation
// ---------------------------------------------------------------------------

enum NavTab { home, tools, diet, progress, library, profile }

/// Page shell: an app bar from [header], a padded list of [children], an
/// optional sticky [bottom] action and the tab bar when [nav] is set.
class VPage extends StatelessWidget {
  const VPage({
    super.key,
    required this.children,
    this.header,
    this.nav,
    this.navVariantLibrary = false,
    this.padding = const EdgeInsets.symmetric(horizontal: Sp.margin),
    this.bottom,
    this.background,
    this.spacing = Sp.md,
    this.onRefresh,
    this.backgroundDecoration,
    this.topPadding,
  });

  final List<Widget> children;
  final Widget? header;
  final NavTab? nav;
  final bool navVariantLibrary;
  final EdgeInsetsGeometry padding;
  final Widget? bottom;
  final Color? background;
  final double spacing;
  final Future<void> Function()? onRefresh;
  final Decoration? backgroundDecoration;
  final double? topPadding;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final showNav = nav != null && nav != NavTab.library;
    final h = header;
    Widget scroll(BuildContext ctx) => CustomScrollView(physics: const AlwaysScrollableScrollPhysics(), slivers: [
          if (h is VHeader)
            h.sliver(ctx)
          else if (h != null)
            SliverToBoxAdapter(child: SafeArea(bottom: false, child: h))
          else
            SliverToBoxAdapter(child: SizedBox(height: mq.padding.top)),
          SliverPadding(
            // Inside the scaffold the bottom inset already covers the tab bar
            // (drawn over the content) or the sticky action.
            padding: EdgeInsets.only(top: topPadding ?? Sp.sm, bottom: Sp.xl + MediaQuery.paddingOf(ctx).bottom),
            sliver: SliverList.list(children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: spacing),
                children[i] is FullBleed ? children[i] : Padding(padding: padding, child: children[i]),
              ],
            ]),
          ),
        ]);
    Widget body = Builder(builder: scroll);
    if (onRefresh != null) body = RefreshIndicator(onRefresh: onRefresh!, edgeOffset: mq.padding.top + 56, child: body);
    if (backgroundDecoration != null) body = DecoratedBox(decoration: backgroundDecoration!, child: body);

    Widget? bottomBar;
    if (bottom != null || showNav) {
      bottomBar = Column(mainAxisSize: MainAxisSize.min, children: [
        if (bottom != null)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: showNav ? null : Border(top: BorderSide(color: AppColors.outlineVariant, width: 0.6)),
            ),
            padding: EdgeInsets.fromLTRB(Sp.margin, 12, Sp.margin, showNav ? 12 : 12 + mq.padding.bottom),
            child: bottom,
          ),
        if (showNav) BottomNav(current: nav!),
      ]);
    }
    return Scaffold(backgroundColor: background ?? AppColors.surface, extendBody: showNav, body: body, bottomNavigationBar: bottomBar);
  }
}

/// Marks a child that should ignore the page's horizontal padding.
class FullBleed extends StatelessWidget {
  const FullBleed({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

bool _isCupertino(BuildContext context) {
  final p = Theme.of(context).platform;
  return p == TargetPlatform.iOS || p == TargetPlatform.macOS;
}

/// Platform back icon: arrow on Android, chevron on iOS.
IconData backIcon(BuildContext context) => _isCupertino(context) ? Symbols.arrow_back_ios_new_rounded : Symbols.arrow_back_rounded;

/// App bar description used by [VPage]. Top-level tabs get a collapsing large
/// title; everything else a standard bar with back or close.
abstract class VHeader extends StatelessWidget {
  const VHeader({super.key});

  String get titleText;
  bool get large => false;
  bool get closeIcon => false;
  VoidCallback? get onLeading => null;
  bool get showLeading => true;
  List<Widget> actionsFor(BuildContext context) => const [];

  Widget? _leading(BuildContext context) => showLeading
      ? IconButton(
          icon: Icon(closeIcon ? Symbols.close_rounded : backIcon(context)),
          tooltip: closeIcon ? 'Close' : 'Back',
          onPressed: onLeading ?? () => goBack(context),
        )
      : null;

  Widget sliver(BuildContext context) {
    final actions = [...actionsFor(context), const SizedBox(width: 4)];
    if (large) {
      return SliverAppBar.large(
        pinned: true,
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(titleText),
        actions: actions,
      );
    }
    return SliverAppBar(
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      leading: _leading(context),
      title: Text(titleText, style: T.headlineSm),
      actions: actions,
    );
  }

  @override
  Widget build(BuildContext context) => AppBar(
        automaticallyImplyLeading: false,
        leading: large ? null : _leading(context),
        title: Text(titleText, style: large ? T.headlineLg : T.headlineSm),
        actions: actionsFor(context),
      );
}

List<Widget> _accountActions(BuildContext context) => [
      CircleButton(Symbols.notifications_rounded, onTap: () => context.push('/notifications'), badge: AppState.instance.unreadCount > 0),
      const SizedBox(width: 4),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Avatar(size: 32, ring: false)),
    ];

/// Top-level tab header: large collapsing title, notifications and avatar.
class MainHeader extends VHeader {
  const MainHeader(this.title, {super.key});
  final String title;
  @override
  String get titleText => title;
  @override
  bool get large => true;
  @override
  bool get showLeading => false;
  @override
  List<Widget> actionsFor(BuildContext context) => _accountActions(context);
}

/// Detail header with a back button and an optional title.
class BrandBackHeader extends VHeader {
  const BrandBackHeader({super.key, this.chip, this.onBack});
  final String? chip;
  final VoidCallback? onBack;
  @override
  String get titleText => chip ?? '';
  @override
  VoidCallback? get onLeading => onBack;
}

/// Back (or close) plus a title.
class TitleHeader extends VHeader {
  const TitleHeader(this.title, {super.key, this.close = false, this.upper = false, this.filledButton = false, this.onLeading, this.actions = const []});
  final String title;
  final bool close;
  final bool upper;
  final bool filledButton;
  final List<Widget> actions;
  @override
  final VoidCallback? onLeading;
  @override
  String get titleText => title;
  @override
  bool get closeIcon => close;
  @override
  List<Widget> actionsFor(BuildContext context) => actions;
}

/// Registration flow header.
class RegistrationHeader extends VHeader {
  const RegistrationHeader({super.key, this.title = 'Your profile', this.onBack});
  final String title;
  final VoidCallback? onBack;
  @override
  String get titleText => title;
  @override
  VoidCallback? get onLeading => onBack;
}

/// Close plus a title, for self-check flows.
class ConfidentialHeader extends VHeader {
  const ConfidentialHeader({super.key, this.onClose, this.label = 'Self-check'});
  final VoidCallback? onClose;
  final String label;
  @override
  String get titleText => label;
  @override
  bool get closeIcon => true;
  @override
  VoidCallback? get onLeading => onClose;
}

/// Large-title header; the kicker is dropped (headings stand on their own).
class TwoLineHeader extends VHeader {
  const TwoLineHeader({super.key, required this.kicker, required this.title});
  final String kicker;
  final String title;
  @override
  String get titleText => title;
  @override
  bool get large => true;
  @override
  bool get showLeading => false;
  @override
  List<Widget> actionsFor(BuildContext context) => _accountActions(context);
}

void goBack(BuildContext context, [String fallback = '/home']) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// In-page title row with a back button.
class BackTitleRow extends StatelessWidget {
  const BackTitleRow({super.key, required this.title, this.subtitle, this.trailing, this.onBack});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Row(children: [
        CircleButton(backIcon(context), onTap: onBack ?? () => goBack(context)),
        const SizedBox(width: Sp.xs),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.headlineMd, overflow: TextOverflow.ellipsis),
            if (subtitle != null) Text(subtitle!, style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ]),
        ),
        ?trailing,
      ]);
}

//// Floating tab bar: a frosted-glass capsule that hovers above the content,
/// with a pill that slides to the active tab.
class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.current, this.library = false});
  final NavTab current;
  final bool library;

  static const height = 64.0;

  /// Tab shown by the previous page, so the pill can slide from it.
  static int _lastIndex = 0;

  static const _items = <(NavTab, IconData, String, String)>[
    (NavTab.home, Symbols.home_rounded, 'Home', '/home'),
    (NavTab.tools, Symbols.vital_signs_rounded, 'Tools', '/tools'),
    (NavTab.diet, Symbols.nutrition_rounded, 'Diet', '/diet'),
    (NavTab.progress, Symbols.monitoring_rounded, 'Progress', '/progress'),
    (NavTab.profile, Symbols.account_circle_rounded, 'Profile', '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    final index = _items.indexWhere((e) => e.$1 == current).clamp(0, _items.length - 1);
    final from = _lastIndex;
    _lastIndex = index;
    final dark = AppColors.isDark;
    final radius = BorderRadius.circular(height / 2);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, math.max(inset, 12) + 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.45 : 0.12), blurRadius: 30, offset: const Offset(0, 10), spreadRadius: -6),
            BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: Container(
              height: height,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                borderRadius: radius,
                color: dark ? const Color(0xFF1C1E22).withValues(alpha: 0.78) : Colors.white.withValues(alpha: 0.78),
                border: Border.all(color: dark ? Colors.white.withValues(alpha: 0.09) : Colors.black.withValues(alpha: 0.05), width: 0.8),
              ),
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth / _items.length;
                return Stack(children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: from.toDouble(), end: index.toDouble()),
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeOutBack,
                    builder: (_, v, _) => Positioned(
                      left: v * w,
                      top: 0,
                      bottom: 0,
                      width: w,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular((height - 10) / 2),
                          color: dark ? Colors.white.withValues(alpha: 0.10) : AppColors.primary.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                  ),
                  Row(children: [
                    for (int i = 0; i < _items.length; i++)
                      SizedBox(
                        width: w,
                        child: _NavItem(
                          icon: _items[i].$2,
                          label: _items[i].$3,
                          selected: i == index,
                          onTap: i == index ? null : () => context.go(_items[i].$4),
                        ),
                      ),
                  ]),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = selected ? AppColors.primary : AppColors.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: selected ? 1 : 0),
              duration: const Duration(milliseconds: 220),
              builder: (_, v, _) => Transform.scale(
                scale: 1 + 0.06 * v,
                child: Icon(icon, size: 24, color: c, fill: v, weight: 400 + 150 * v),
              ),
            ),
            const SizedBox(height: 2),
            ExcludeSemantics(child: Text(label, style: T.labelSm.s(10.5).c(c).w(selected ? FontWeight.w700 : FontWeight.w600))),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lists, labels & metrics
// ---------------------------------------------------------------------------

/// Section title above a group of content.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing, this.style});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Sp.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: style ?? T.headlineMd),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: T.bodySm.c(AppColors.onSurfaceVariant))),
            ]),
          ),
          ?trailing,
        ]),
      );
}

/// Inset grouped list: rows on one card separated by hairlines.
class ListGroup extends StatelessWidget {
  const ListGroup({super.key, required this.children, this.header, this.footer, this.dividerIndent = 60});
  final List<Widget> children;
  final String? header;
  final String? footer;
  final double dividerIndent;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (header != null) Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(header!, style: T.labelMd.c(AppColors.onSurfaceVariant))),
        VCard(
          padding: EdgeInsets.zero,
          clip: true,
          child: Column(children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: dividerIndent),
              children[i],
            ],
          ]),
        ),
        if (footer != null) Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text(footer!, style: T.bodySm.c(AppColors.onSurfaceVariant))),
      ]);
}

/// One row in a [ListGroup]: category icon tile, title, optional detail.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.title, this.icon, this.color, this.subtitle, this.value, this.trailing, this.onTap, this.destructive = false, this.chevron = true});
  final String title;
  final IconData? icon;
  final Color? color;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;
  final bool chevron;
  @override
  Widget build(BuildContext context) {
    final c = destructive ? AppColors.error : (color ?? AppColors.primary);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.md, vertical: 10),
          child: Row(children: [
            if (icon != null) ...[IconCircle(icon!, size: 30, iconSize: 18, bg: c, fg: AppColors.isDark ? AppColors.surface : Colors.white, radius: 8, fill: 1), const SizedBox(width: 14)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(title, style: T.bodyLg.w(FontWeight.w600).c(destructive ? AppColors.error : AppColors.onSurface)),
                if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 1), child: Text(subtitle!, style: T.bodySm.c(AppColors.onSurfaceVariant))),
              ]),
            ),
            if (value != null) Padding(padding: const EdgeInsets.only(left: 8), child: Text(value!, style: T.bodyMd.c(AppColors.onSurfaceVariant))),
            ?trailing,
            if (trailing == null && onTap != null && chevron) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Symbols.chevron_right_rounded, size: 20, color: AppColors.outline)),
          ]),
        ),
      ),
    );
  }
}

/// Small coloured category label, e.g. "Water" with its icon.
class CategoryLabel extends StatelessWidget {
  const CategoryLabel(this.label, {super.key, required this.icon, required this.color, this.trailing});
  final String label;
  final IconData icon;
  final Color color;
  final String? trailing;
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 18, color: color, fill: 1),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: T.labelLg.semi.c(color), overflow: TextOverflow.ellipsis)),
        if (trailing != null) Text(trailing!, style: T.labelSm.c(AppColors.onSurfaceVariant)),
      ]);
}

/// Large number with a smaller unit, e.g. "1.8 L".
class MetricValue extends StatelessWidget {
  const MetricValue(this.value, {super.key, this.unit, this.size = 28, this.color});
  final String value;
  final String? unit;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(text: value, children: [
          if (unit != null) TextSpan(text: ' $unit', style: T.labelLg.c(AppColors.onSurfaceVariant).copyWith(fontWeight: FontWeight.w500)),
        ]),
        style: T.metric(size).c(color ?? AppColors.onSurface),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}

/// Dashboard tile: icon badge and label, a large value and caption, and a
/// progress ring in the category colour when there is a target.
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.icon, required this.color, required this.value, this.unit, this.caption, this.captionColor, this.progress, this.onTap, this.action});
  final String label;
  final IconData icon;
  final Color color;
  final String value;
  final String? unit;
  final String? caption;
  final Color? captionColor;
  final double? progress;
  final VoidCallback? onTap;
  final Widget? action;
  @override
  Widget build(BuildContext context) => VCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconCircle(icon, size: 30, iconSize: 17, fg: color, radius: 9, fill: 1),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: T.labelMd.c(AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (action != null)
              action!
            else if (progress != null)
              Ring(value: progress!, size: 28, stroke: 4, color: color),
          ]),
          const SizedBox(height: 16),
          MetricValue(value, unit: unit, size: 26),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: T.bodySm.c(captionColor ?? AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ]),
      );
}

/// Two-column grid whose rows share the height of their tallest tile.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.gap = 12});
  final List<Widget> children;
  final double gap;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (int i = 0; i < children.length; i += 2) ...[
          if (i > 0) SizedBox(height: gap),
          if (i + 1 < children.length)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(child: children[i]),
                SizedBox(width: gap),
                Expanded(child: children[i + 1]),
              ]),
            )
          else
            children[i],
        ],
      ]);
}

class PrivacyNote extends StatelessWidget {
  const PrivacyNote(this.text, {super.key, this.icon = Symbols.lock_rounded, this.center = true});
  final String text;
  final IconData icon;
  final bool center;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 14, color: AppColors.onSurfaceVariant)),
          const SizedBox(width: 6),
          Flexible(child: Text(text, textAlign: center ? TextAlign.center : TextAlign.start, style: T.bodySm.c(AppColors.onSurfaceVariant))),
        ],
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.text, this.action});
  final IconData icon;
  final String title;
  final String? text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => VCard(
        padding: const EdgeInsets.symmetric(horizontal: Sp.lg, vertical: Sp.lg),
        child: Column(children: [
          Icon(icon, size: 32, color: AppColors.outline),
          const SizedBox(height: Sp.sm),
          Text(title, style: T.headlineSm, textAlign: TextAlign.center),
          if (text != null) ...[const SizedBox(height: 4), Text(text!, style: T.bodyMd.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center)],
          if (action != null) ...[const SizedBox(height: Sp.md), action!],
        ]),
      );
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        if (error) ...[Icon(Symbols.error_rounded, size: 20, color: AppColors.inverseOnSurface), const SizedBox(width: 10)],
        Expanded(child: Text(msg)),
      ]),
    ));
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))),
      );
}

/// Modal bottom sheet with the platform drag handle.
Future<R?> showVSheet<R>(BuildContext context, {required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Padding(
        padding: EdgeInsets.fromLTRB(Sp.margin, 0, Sp.margin, MediaQuery.of(ctx).padding.bottom + Sp.md),
        child: SingleChildScrollView(child: builder(ctx)),
      ),
    ),
  );
}

class VTextField extends StatelessWidget {
  const VTextField({super.key, this.controller, this.hint, this.icon, this.keyboard, this.obscure = false, this.suffix, this.onChanged, this.maxLines = 1, this.validator, this.autofill, this.textInputAction, this.onSubmitted});
  final TextEditingController? controller;
  final String? hint;
  final IconData? icon;
  final TextInputType? keyboard;
  final bool obscure;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final String? Function(String?)? validator;
  final Iterable<String>? autofill;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      onChanged: onChanged,
      maxLines: maxLines,
      validator: validator,
      autofillHints: autofill,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      style: T.bodyLg,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon, color: AppColors.onSurfaceVariant, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}

/// Segmented control: a sliding thumb on a recessed track. Fills its width
/// under tight constraints, otherwise sizes every segment to the longest label.
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, this.small = true});
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final h = small ? 34.0 : 40.0;
    final idx = options.indexOf(value);
    final style = T.labelMd;
    return LayoutBuilder(builder: (context, c) {
      double segW;
      if (c.hasTightWidth) {
        segW = (c.maxWidth - 4) / options.length;
      } else {
        final scaler = MediaQuery.textScalerOf(context);
        final widest = options
            .map((o) => (TextPainter(text: TextSpan(text: o, style: style.w(FontWeight.w700)), textDirection: TextDirection.ltr, textScaler: scaler)..layout()).width)
            .fold(0.0, math.max);
        segW = widest + (small ? 22 : 28);
        if (c.hasBoundedWidth) segW = math.min(segW, (c.maxWidth - 4) / options.length);
      }
      return Container(
        width: segW * options.length + 4,
        height: h,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: AppColors.isDark ? AppColors.surfaceContainer : AppColors.surfaceContainerHigh, borderRadius: BorderRadius.circular(h / 2)),
        child: Stack(children: [
          if (idx >= 0)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: segW * idx,
              top: 0,
              bottom: 0,
              width: segW,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.isDark ? AppColors.surfaceContainerHighest : Colors.white,
                  borderRadius: BorderRadius.circular((h - 4) / 2),
                  boxShadow: AppColors.isDark ? null : const [BoxShadow(color: Color(0x1F0F172A), blurRadius: 4, offset: Offset(0, 1)), BoxShadow(color: Color(0x0A0F172A), blurRadius: 1)],
                ),
              ),
            ),
          Row(children: [
            for (int i = 0; i < options.length; i++)
              SizedBox(
                width: segW,
                child: Semantics(
                  button: true,
                  selected: i == idx,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(options[i]),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 160),
                        style: style.c(i == idx ? AppColors.onSurface : AppColors.onSurfaceVariant).w(i == idx ? FontWeight.w700 : FontWeight.w600),
                        child: Text(options[i], maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ]),
      );
    });
  }
}

/// Concentric progress rings, outermost first, each on a faint track in its
/// own colour. Progress past 100% keeps the ring closed.
class ConcentricRings extends StatelessWidget {
  const ConcentricRings({super.key, required this.rings, this.size = 132, this.stroke = 12, this.gap = 3});
  final List<(double, Color)> rings;
  final double size;
  final double stroke;
  final double gap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          for (int i = 0; i < rings.length; i++)
            Ring(
              value: rings[i].$1,
              size: size - i * 2 * (stroke + gap),
              stroke: stroke,
              color: rings[i].$2,
            ),
        ]),
      );
}
