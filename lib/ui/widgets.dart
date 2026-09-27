import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
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
  static String p(String name) => name == 'app_icon' ? 'assets/images/app_icon.png' : 'assets/images/$name.jpg';
}

class AssetImg extends StatelessWidget {
  const AssetImg(this.name, {super.key, this.fit = BoxFit.cover, this.width, this.height, this.radius = 0, this.alignment = Alignment.center});
  final String name;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double radius;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(Img.p(name), fit: fit, width: width, height: height, alignment: alignment);
    if (radius == 0) return img;
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
  }
}

/// Circular avatar of the signed-in student (uploaded photo or default illustration).
class Avatar extends StatelessWidget {
  const Avatar({super.key, this.size = 32, this.ring = true, this.onTap});
  final double size;
  final bool ring;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final url = AppState.instance.profile?.avatarUrl;
    final child = ClipOval(
      child: url != null && url.isNotEmpty
          ? Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => AssetImg('avatar_student', width: size, height: size))
          : AssetImg('avatar_student', width: size, height: size),
    );
    return GestureDetector(
      onTap: onTap ?? () => context.push('/profile'),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: ring ? Border.all(color: AppColors.surfaceContainerHighest, width: 2) : null,
          boxShadow: ring ? Shadows.tiny : null,
        ),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Containers
// ---------------------------------------------------------------------------

class VCard extends StatelessWidget {
  const VCard({
    super.key,
    required this.child,
    this.color = AppColors.surfaceContainerLowest,
    this.radius = Rad.lg,
    this.padding = const EdgeInsets.all(Sp.md),
    this.shadow,
    this.gradient,
    this.border,
    this.onTap,
    this.margin,
    this.clip = false,
  });
  final Widget child;
  final Color color;
  final double radius;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow>? shadow;
  final Gradient? gradient;
  final BoxBorder? border;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(padding: padding, child: child);
    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: content),
      );
    }
    return Container(
      margin: margin,
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow,
        border: border,
      ),
      child: content,
    );
  }
}

class IconCircle extends StatelessWidget {
  const IconCircle(this.icon, {super.key, this.size = 44, this.iconSize = 22, this.bg = AppColors.surfaceContainerLowest, this.fg = AppColors.primary, this.fill = 0, this.shadow, this.radius});
  final IconData icon;
  final double size;
  final double iconSize;
  final Color bg;
  final Color fg;
  final double fill;
  final List<BoxShadow>? shadow;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: radius == null ? null : BorderRadius.circular(radius!),
        boxShadow: shadow,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: fg, fill: fill),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.child, this.color = AppColors.surfaceContainer, this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 4), this.border, this.shadow});
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final BoxBorder? border;
  final List<BoxShadow>? shadow;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Rad.full), border: border, boxShadow: shadow),
        child: child,
      );
}

/// Small pill with icon + label, e.g. "🔒 FERPA Private".
class TagPill extends StatelessWidget {
  const TagPill(this.label, {super.key, this.icon, this.bg = AppColors.surfaceContainer, this.fg = AppColors.onSurfaceVariant, this.iconColor, this.upper = false, this.fill = 0});
  final String label;
  final IconData? icon;
  final Color bg;
  final Color fg;
  final Color? iconColor;
  final bool upper;
  final double fill;
  @override
  Widget build(BuildContext context) => Pill(
        color: bg,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: iconColor ?? fg, fill: fill), const SizedBox(width: 5)],
          Flexible(child: Text(upper ? label.toUpperCase() : label, style: T.labelSm.c(fg).tracking(upper ? 0.8 : 0.2), overflow: TextOverflow.ellipsis)),
        ]),
      );
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97});
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
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 140),
        curve: const Cubic(0.2, 0.8, 0.2, 1),
        child: widget.child,
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, this.onTap, this.icon, this.leadingIcon, this.color = AppColors.primary, this.fg = AppColors.onPrimary, this.height = 56, this.loading = false, this.shadowColor, this.expand = true, this.textStyle});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? leadingIcon;
  final Color color;
  final Color fg;
  final double height;
  final bool loading;
  final Color? shadowColor;
  final bool expand;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null || loading;
    return Pressable(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(Rad.full),
            boxShadow: Shadows.tinted(shadowColor ?? color, opacity: 0.3, blur: 24, y: 10, spread: -6),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: loading
                ? [SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))]
                : [
                    if (leadingIcon != null) ...[Icon(leadingIcon, color: fg, size: 20), const SizedBox(width: 8)],
                    Flexible(child: Text(label, style: (textStyle ?? T.labelLg).c(fg).semi, overflow: TextOverflow.ellipsis)),
                    if (icon != null) ...[const SizedBox(width: 8), Icon(icon, color: fg, size: 20)],
                  ],
          ),
        ),
      ),
    );
  }
}

