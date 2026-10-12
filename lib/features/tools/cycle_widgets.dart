import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'cycle_data.dart';

// -----------------------------------------------------------------------------
// "What is happening?" diagram

/// How thick the womb lining is drawn in each phase (0..1).
double _liningFor(CyclePhase p) => switch (diagramPhase(p)) {
      CyclePhase.menstrual => 0.12,
      CyclePhase.follicular => 0.5,
      CyclePhase.ovulation => 0.85,
      _ => 1.0,
    };

/// Phase tabs over an animated cross-section of the uterus, tubes and
/// ovaries. It steps through the phases on its own until the student taps
/// one, then stays on their choice.
class CycleExplainer extends StatefulWidget {
  const CycleExplainer({super.key, required this.cycleLen, required this.periodLen, this.current});
  final int cycleLen;
  final int periodLen;
  final CyclePhase? current;
  @override
  State<CycleExplainer> createState() => _CycleExplainerState();
}

class _CycleExplainerState extends State<CycleExplainer> {
  static const _order = [CyclePhase.menstrual, CyclePhase.follicular, CyclePhase.ovulation, CyclePhase.luteal];
  late CyclePhase _phase = widget.current == null ? CyclePhase.menstrual : diagramPhase(widget.current!);
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _auto = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted) return;
      setState(() => _phase = _order[(_order.indexOf(_phase) + 1) % _order.length]);
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  String _days(CyclePhase p) {
    final ov = widget.cycleLen - 14, pl = widget.periodLen;
    return switch (p) {
      CyclePhase.menstrual => 'Days 1 to $pl',
      CyclePhase.follicular => 'Days ${pl + 1} to ${ov - 3}',
      CyclePhase.ovulation => 'Days ${ov - 2} to ${ov + 2}',
      _ => 'Days ${ov + 3} to ${widget.cycleLen}',
    };
  }

  static const _text = {
    CyclePhase.menstrual: (
      'The lining sheds',
      'Hormone levels are low. The thick lining built up last cycle breaks down and leaves the body through the cervix as your period. The ovaries quietly start growing a few new follicles (tiny sacs that hold eggs).'
    ),
    CyclePhase.follicular: (
      'The lining rebuilds',
      'Oestrogen rises. Follicles in the ovary grow, and one becomes the leader. The womb lining starts to rebuild and thicken, getting ready for a possible pregnancy.'
    ),
    CyclePhase.ovulation: (
      'An egg is released',
      'A surge of luteinising hormone (LH) makes the leading follicle burst and release an egg. The egg is swept into the fallopian tube, and the lining is thick and ready.'
    ),
    CyclePhase.luteal: (
      'The lining waits, then resets',
      'The empty follicle becomes the corpus luteum and makes progesterone, which keeps the lining rich and soft. If the egg is not fertilised, hormone levels fall and a new period begins.'
    ),
  };

  @override
  Widget build(BuildContext context) {
    final c = AppColors.cycle;
    final (title, body) = _text[_phase]!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final p in _order) ...[
            VChip(
              phaseCopy[p]!.name,
              icon: phaseCopy[p]!.icon,
              selected: p == _phase,
              selectedColor: c,
              dense: true,
              onTap: () {
                _auto?.cancel();
                setState(() => _phase = p);
              },
            ),
            const SizedBox(width: 6),
          ],
        ]),
      ),
      const SizedBox(height: Sp.sm),
      Container(
        decoration: BoxDecoration(color: AppColors.isDark ? AppColors.surfaceContainerHigh : const Color(0xFFFFF5F8), borderRadius: BorderRadius.circular(Rad.lg)),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: AspectRatio(aspectRatio: 300 / 205, child: UterusDiagram(phase: _phase)),
      ),
      const SizedBox(height: Sp.sm),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Column(
          key: ValueKey(_phase),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(title, style: T.headlineSm)),
              TagPill(_days(_phase), bg: AppColors.tint(c), fg: c),
            ]),
            const SizedBox(height: 4),
            Text(body, style: T.bodyMd.c(AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    ]);
  }
}

