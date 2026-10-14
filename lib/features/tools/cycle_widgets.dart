import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../ui/text.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets.dart';
import 'cycle_data.dart';

// -----------------------------------------------------------------------------
// "What is happening?" diagram

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
        decoration: BoxDecoration(color: const Color(0xFFFBE3E6), borderRadius: BorderRadius.circular(Rad.lg)),
        child: AspectRatio(aspectRatio: 3 / 2, child: UterusDiagram(phase: _phase)),
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

/// The uterus, tubes and ovaries in each phase, brought to life with a live
/// layer on top of the illustration: during a period droplets fall from the
/// cervix, in the follicular phase the leading follicle grows, at ovulation
/// the egg travels down the tube, and in the luteal phase the corpus luteum
/// glows while the thick lining gently pulses. Phases cross-fade.
class UterusDiagram extends StatefulWidget {
  const UterusDiagram({super.key, required this.phase});
  final CyclePhase phase;

  static String _asset(CyclePhase p) => switch (p) {
        CyclePhase.menstrual => 'uterus_menstrual',
        CyclePhase.follicular => 'uterus_follicular',
        CyclePhase.ovulation => 'uterus_ovulation',
        _ => 'uterus_luteal',
      };

  @override
  State<UterusDiagram> createState() => _UterusDiagramState();
}