class SoftButton extends StatelessWidget {
  const SoftButton(this.label, {super.key, this.onTap, this.icon, this.trailingIcon, this.color = AppColors.surfaceContainerLow, this.fg = AppColors.onSurface, this.iconColor, this.height = 52, this.border, this.expand = true, this.style});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color color;
  final Color fg;
  final Color? iconColor;
  final double height;
  final BoxBorder? border;
  final bool expand;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: height,
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Rad.full), border: border),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: iconColor ?? fg, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label, style: (style ?? T.labelLg).c(fg), overflow: TextOverflow.ellipsis)),
            if (trailingIcon != null) ...[const SizedBox(width: 6), Icon(trailingIcon, color: iconColor ?? fg, size: 18)],
          ],
        ),
      ),
    );
  }
}

class TextLinkButton extends StatelessWidget {
  const TextLinkButton(this.label, {super.key, this.onTap, this.icon, this.color = AppColors.onSurfaceVariant, this.leading});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? leading;
  final Color color;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (leading != null) ...[Icon(leading, size: 18, color: color), const SizedBox(width: 6)],
            Text(label, style: T.labelLg.c(color)),
            if (icon != null) ...[const SizedBox(width: 6), Icon(icon, size: 18, color: color)],
          ]),
        ),
      );
}

class CircleButton extends StatelessWidget {
  const CircleButton(this.icon, {super.key, this.onTap, this.size = 44, this.bg = Colors.transparent, this.fg = AppColors.onSurfaceVariant, this.iconSize = 24, this.shadow, this.badge = false});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color bg;
  final Color fg;
  final double iconSize;
  final List<BoxShadow>? shadow;
  final bool badge;
  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        scale: 0.92,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle, boxShadow: shadow),
          child: Stack(alignment: Alignment.center, children: [
            Icon(icon, size: iconSize, color: fg),
            if (badge)
              Positioned(
                top: size * 0.22,
                right: size * 0.22,
                child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: AppColors.secondaryContainer, shape: BoxShape.circle)),
              ),
          ]),
        ),
      );
}

/// Filter chip (38px pill).
class VChip extends StatelessWidget {
  const VChip(this.label, {super.key, this.selected = false, this.onTap, this.icon, this.emoji, this.selectedColor = AppColors.primary, this.selectedFg = AppColors.onPrimary, this.color = AppColors.surfaceContainerLow, this.fg = AppColors.onSurfaceVariant, this.height = 38});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? emoji;
  final Color selectedColor;
  final Color selectedFg;
  final Color color;
  final Color fg;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = selected ? selectedFg : fg;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? selectedColor : color,
          borderRadius: BorderRadius.circular(Rad.full),
          boxShadow: selected ? Shadows.tinted(selectedColor, opacity: 0.22, blur: 16, y: 6) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 17, color: c), const SizedBox(width: 6)],
          if (emoji != null) ...[Text(emoji!, style: const TextStyle(fontSize: 14)), const SizedBox(width: 6)],
          Text(label, style: T.labelMd.c(c)),
        ]),
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
  const Ring({super.key, required this.value, this.size = 56, this.stroke = 5, this.color = AppColors.primary, this.track = AppColors.surfaceContainerHigh, this.child, this.gradient});
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.clamp(0, 1)),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => CustomPaint(
            painter: _RingPainter(v, stroke, color, track, gradient),
            child: Center(child: child),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.stroke, this.color, this.track, this.gradient);
  final double v;
  final double stroke;
  final Color color;
  final Color track;
  final List<Color>? gradient;
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
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (gradient != null) {
      p.shader = SweepGradient(colors: gradient!, startAngle: -math.pi / 2, endAngle: 3 * math.pi / 2, transform: const GradientRotation(-math.pi / 2)).createShader(rect);
    } else {
      p.color = color;
    }
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * v, false, p);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v || old.color != color;
}