/// Animated cross-section: the lining thickens and thins between phases,
/// follicles grow, an egg is released and travels down the tube, and the
/// lining sheds during a period.
class UterusDiagram extends StatefulWidget {
  const UterusDiagram({super.key, required this.phase});
  final CyclePhase phase;
  @override
  State<UterusDiagram> createState() => _UterusDiagramState();
}

class _UterusDiagramState extends State<UterusDiagram> with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = diagramPhase(widget.phase);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _liningFor(p)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOutCubic,
      builder: (_, lining, _) => AnimatedBuilder(
        animation: _loop,
        builder: (_, _) => CustomPaint(painter: _UterusPainter(phase: p, lining: lining, t: _loop.value, label: AppColors.onSurfaceVariant, dark: AppColors.isDark)),
      ),
    );
  }
}

class _UterusPainter extends CustomPainter {
  _UterusPainter({required this.phase, required this.lining, required this.t, required this.label, required this.dark});
  final CyclePhase phase;
  final double lining;
  final double t;
  final Color label;
  final bool dark;

  static const muscle = Color(0xFFF6B5C6);
  static const muscleEdge = Color(0xFFE28AA4);
  static const liningColor = Color(0xFFC72C66);
  static const cavity = Color(0xFFFFF0F5);
  static const tube = Color(0xFFF3A3BA);
  static const ovary = Color(0xFFF9CAD7);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 300;
    canvas.save();
    canvas.scale(s);

    final body = Path()
      ..moveTo(95, 72)
      ..cubicTo(95, 40, 205, 40, 205, 72)
      ..cubicTo(205, 108, 182, 132, 170, 150)
      ..cubicTo(164, 160, 162, 168, 162, 184)
      ..lineTo(138, 184)
      ..cubicTo(138, 168, 136, 160, 130, 150)
      ..cubicTo(118, 132, 95, 108, 95, 72)
      ..close();