class _UterusDiagramState extends State<UterusDiagram> with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = diagramPhase(widget.phase);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Rad.base),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(a), child: child),
        ),
        child: AnimatedBuilder(
          key: ValueKey(p),
          animation: _loop,
          builder: (_, child) {
            final t = reduceMotion ? 0.35 : _loop.value;
            // A slow "breath" so the whole picture feels alive.
            final breathe = 1.014 + 0.012 * math.sin(t * 2 * math.pi); // never below 1, so no edge shows
            return Stack(fit: StackFit.expand, children: [
              Transform.scale(scale: breathe, child: child),
              CustomPaint(painter: _PhasePainter(phase: p, t: t, breathe: breathe)),
            ]);
          },
          child: Image.asset('assets/art/${UterusDiagram._asset(p)}.jpg', fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// Live effects drawn over the phase illustration, positioned in fractions
/// of the picture (all four pictures share the same 3:2 layout).
class _PhasePainter extends CustomPainter {
  _PhasePainter({required this.phase, required this.t, required this.breathe});
  final CyclePhase phase;
  final double t;
  final double breathe;

  Offset _at(Size s, double x, double y) {
    // Follow the breathing scale around the centre so effects stay attached.
    final c = s.center(Offset.zero);
    return c + (Offset(x * s.width, y * s.height) - c) * breathe;
  }

  void _glow(Canvas canvas, Offset c, double r, Color color, double strength) {
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = RadialGradient(colors: [color.withValues(alpha: strength.clamp(0.0, 1.0)), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  @override
  void paint(Canvas canvas, Size s) {
    switch (phase) {
      case CyclePhase.menstrual:
        _menstrual(canvas, s);
      case CyclePhase.follicular:
        _follicular(canvas, s);
      case CyclePhase.ovulation:
        _ovulation(canvas, s);
      default:
        _luteal(canvas, s);
    }
  }

  // Droplets form at the cervix and fall, while the shedding lining shimmers.
  void _menstrual(Canvas canvas, Size s) {
    final w = s.width;
    for (int i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1.0;
      final y = 0.58 + p * 0.40;
      final size = w * (0.010 + 0.006 * math.sin(p * math.pi));
      final o = _at(s, 0.489, y);
      final alpha = p < 0.85 ? 1.0 : (1 - p) / 0.15;
      final drop = Path()
        ..moveTo(o.dx, o.dy - size * 1.8)
        ..quadraticBezierTo(o.dx + size, o.dy - size * 0.2, o.dx + size, o.dy + size * 0.2)
        ..arcToPoint(Offset(o.dx - size, o.dy + size * 0.2), radius: Radius.circular(size))
        ..quadraticBezierTo(o.dx - size, o.dy - size * 0.2, o.dx, o.dy - size * 1.8)
        ..close();
      canvas.drawPath(drop, Paint()..color = const Color(0xFFB3122A).withValues(alpha: 0.9 * alpha));
      canvas.drawCircle(o + Offset(-size * 0.35, -size * 0.1), size * 0.28, Paint()..color = Colors.white.withValues(alpha: 0.55 * alpha));
    }
    final pulse = 0.5 + 0.5 * math.sin(t * 4 * math.pi);
    _glow(canvas, _at(s, 0.49, 0.33), w * 0.09, const Color(0xFFD7263D), 0.12 + 0.12 * pulse);
  }

  // The leading follicle swells and glows; light rises in the rebuilding lining.
  void _follicular(Canvas canvas, Size s) {
    final w = s.width;
    final grow = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    final f = _at(s, 0.835, 0.335);
    _glow(canvas, f, w * (0.05 + 0.025 * grow), const Color(0xFFFFE3EC), 0.55);
    canvas.drawCircle(
      f,
      w * (0.035 + 0.012 * grow),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.004
        ..color = Colors.white.withValues(alpha: 0.55 + 0.3 * grow),
    );
    final rnd = math.Random(7);
    for (int i = 0; i < 9; i++) {
      final x = 0.43 + rnd.nextDouble() * 0.14;
      final phase = (t * 0.8 + rnd.nextDouble()) % 1.0;
      final y = 0.55 - phase * 0.36;
      final a = math.sin(phase * math.pi);
      canvas.drawCircle(_at(s, x, y), w * (0.004 + rnd.nextDouble() * 0.004), Paint()..color = Colors.white.withValues(alpha: 0.7 * a));
    }
  }

  // The follicle flashes, then the egg drifts into the tube and down to the womb.
  void _ovulation(Canvas canvas, Size s) {
    final w = s.width;
    // Measured along the centre of the tube in the illustration.
    const path = [(0.825, 0.30), (0.89, 0.235), (0.93, 0.18), (0.915, 0.12), (0.86, 0.107), (0.82, 0.12), (0.78, 0.145), (0.74, 0.17), (0.70, 0.19), (0.64, 0.205)];
    final flash = t < 0.18 ? math.sin(t / 0.18 * math.pi) : 0.0;
    _glow(canvas, _at(s, 0.825, 0.30), w * 0.09, const Color(0xFFFFD27A), 0.25 + 0.55 * flash);
    final p = ((t - 0.1) / 0.85).clamp(0.0, 1.0);
    final seg = p * (path.length - 1);
    final i = seg.floor().clamp(0, path.length - 2);
    final k = Curves.easeInOut.transform((seg - i).clamp(0.0, 1.0));
    final x = path[i].$1 + (path[i + 1].$1 - path[i].$1) * k;
    final y = path[i].$2 + (path[i + 1].$2 - path[i].$2) * k;
    final egg = _at(s, x, y);
    final fade = p <= 0 ? 0.0 : (p > 0.9 ? (1 - p) / 0.1 : 1.0);
    _glow(canvas, egg, w * 0.035, const Color(0xFFFFF4D6), 0.9 * fade);
    canvas.drawCircle(egg, w * 0.011, Paint()..color = const Color(0xFFFFFBF0).withValues(alpha: fade));
    canvas.drawCircle(
      egg,
      w * 0.011,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.003
        ..color = const Color(0xFFF2B54A).withValues(alpha: fade),
    );
  }

  // The corpus luteum glows gold and the thick, rich lining breathes.
  void _luteal(Canvas canvas, Size s) {
    final w = s.width;
    final pulse = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    _glow(canvas, _at(s, 0.865, 0.37), w * (0.06 + 0.02 * pulse), const Color(0xFFFFC233), 0.35 + 0.3 * pulse);
    _glow(canvas, _at(s, 0.5, 0.33), w * (0.13 + 0.02 * pulse), const Color(0xFFE8475F), 0.10 + 0.10 * pulse);
  }

  @override
  bool shouldRepaint(covariant _PhasePainter old) => old.t != t || old.phase != phase;
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
