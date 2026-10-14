import 'dart:async';

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

/// The uterus, tubes and ovaries in each phase: the lining shedding, then
/// rebuilding, an egg being released, and the lining at its thickest. The
/// pictures cross-fade with a gentle zoom as the phase changes.
class UterusDiagram extends StatelessWidget {
  const UterusDiagram({super.key, required this.phase});
  final CyclePhase phase;

  static String _asset(CyclePhase p) => switch (diagramPhase(p)) {
        CyclePhase.menstrual => 'uterus_menstrual',
        CyclePhase.follicular => 'uterus_follicular',
        CyclePhase.ovulation => 'uterus_ovulation',
        _ => 'uterus_luteal',
      };

  @override
  Widget build(BuildContext context) {
    final name = _asset(phase);
    return ClipRRect(
      borderRadius: BorderRadius.circular(Rad.base),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 700),
        switchInCurve: Curves.easeOutCubic,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(a), child: child),
        ),
        child: Image.asset('assets/art/$name.jpg', key: ValueKey(name), fit: BoxFit.cover, width: double.infinity, height: double.infinity),
      ),
    );
  }
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
