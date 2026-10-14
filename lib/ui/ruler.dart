import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'text.dart';
import 'tokens.dart';

/// A scrollable measuring ruler: the value under the fixed centre line is
/// the selection. Horizontal for weight and girths, vertical for height.
///
/// Values run from [min] to [max] in steps of [step]; every [majorEvery]th
/// tick is long and labelled, every [midEvery]th is medium.
class RulerPicker extends StatefulWidget {
  const RulerPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.axis = Axis.horizontal,
    this.majorEvery = 10,
    this.midEvery = 5,
    this.label,
    this.color,
    this.crossExtent = 96,
    this.spacing = 11,
  });

  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final Axis axis;
  final int majorEvery;
  final int midEvery;

  /// Text drawn under (or beside) each major tick.
  final String Function(double value)? label;
  final Color? color;

  /// Height of a horizontal ruler, or width of a vertical one.
  final double crossExtent;

  /// Distance between ticks in logical pixels.
  final double spacing;

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  late final ScrollController _c;
  late int _last;
  bool _snapping = false;

  int get _count => ((widget.max - widget.min) / widget.step).round() + 1;
  int _indexOf(double v) => ((v - widget.min) / widget.step).round().clamp(0, _count - 1);
  double _valueAt(int i) => double.parse((widget.min + i * widget.step).toStringAsFixed(4));

  @override
  void initState() {
    super.initState();
    _last = _indexOf(widget.value);
    _c = ScrollController(initialScrollOffset: _last * widget.spacing)..addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant RulerPicker old) {
    super.didUpdateWidget(old);
    // Follow outside changes (a unit switch, a typed value) without fighting
    // the student's own scrolling.
    final i = _indexOf(widget.value);
    final rangeChanged = old.min != widget.min || old.max != widget.max || old.step != widget.step;
    if ((i != _last || rangeChanged) && _c.hasClients) {
      _last = i;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_c.hasClients) _c.jumpTo(i * widget.spacing);
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onScroll() {
    final i = (_c.offset / widget.spacing).round().clamp(0, _count - 1);
    if (i == _last) return;
    _last = i;
    if (i % widget.midEvery == 0) HapticFeedback.selectionClick();
    widget.onChanged(_valueAt(i));
  }

  bool _onNotification(ScrollNotification n) {
    if (n is ScrollEndNotification && !_snapping && _c.hasClients) {
      final target = (_c.offset / widget.spacing).round().clamp(0, _count - 1) * widget.spacing;
      if ((target - _c.offset).abs() > 0.5) {
        _snapping = true;
        scheduleMicrotask(() async {
          if (!_c.hasClients) return;
          await _c.animateTo(target, duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
          _snapping = false;
        });
      }
    }
    return false;
  }

  void _nudge(int by) {
    final i = (_last + by).clamp(0, _count - 1);
    _c.animateTo(i * widget.spacing, duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppColors.primary;
    final horizontal = widget.axis == Axis.horizontal;
    return LayoutBuilder(builder: (context, box) {
      final main = horizontal ? box.maxWidth : box.maxHeight;
      final pad = main / 2 - widget.spacing / 2;
      final list = NotificationListener<ScrollNotification>(
        onNotification: _onNotification,
        child: ListView.builder(
          controller: _c,
          scrollDirection: widget.axis,
          physics: const BouncingScrollPhysics(),
          padding: horizontal ? EdgeInsets.symmetric(horizontal: pad) : EdgeInsets.symmetric(vertical: pad),
          itemExtent: widget.spacing,
          itemCount: _count,
          itemBuilder: (_, i) {
            final v = _valueAt(i);
            final kind = i % widget.majorEvery == 0 ? 2 : (i % widget.midEvery == 0 ? 1 : 0);
            return CustomPaint(painter: _TickPainter(kind: kind, axis: widget.axis, label: kind == 2 ? widget.label?.call(v) ?? _fmt(v) : null, color: AppColors.outline));
          },
        ),
      );
      final faded = ShaderMask(
        shaderCallback: (r) => LinearGradient(
          begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
          end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
          colors: const [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
          stops: const [0, 0.18, 0.82, 1],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: list,
      );
      String spoken(double v) => widget.label?.call(v) ?? _fmt(v);
      return Semantics(
        slider: true,
        value: spoken(widget.value),
        increasedValue: spoken((widget.value + widget.step).clamp(widget.min, widget.max)),
        decreasedValue: spoken((widget.value - widget.step).clamp(widget.min, widget.max)),
        onIncrease: () => _nudge(1),
        onDecrease: () => _nudge(-1),
        child: SizedBox(
          width: horizontal ? null : widget.crossExtent,
          height: horizontal ? widget.crossExtent : null,
          child: Stack(children: [
            Positioned.fill(child: faded),
            // The fixed selection line with a dot at its tip.
            if (horizontal)
              Align(
                alignment: Alignment.topCenter,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 3, height: widget.crossExtent * 0.62, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                  Container(width: 11, height: 11, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                ]),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(height: 3, width: widget.crossExtent * 0.72, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                  Container(width: 11, height: 11, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                ]),
              ),
          ]),
        ),
      );
    });
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _TickPainter extends CustomPainter {
  _TickPainter({required this.kind, required this.axis, required this.color, this.label});
  final int kind; // 0 minor, 1 mid, 2 major
  final Axis axis;
  final Color color;
  final String? label;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = kind == 2 ? color : color.withValues(alpha: kind == 1 ? 0.8 : 0.55)
      ..strokeWidth = kind == 2 ? 2 : 1.4
      ..strokeCap = StrokeCap.round;
    if (axis == Axis.horizontal) {
      final x = size.width / 2;
      final len = size.height * (kind == 2 ? 0.46 : (kind == 1 ? 0.32 : 0.2));
      canvas.drawLine(Offset(x, 0), Offset(x, len), p);
      if (label != null) _text(canvas, label!, Offset(x, size.height * 0.58), center: true);
    } else {
      final y = size.height / 2;
      final len = size.width * (kind == 2 ? 0.5 : (kind == 1 ? 0.36 : 0.22));
      canvas.drawLine(Offset(0, y), Offset(len, y), p);
      if (label != null) _text(canvas, label!, Offset(size.width * 0.58, y), center: false);
    }
  }

  void _text(Canvas canvas, String s, Offset at, {required bool center}) {
    final tp = TextPainter(text: TextSpan(text: s, style: T.labelSm.c(AppColors.onSurfaceVariant).tnum), textDirection: TextDirection.ltr)..layout();
    final dx = center ? at.dx - tp.width / 2 : at.dx;
    final dy = center ? at.dy : at.dy - tp.height / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _TickPainter old) => old.kind != kind || old.label != label || old.color != color || old.axis != axis;
}