    // Tubes and fimbriae.
    final tubePaint = Paint()
      ..color = tube
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final leftTube = Path()
      ..moveTo(99, 64)
      ..cubicTo(78, 46, 56, 50, 44, 74);
    final rightTube = Path()
      ..moveTo(256, 74)
      ..cubicTo(244, 50, 222, 46, 201, 64);
    canvas.drawPath(leftTube, tubePaint);
    canvas.drawPath(rightTube, tubePaint);
    final fimb = Paint()
      ..color = tube
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final d in const [(-10.0, 6.0), (-8.0, 12.0), (-2.0, 15.0)]) {
      canvas.drawLine(const Offset(44, 74), Offset(44 + d.$1, 74 + d.$2), fimb);
      canvas.drawLine(const Offset(256, 74), Offset(256 - d.$1, 74 + d.$2), fimb);
    }

    // Ligaments and ovaries.
    final lig = Paint()
      ..color = muscleEdge.withValues(alpha: 0.6)
      ..strokeWidth = 2.5;
    canvas.drawLine(const Offset(72, 98), const Offset(100, 90), lig);
    canvas.drawLine(const Offset(228, 98), const Offset(200, 90), lig);
    final ovPaint = Paint()..color = ovary;
    final ovEdge = Paint()
      ..color = muscleEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final cx in const [56.0, 244.0]) {
      final r = Rect.fromCenter(center: Offset(cx, 100), width: 36, height: 26);
      canvas.drawOval(r, ovPaint);
      canvas.drawOval(r, ovEdge);
    }
    _drawOvaryActivity(canvas, rightTube);

    // Womb wall.
    canvas.drawPath(body, Paint()..color = muscle);
    canvas.drawPath(body, Paint()
      ..color = muscleEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);

    // Lining: the band between the cavity outline and a shrunken copy of it.
    final outer = Path()
      ..moveTo(112, 74)
      ..cubicTo(125, 64, 175, 64, 188, 74)
      ..cubicTo(182, 100, 166, 126, 153, 148)
      ..lineTo(147, 148)
      ..cubicTo(134, 126, 118, 100, 112, 74)
      ..close();
    const centre = Offset(150, 92);
    final inScale = 1 - 0.62 * lining;
    Path scaled(Path p, double k) => p.transform((Matrix4.identity()
          ..translateByDouble(centre.dx, centre.dy, 0, 1)
          ..scaleByDouble(k, k, 1, 1)
          ..translateByDouble(-centre.dx, -centre.dy, 0, 1))
        .storage);
    canvas.drawPath(outer, Paint()..color = Color.lerp(const Color(0xFFE9849F), liningColor, lining)!);
    // Little glands and blood vessels once the lining is thick.
    if (lining > 0.35) {
      final dot = Paint()..color = const Color(0xFF8E1240).withValues(alpha: (lining - 0.35) * 0.9);
      for (final m in outer.computeMetrics()) {
        for (double d = 0; d < m.length; d += 7) {
          final pos = m.getTangentForOffset(d)!.position;
          final mid = centre + (pos - centre) * (1 - (1 - inScale) * 0.5);
          canvas.drawCircle(mid + Offset(math.sin(d) * 1.5, math.cos(d) * 1.5), 1.3, dot);
        }
      }
    }
    canvas.drawPath(scaled(outer, inScale), Paint()..color = cavity);
    // Cervical canal.
    canvas.drawLine(const Offset(150, 146), const Offset(150, 184), Paint()
      ..color = cavity
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);

    if (phase == CyclePhase.menstrual) _drawShedding(canvas);

    canvas.restore();
    _drawLabels(canvas, s);
  }

  void _drawOvaryActivity(Canvas canvas, Path rightTube) {
    const ov = Offset(244, 100);
    final follicle = Paint()..color = Colors.white;
    final ring = Paint()
      ..color = const Color(0xFFF2C94C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    switch (phase) {
      case CyclePhase.menstrual:
        for (final o in const [Offset(-8, -3), Offset(2, 4), Offset(8, -4)]) {
          canvas.drawCircle(ov + o, 2.2, follicle);
          canvas.drawCircle(ov + o, 2.2, ring);
        }
      case CyclePhase.follicular:
        final grow = 3 + 3.5 * t;
        canvas.drawCircle(ov + const Offset(4, 0), grow, follicle);
        canvas.drawCircle(ov + const Offset(4, 0), grow, ring);
        canvas.drawCircle(ov + const Offset(-9, 3), 2.2, follicle);
        canvas.drawCircle(ov + const Offset(-6, -5), 2, follicle);
      case CyclePhase.ovulation:
        // The follicle bursts and the egg drifts out to the tube's end.
        canvas.drawCircle(ov + const Offset(4, -6), 6, Paint()..color = const Color(0xFFF2C94C).withValues(alpha: 0.6));
        final e = Curves.easeOut.transform(t);
        _egg(canvas, Offset.lerp(ov + const Offset(4, -8), const Offset(256, 76), e)!);
      default:
        // Corpus luteum, and the egg travelling down the tube.
        canvas.drawCircle(ov + const Offset(4, -2), 6.5, Paint()..color = const Color(0xFFF5C542));
        final m = rightTube.computeMetrics().first;
        final pos = m.getTangentForOffset(m.length * (0.15 + 0.8 * t))!.position;
        _egg(canvas, pos);
    }
  }

  void _egg(Canvas canvas, Offset at) {
    canvas.drawCircle(at, 7, Paint()..color = const Color(0xFFFFE9A8).withValues(alpha: 0.8));
    canvas.drawCircle(at, 4.5, Paint()..color = Colors.white);
    canvas.drawCircle(at, 1.6, Paint()..color = const Color(0xFFF2C94C));
  }

  void _drawShedding(Canvas canvas) {
    final blood = Paint()..color = liningColor;
    // Flecks of lining loosening inside the womb.
    for (int i = 0; i < 6; i++) {
      final ph = (t + i / 6) % 1;
      final x = 136 + (i * 29 % 28).toDouble();
      final y = 92 + ph * 50;
      canvas.drawOval(Rect.fromCenter(center: Offset(x + (150 - x) * ph, y), width: 5, height: 3.5), blood..color = liningColor.withValues(alpha: 1 - ph * 0.5));
    }
    // Drops leaving through the cervix.
    for (int i = 0; i < 3; i++) {
      final ph = (t + i / 3) % 1;
      final y = 178 + ph * 22;
      final drop = Path()
        ..moveTo(150, y - 5)
        ..quadraticBezierTo(155, y + 1, 150, y + 4)
        ..quadraticBezierTo(145, y + 1, 150, y - 5);
      canvas.drawPath(drop, Paint()..color = liningColor.withValues(alpha: 1 - ph));
    }
  }

  void _drawLabels(Canvas canvas, double s) {
    void text(String t, Offset at, {TextAlign align = TextAlign.left}) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontFamily: T.family, fontSize: 10.5 * s.clamp(0.9, 1.4), fontWeight: FontWeight.w600, color: label)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final dx = align == TextAlign.right ? at.dx * s - tp.width : (align == TextAlign.center ? at.dx * s - tp.width / 2 : at.dx * s);
      tp.paint(canvas, Offset(dx, at.dy * s));
    }

    final lead = Paint()
      ..color = label.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    text('Ovary', const Offset(244, 116), align: TextAlign.center);
    text('Fallopian tube', const Offset(226, 30), align: TextAlign.center);
    text('Lining', const Offset(16, 132));
    canvas.drawLine(Offset(50 * s, 139 * s), Offset(128 * s, 112 * s), lead);
    text('Womb wall', const Offset(16, 160));
    canvas.drawLine(Offset(70 * s, 167 * s), Offset(118 * s, 130 * s), lead);
    text('Cervix', const Offset(172, 176));
  }

  @override
  bool shouldRepaint(covariant _UterusPainter old) => true;
}

