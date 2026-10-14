import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'cycle.dart';
import 'record_page.dart';
import 'store.dart';

class CyclePage extends StatefulWidget {
  const CyclePage({super.key});

  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month, 1);
  }

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta, 1));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final s = Store.instance;
        final info = computeCycle(s.periods, DateTime.now());
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('月経周期', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _summary(context, info),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.water_drop),
                    label: const Text('今日から月経開始'),
                    onPressed: () async {
                      await s.addPeriodStart(DateTime.now());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('月経開始日を記録しました')));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.flag),
                    label: const Text('今日で月経終了'),
                    onPressed: () async {
                      final ok = await s.setPeriodEnd(DateTime.now());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ok ? '月経終了日を記録しました' : '先に月経開始日を記録してください')));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _calendar(context, info, s),
            const SizedBox(height: 8),
            _legend(context),
            const SizedBox(height: 20),
            Text('月経の履歴', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (s.periods.isEmpty)
              Text('まだ記録がありません',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            for (final p in s.periods.reversed.take(12)) _periodTile(context, p, s),
            const SizedBox(height: 12),
            Text(
              '予測は過去の記録をもとにした目安です。避妊や診断の目的には使えません。'
              '体調に不安がある場合は医療機関にご相談ください。',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
            ),
          ],
        );
      },
    );
  }

  Widget _summary(BuildContext context, CycleInfo info) {
    final cs = Theme.of(context).colorScheme;
    final md = DateFormat('M/d(E)', 'ja');
    if (info.lastStart == null) {
      return Card(
        color: cs.primaryContainer,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Text('月経が始まったら「今日から月経開始」を押して記録しましょう。'
              '記録が増えるほど予測の精度が上がります。'),
        ),
      );
    }
    final today = dateOnly(DateTime.now());
    final diff = daysBetween(today, info.nextStart!);
    final String next;
    if (diff > 0) {
      next = '次の月経予定まで あと$diff日（${md.format(info.nextStart!)}）';
    } else if (diff == 0) {
      next = '今日が月経予定日です';
    } else {
      next = '月経予定日（${md.format(info.nextStart!)}）を${-diff}日過ぎています';
    }
    final ov = info.ovulation!;
    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('周期${info.cycleDay}日目',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(next),
            Text('排卵予定日（目安）${md.format(ov)}'),
            Text('妊娠しやすい期間（目安）'
                '${md.format(addDays(ov, -5))}〜${md.format(addDays(ov, 1))}'),
            const SizedBox(height: 4),
            Text('平均周期 ${info.avgCycle}日 / 平均月経期間 ${info.avgPeriod}日',
                style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }

  Widget _calendar(BuildContext context, CycleInfo info, Store s) {
    final cs = Theme.of(context).colorScheme;
    final first = DateTime(_month.year, _month.month, 1);
    final daysIn = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7; // 日曜始まり
    final today = dateOnly(DateTime.now());

    final cells = <Widget>[];
    for (var i = 0; i < lead; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysIn; day++) {
      final d = DateTime(_month.year, _month.month, day);
      final k = dayKey(d);
      final isPeriod = info.periodDays.contains(k);
      final isPredicted = !isPeriod && info.predictedPeriodDays.contains(k);
      final isFertile = !isPeriod && !isPredicted && info.fertileDays.contains(k);
      final hasLog = s.logs[k] != null;
      final isToday = d == today;

      Color? bg;
      Color fg = cs.onSurface;
      if (isPeriod) {
        bg = cs.primary;
        fg = cs.onPrimary;
      } else if (isPredicted) {
        bg = cs.primary.withOpacity(0.18);
      } else if (isFertile) {
        bg = Colors.lightBlue.shade100;
      }

      cells.add(InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showDaySheet(context, d),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: isToday ? Border.all(color: cs.primary, width: 2) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day', style: TextStyle(color: fg, fontWeight: isToday ? FontWeight.bold : null)),
              SizedBox(
                height: 8,
                child: hasLog
                    ? Icon(Icons.circle, size: 6, color: isPeriod ? cs.onPrimary : cs.primary)
                    : null,
              ),
            ],
          ),
        ),
      ));
    }

    const week = ['日', '月', '火', '水', '木', '金', '土'];
    return Column(
      children: [
        Row(
          children: [
            IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Center(
                child: Text(DateFormat('yyyy年M月', 'ja').format(_month),
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Row(
          children: [
            for (final w in week)
              Expanded(
                child: Center(
                  child: Text(w, style: TextStyle(color: cs.outline, fontSize: 12)),
                ),
              ),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.0,
          children: cells,
        ),
      ],
    );
  }

  Widget _legend(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget item(Color c, String t, {bool border = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(4),
                border: border ? Border.all(color: cs.primary, width: 2) : null,
              ),
            ),
            const SizedBox(width: 4),
            Text(t, style: const TextStyle(fontSize: 12)),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        item(cs.primary, '月経'),
        item(cs.primary.withOpacity(0.18), '月経予定'),
        item(Colors.lightBlue.shade100, '妊娠しやすい期間'),
        item(Colors.transparent, '今日', border: true),
      ],
    );
  }

  Widget _periodTile(BuildContext context, Period p, Store s) {
    final f = DateFormat('yyyy/M/d', 'ja');
    final text = p.end == null
        ? '${f.format(p.start)} 〜'
        : '${f.format(p.start)} 〜 ${f.format(p.end!)}（${daysBetween(p.start, p.end!) + 1}日間）';
    return Card(
      child: ListTile(
        leading: const Icon(Icons.water_drop),
        title: Text(text),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('この記録を削除しますか？'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('キャンセル')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('削除')),
                ],
              ),
            );
            if (ok == true) await s.deletePeriod(p);
          },
        ),
      ),
    );
  }
}