class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.height = 8, this.color = AppColors.primary, this.track = AppColors.surfaceContainerHigh, this.gradient});
  final double value;
  final double height;
  final Color color;
  final Color track;
  final Gradient? gradient;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, cons) => Container(
          height: height,
          decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height)),
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.clamp(0, 1)),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Container(
              width: cons.maxWidth * v,
              height: height,
              decoration: BoxDecoration(color: gradient == null ? color : null, gradient: gradient, borderRadius: BorderRadius.circular(height)),
            ),
          ),
        ),
      );
}

/// Thick pill slider (14px track, 32px thumb) from DESIGN.md.
class VSlider extends StatelessWidget {
  const VSlider({super.key, required this.value, required this.min, required this.max, required this.onChanged, this.divisions, this.color = AppColors.primary});
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final Color color;
  @override
  Widget build(BuildContext context) => SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 10,
          activeTrackColor: color,
          inactiveTrackColor: AppColors.surfaceContainerHigh,
          thumbColor: Colors.white,
          overlayColor: color.withValues(alpha: 0.12),
          thumbShape: const _ThumbShape(),
          trackShape: const RoundedRectSliderTrackShape(),
        ),
        child: Slider(value: value.clamp(min, max), min: min, max: max, divisions: divisions, onChanged: onChanged),
      );
}

class _ThumbShape extends SliderComponentShape {
  const _ThumbShape();
  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(28, 28);
  @override
  void paint(PaintingContext context, Offset center,
      {required Animation<double> activationAnimation,
      required Animation<double> enableAnimation,
      required bool isDiscrete,
      required TextPainter labelPainter,
      required RenderBox parentBox,
      required SliderThemeData sliderTheme,
      required TextDirection textDirection,
      required double value,
      required double textScaleFactor,
      required Size sizeWithOverflow}) {
    final canvas = context.canvas;
    canvas.drawCircle(center + const Offset(0, 2), 14, Paint()
      ..color = const Color(0x332D2B38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(center, 14, Paint()..color = Colors.white);
    canvas.drawCircle(center, 6, Paint()..color = sliderTheme.activeTrackColor ?? AppColors.primary);
  }
}

// ---------------------------------------------------------------------------
// Page scaffold, headers & bottom navigation
// ---------------------------------------------------------------------------

enum NavTab { home, tools, diet, progress, library, profile }

class VPage extends StatelessWidget {
  const VPage({
    super.key,
    required this.children,
    this.header,
    this.nav,
    this.navVariantLibrary = false,
    this.padding = const EdgeInsets.symmetric(horizontal: Sp.margin),
    this.bottom,
    this.background = AppColors.surface,
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
  final Color background;
  final double spacing;
  final Future<void> Function()? onRefresh;
  final Decoration? backgroundDecoration;
  final double? topPadding;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final top = mq.padding.top + (header != null ? 64 : 0) + (topPadding ?? 8);
    final bottomPad = mq.padding.bottom + (nav != null ? 110 : 32) + (bottom != null ? 90 : 0);
    Widget list = ListView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.only(top: top, bottom: bottomPad),
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(height: spacing),
          children[i] is FullBleed ? children[i] : Padding(padding: padding, child: children[i]),
        ]
      ],
    );
    if (onRefresh != null) {
      list = RefreshIndicator(color: AppColors.primary, edgeOffset: top, onRefresh: onRefresh!, child: list);
    }
    return Scaffold(
      backgroundColor: background,
      body: Container(
        decoration: backgroundDecoration,
        child: Stack(children: [
          Positioned.fill(child: list),
          if (header != null) Positioned(top: 0, left: 0, right: 0, child: header!),
          if (bottom != null)
            Positioned(left: 0, right: 0, bottom: nav != null ? mq.padding.bottom + 84 : 0, child: bottom!),
          if (nav != null) Positioned(left: 0, right: 0, bottom: 0, child: BottomNav(current: nav!, library: navVariantLibrary)),
        ]),
      ),
    );
  }
}