// -----------------------------------------------------------------------------
// Year calendar

/// The days to mark on the calendar.
class CycleMarks {
  const CycleMarks({required this.period, required this.predicted, required this.fertile});
  final Set<DateTime> period;
  final Set<DateTime> predicted;
  final Set<DateTime> fertile;

  bool hasPeriodIn(int year, int month) => period.any((d) => d.year == year && d.month == month);
  bool hasPredictedIn(int year, int month) => predicted.any((d) => d.year == year && d.month == month);
}

/// Twelve small month grids, like a phone's year view. Logged period days
/// are filled, predicted ones outlined, and each month opens on tap.
class YearCalendar extends StatelessWidget {
  const YearCalendar({super.key, required this.year, required this.marks, required this.onMonth});
  final int year;
  final CycleMarks marks;
  final ValueChanged<DateTime> onMonth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      const gap = 10.0;
      final w = (box.maxWidth - 2 * gap) / 3;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (int m = 1; m <= 12; m++) SizedBox(width: w, child: _MiniMonth(year: year, month: m, marks: marks, onTap: () => onMonth(DateTime(year, m)))),
      ]);
    });
  }
}

class _MiniMonth extends StatelessWidget {
  const _MiniMonth({required this.year, required this.month, required this.marks, required this.onTap});
  final int year;
  final int month;
  final CycleMarks marks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.cycle;
    final logged = marks.hasPeriodIn(year, month);
    final now = DateTime.now();
    final current = now.year == year && now.month == month;
    return Material(
      color: logged ? Color.alphaBlend(c.withValues(alpha: AppColors.isDark ? 0.16 : 0.07), AppColors.surfaceContainerLowest) : AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rad.base),
        side: BorderSide(color: current ? c : (logged ? c.withValues(alpha: 0.35) : AppColors.outlineVariant), width: current ? 1.5 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(DateFormat('MMM').format(DateTime(year, month)), style: T.labelMd.c(logged || current ? c : AppColors.onSurface).w(FontWeight.w800))),
              if (logged) Icon(Symbols.water_drop_rounded, size: 13, color: c, fill: 1),
            ]),
            const SizedBox(height: 4),
            AspectRatio(aspectRatio: 7 / 6, child: CustomPaint(painter: _MiniMonthPainter(year, month, marks, c, AppColors.mind, AppColors.outlineVariant, AppColors.onSurface))),
          ]),
        ),
      ),
    );
  }
}

