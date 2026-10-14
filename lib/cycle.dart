import 'store.dart';

/// 月経周期の集計と予測。あくまで過去の記録からの目安です。
class CycleInfo {
  final int avgCycle;
  final int avgPeriod;
  final DateTime? lastStart;
  final DateTime? nextStart;
  final DateTime? ovulation;
  final int? cycleDay;
  final Set<String> periodDays;
  final Set<String> predictedPeriodDays;
  final Set<String> fertileDays;

  const CycleInfo({
    required this.avgCycle,
    required this.avgPeriod,
    required this.lastStart,
    required this.nextStart,
    required this.ovulation,
    required this.cycleDay,
    required this.periodDays,
    required this.predictedPeriodDays,
    required this.fertileDays,
  });
}

int _avg(List<int> v, int fallback) {
  if (v.isEmpty) return fallback;
  return (v.reduce((a, b) => a + b) / v.length).round();
}

List<int> _recent(List<int> v) =>
    v.length > 6 ? v.sublist(v.length - 6) : v;

CycleInfo computeCycle(List<Period> periods, DateTime now) {
  final today = dateOnly(now);
  final sorted = [...periods]..sort((a, b) => a.start.compareTo(b.start));

  final intervals = <int>[];
  for (var i = 1; i < sorted.length; i++) {
    final d = daysBetween(sorted[i - 1].start, sorted[i].start);
    if (d >= 15 && d <= 60) intervals.add(d);
  }
  final avgCycle = _avg(_recent(intervals), 28);

  final lens = <int>[];
  for (final p in sorted) {
    if (p.end != null) {
      final l = daysBetween(p.start, p.end!) + 1;
      if (l >= 1 && l <= 14) lens.add(l);
    }
  }
  final avgPeriod = _avg(_recent(lens), 5);

  final periodDays = <String>{};
  for (final p in sorted) {
    DateTime end;
    if (p.end != null) {
      end = p.end!;
    } else {
      final guess = addDays(p.start, avgPeriod - 1);
      end = p.start.isAfter(today) ? p.start : (guess.isBefore(today) ? guess : today);
    }
    var d = p.start;
    var guard = 0;
    while (!d.isAfter(end) && guard < 40) {
      periodDays.add(dayKey(d));
      d = addDays(d, 1);
      guard++;
    }
  }

  final predicted = <String>{};
  final fertile = <String>{};
  DateTime? lastStart;
  DateTime? nextStart;
  DateTime? ovulation;
  int? cycleDay;

  if (sorted.isNotEmpty) {
    lastStart = sorted.last.start;
    nextStart = addDays(lastStart, avgCycle);
    ovulation = addDays(nextStart, -14);
    cycleDay = daysBetween(lastStart, today) + 1;
    for (var k = 1; k <= 3; k++) {
      final s = addDays(lastStart, avgCycle * k);
      for (var i = 0; i < avgPeriod; i++) {
        predicted.add(dayKey(addDays(s, i)));
      }
      final ov = addDays(s, -14);
      for (var i = -5; i <= 1; i++) {
        fertile.add(dayKey(addDays(ov, i)));
      }
    }
  }

  return CycleInfo(
    avgCycle: avgCycle,
    avgPeriod: avgPeriod,
    lastStart: lastStart,
    nextStart: nextStart,
    ovulation: ovulation,
    cycleDay: cycleDay,
    periodDays: periodDays,
    predictedPeriodDays: predicted,
    fertileDays: fertile,
  );
}