/// Marks a child that should ignore the page's horizontal padding.
class FullBleed extends StatelessWidget {
  const FullBleed({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

class _Blur extends StatelessWidget {
  const _Blur({required this.child, this.opacity = 0.85, this.shadow = false});
  final Widget child;
  final double opacity;
  final bool shadow;
  @override
  Widget build(BuildContext context) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: opacity),
              boxShadow: shadow ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 1))] : null,
            ),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: SizedBox(height: 64, child: Padding(padding: const EdgeInsets.symmetric(horizontal: Sp.margin), child: child)),
          ),
        ),
      );
}

/// Tab-level header: title on the left, notifications + avatar on the right.
class MainHeader extends StatelessWidget {
  const MainHeader(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => _Blur(
        child: Row(children: [
          Expanded(child: Text(title, style: T.headlineSm.tracking(-0.2), overflow: TextOverflow.ellipsis)),
          CircleButton(Symbols.notifications, onTap: () => context.push('/notifications'), badge: AppState.instance.unreadCount > 0),
          const SizedBox(width: Sp.sm),
          const Avatar(size: 32),
        ]),
      );
}

/// Back arrow + VitalU brand + contextual chip + person dot.
class BrandBackHeader extends StatelessWidget {
  const BrandBackHeader({super.key, this.chip, this.onBack});
  final String? chip;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => _Blur(
        shadow: true,
        child: Row(children: [
          CircleButton(Symbols.arrow_back, onTap: onBack ?? () => goBack(context)),
          const SizedBox(width: 4),
          const AssetImg('app_icon', height: 32, fit: BoxFit.contain),
          const SizedBox(width: 8),
          Text('VitalU', style: T.headlineSm.tracking(-0.2)),
          const Spacer(),
          if (chip != null) TagPill(chip!),
          const SizedBox(width: Sp.sm),
          const PersonDot(),
        ]),
      );
}

class PersonDot extends StatelessWidget {
  const PersonDot({super.key});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.push('/profile'),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle, boxShadow: Shadows.tinted(AppColors.lavenderInteractive, opacity: 0.25, blur: 12, y: 4, spread: -2)),
          child: const Icon(Symbols.person, color: AppColors.onPrimary, size: 18),
        ),
      );
}

/// Close/back icon + centred title + person dot.
class TitleHeader extends StatelessWidget {
  const TitleHeader(this.title, {super.key, this.close = false, this.upper = false, this.filledButton = false, this.onLeading});
  final String title;
  final bool close;
  final bool upper;
  final bool filledButton;
  final VoidCallback? onLeading;
  @override
  Widget build(BuildContext context) => _Blur(
        opacity: 0.8,
        shadow: true,
        child: Row(children: [
          CircleButton(close ? Symbols.close : Symbols.arrow_back,
              onTap: onLeading ?? () => goBack(context),
              bg: filledButton ? AppColors.surfaceContainer : Colors.transparent,
              fg: filledButton ? AppColors.onSurfaceVariant : AppColors.onSurface,
              iconSize: filledButton ? 20 : 24),
          Expanded(
            child: Text(upper ? title.toUpperCase() : title,
                textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: upper ? T.labelMd.tracking(1.0) : T.headlineSm),
          ),
          const SizedBox(width: 6),
          const PersonDot(),
          const SizedBox(width: 6),
        ]),
      );
}