class _MiniMonthPainter extends CustomPainter {
  _MiniMonthPainter(this.year, this.month, this.marks, this.c, this.fertileC, this.idle, this.ink);
  final int year;
  final int month;
  final CycleMarks marks;
  final Color c;
  final Color fertileC;
  final Color idle;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 7;
    final first = DateTime(year, month, 1);
    final lead = first.weekday - 1;
    final days = DateUtils.getDaysInMonth(year, month);
    final today = DateUtils.dateOnly(DateTime.now());
    for (int d = 1; d <= days; d++) {
      final i = lead + d - 1;
      final center = Offset((i % 7 + 0.5) * cell, (i ~/ 7 + 0.5) * (size.height / 6));
      final date = DateTime(year, month, d);
      final r = cell * 0.36;
      if (marks.period.contains(date)) {
        canvas.drawCircle(center, r, Paint()..color = c);
      } else if (marks.predicted.contains(date)) {
        canvas.drawCircle(center, r * 0.9, Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
      } else if (marks.fertile.contains(date)) {
        canvas.drawCircle(center, r * 0.8, Paint()..color = fertileC.withValues(alpha: 0.35));
      } else {
        canvas.drawCircle(center, r * 0.38, Paint()..color = idle);
      }
      if (date == today) {
        canvas.drawCircle(center, r + 1.6, Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMonthPainter old) => true;
}

/// Full month grid with day numbers, used in the month detail sheet.
class MonthGrid extends StatelessWidget {
  const MonthGrid({super.key, required this.month, required this.marks});
  final DateTime month;
  final CycleMarks marks;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.cycle;
    final first = DateTime(month.year, month.month, 1);
    final lead = first.weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final today = DateUtils.dateOnly(DateTime.now());
    final cells = <Widget>[
      for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Center(child: Text(w, style: T.labelSm.c(AppColors.onSurfaceVariant))),
      for (int i = 0; i < lead; i++) const SizedBox(),
      for (int d = 1; d <= days; d++)
        Builder(builder: (_) {
          final date = DateTime(month.year, month.month, d);
          final period = marks.period.contains(date);
          final predicted = !period && marks.predicted.contains(date);
          final fertile = !period && !predicted && marks.fertile.contains(date);
          return Center(
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: period ? c : (fertile ? AppColors.mind.withValues(alpha: 0.18) : null),
                border: predicted ? Border.all(color: c, width: 1.6) : (date == today ? Border.all(color: AppColors.onSurface, width: 1.6) : null),
              ),
              child: Text('$d', style: T.labelMd.tnum.c(period ? Colors.white : AppColors.onSurface).w(period ? FontWeight.w800 : FontWeight.w600)),
            ),
          );
        }),
    ];
    return GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1, children: cells);
  }
}

class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.cycle;
    Widget item(Widget dot, String label) => Row(mainAxisSize: MainAxisSize.min, children: [dot, const SizedBox(width: 6), Text(label, style: T.bodySm.c(AppColors.onSurfaceVariant))]);
    return Wrap(spacing: 14, runSpacing: 6, children: [
      item(Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), 'Logged period'),
      item(Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c, width: 1.5))), 'Predicted'),
      item(Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.mind.withValues(alpha: 0.35), shape: BoxShape.circle)), 'Fertile (estimate)'),
    ]);
  }
}