/// Registration header: back + app icon + "VITALU / Personal Profile".
class RegistrationHeader extends StatelessWidget {
  const RegistrationHeader({super.key, this.title = 'Personal Profile', this.onBack});
  final String title;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => _Blur(
        opacity: 0.8,
        shadow: true,
        child: Row(children: [
          CircleButton(Symbols.arrow_back_ios_new, onTap: onBack ?? () => goBack(context)),
          const SizedBox(width: Sp.xs),
          const AssetImg('app_icon', height: 32, fit: BoxFit.contain),
          const SizedBox(width: Sp.xs),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('VITALU', style: T.labelSm.c(AppColors.primary).bold.tracking(1.2).lh(1)),
            Text(title, style: T.headlineSm.lh(1.3)),
          ]),
          const Spacer(),
          const PersonDot(),
        ]),
      );
}

/// Close + "Confidential Self-Check" pill + avatar.
class ConfidentialHeader extends StatelessWidget {
  const ConfidentialHeader({super.key, this.onClose, this.label = 'Confidential Self-Check'});
  final VoidCallback? onClose;
  final String label;
  @override
  Widget build(BuildContext context) => _Blur(
        opacity: 0.8,
        shadow: true,
        child: Row(children: [
          CircleButton(Symbols.close, fg: AppColors.onSurface, iconSize: 22, onTap: onClose ?? () => goBack(context)),
          const SizedBox(width: Sp.sm),
          Flexible(child: TagPill(label, icon: Symbols.lock, iconColor: AppColors.tertiary, upper: true, bg: AppColors.surfaceContainer)),
          const Spacer(),
          const Avatar(size: 32, ring: false),
        ]),
      );
}

class TwoLineHeader extends StatelessWidget {
  const TwoLineHeader({super.key, required this.kicker, required this.title});
  final String kicker;
  final String title;
  @override
  Widget build(BuildContext context) => _Blur(
        opacity: 0.8,
        shadow: true,
        child: Row(children: [
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kicker.toUpperCase(), style: T.labelSm.c(AppColors.secondary).tracking(1)),
            Text(title, style: T.headlineSm),
          ]),
          const Spacer(),
          CircleButton(Symbols.notifications, iconSize: 22, onTap: () => context.push('/notifications')),
          const SizedBox(width: 4),
          const Avatar(size: 32, ring: false),
        ]),
      );
}

void goBack(BuildContext context, [String fallback = '/home']) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallback);
  }
}

/// In-page title row with back button, e.g. "← About & Support".
class BackTitleRow extends StatelessWidget {
  const BackTitleRow({super.key, required this.title, this.subtitle, this.trailing, this.onBack});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Row(children: [
        CircleButton(Symbols.arrow_back, bg: AppColors.surfaceContainerLow, fg: AppColors.onSurface, iconSize: 22, onTap: onBack ?? () => goBack(context)),
        const SizedBox(width: Sp.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.headlineMd, overflow: TextOverflow.ellipsis),
            if (subtitle != null) Text(subtitle!, style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]);
}

class BottomNav extends StatelessWidget {
  const BottomNav({super.key, required this.current, this.library = false});
  final NavTab current;
  final bool library;

  @override
  Widget build(BuildContext context) {
    final items = <(NavTab, IconData, String, String)>[
      (NavTab.home, Symbols.cottage, 'Home', '/home'),
      (NavTab.tools, Symbols.self_improvement, 'Tools', '/tools'),
      (NavTab.diet, Symbols.local_dining, 'Diet', '/diet'),
      library ? (NavTab.library, Symbols.local_library, 'Library', '/library') : (NavTab.progress, Symbols.bubble_chart, 'Progress', '/progress'),
      (NavTab.profile, Symbols.account_circle, 'Profile', '/profile'),
    ];
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(Sp.margin, 0, Sp.margin, (bottom > 0 ? bottom : 16) + Sp.sm - 4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Rad.full),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(Rad.full),
                  boxShadow: Shadows.floating,
                ),
                child: Row(children: [
                  for (final it in items)
                    Expanded(
                      child: Pressable(
                        onTap: () {
                          if (it.$1 != current) context.go(it.$4);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 48,
                          decoration: BoxDecoration(
                            color: it.$1 == current ? AppColors.surfaceContainerLowest : Colors.transparent,
                            borderRadius: BorderRadius.circular(Rad.full),
                            boxShadow: it.$1 == current ? Shadows.card : null,
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(it.$2, size: 22, color: it.$1 == current ? AppColors.primary : AppColors.onSurfaceVariant, fill: it.$1 == current ? 1 : 0),
                            const SizedBox(height: 2),
                            Text(it.$3, style: T.labelSm.s(10).c(it.$1 == current ? AppColors.primary : AppColors.onSurfaceVariant)),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Misc
// ---------------------------------------------------------------------------

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing, this.style});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: style ?? T.headlineMd),
            if (subtitle != null) Text(subtitle!, style: T.bodySm.c(AppColors.onSurfaceVariant)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]);
}

class PrivacyNote extends StatelessWidget {
  const PrivacyNote(this.text, {super.key, this.icon = Symbols.verified_user, this.center = true});
  final String text;
  final IconData icon;
  final bool center;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: center ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, size: 15, color: AppColors.tertiary)),
          const SizedBox(width: 6),
          Flexible(child: Text(text, textAlign: center ? TextAlign.center : TextAlign.start, style: T.bodySm.s(12).c(AppColors.onSurfaceVariant))),
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
        color: AppColors.surfaceContainerLow,
        child: Column(children: [
          IconCircle(icon, size: 52, iconSize: 26),
          const SizedBox(height: Sp.sm),
          Text(title, style: T.labelLg, textAlign: TextAlign.center),
          if (text != null) ...[const SizedBox(height: 4), Text(text!, style: T.bodySm.c(AppColors.onSurfaceVariant), textAlign: TextAlign.center)],
          if (action != null) ...[const SizedBox(height: Sp.sm), action!],
        ]),
      );
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: T.bodySm.c(Colors.white)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.error : AppColors.inverseSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Rad.base)),
      margin: const EdgeInsets.fromLTRB(Sp.margin, 0, Sp.margin, 96),
    ));
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.6)),
      );
}

/// Rounded bottom sheet styled per DESIGN.md (36px top radius + drag handle).
Future<T?> showVSheet<T>(BuildContext context, {required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        ),
        padding: EdgeInsets.fromLTRB(Sp.margin, 10, Sp.margin, MediaQuery.of(ctx).padding.bottom + Sp.md),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 36, height: 5, decoration: BoxDecoration(color: AppColors.outlineVariant, borderRadius: BorderRadius.circular(5)))),
          const SizedBox(height: Sp.md),
          Flexible(child: SingleChildScrollView(child: builder(ctx))),
        ]),
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
      style: T.bodyMd,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: T.bodyMd.c(AppColors.outline),
        filled: true,
        fillColor: AppColors.inputFill,
        prefixIcon: icon == null ? null : Icon(icon, color: AppColors.outline, size: 20),
        suffixIcon: suffix,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: maxLines > 1 ? 16 : 15),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(maxLines > 1 ? 24 : Rad.full), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(maxLines > 1 ? 24 : Rad.full), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(maxLines > 1 ? 24 : Rad.full),
          borderSide: BorderSide(color: AppColors.lavenderInteractive.withValues(alpha: 0.45), width: 2),
        ),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.full), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Rad.full), borderSide: const BorderSide(color: AppColors.error, width: 2)),
      ),
    );
  }
}

/// Segmented pill toggle, e.g. "cm | ft/in".
class Segmented extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, this.small = true});
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool small;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(Rad.full)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final o in options)
            GestureDetector(
              onTap: () => onChanged(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16, vertical: small ? 5 : 8),
                decoration: BoxDecoration(
                  color: o == value ? AppColors.surfaceContainerLowest : Colors.transparent,
                  borderRadius: BorderRadius.circular(Rad.full),
                  boxShadow: o == value ? Shadows.tiny : null,
                ),
                child: Text(o, style: T.labelSm.s(12).c(o == value ? AppColors.primary : AppColors.onSurfaceVariant)),
              ),
            ),
        ]),
      );
}

/// Soft background glow blob used behind hero cards.
class Glow extends StatelessWidget {
  const Glow({super.key, required this.color, this.size = 112});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ),
      );
}
