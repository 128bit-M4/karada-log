import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'store.dart';

const List<String> kSymptoms = [
  '腹痛', '頭痛', '腰痛', 'むくみ', '眠気', '吐き気', '肌荒れ', 'イライラ', '食欲増加', '不正出血',
];
const List<String> kMoods = ['😣', '😟', '😐', '🙂', '😄'];

/// 「記録」タブ：基礎体温グラフと直近の記録
class RecordPage extends StatelessWidget {
  const RecordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final s = Store.instance;
        final cs = Theme.of(context).colorScheme;
        final today = dateOnly(DateTime.now());
        final start = addDays(today, -29);

        final points = <MapEntry<DateTime, double>>[];
        for (var i = 0; i < 30; i++) {
          final d = addDays(start, i);
          final t = s.logs[dayKey(d)]?.temp;
          if (t != null) points.add(MapEntry(d, t));
        }

        final keys = s.logs.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Expanded(
                    child: Text('記録', style: Theme.of(context).textTheme.titleLarge)),
                FilledButton.icon(
                  onPressed: () => showDaySheet(context, today),
                  icon: const Icon(Icons.add),
                  label: const Text('今日を記録'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('基礎体温（直近30日）', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: points.isEmpty
                    ? SizedBox(
                        height: 120,
                        child: Center(
                          child: Text('体温を記録するとグラフが表示されます',
                              style: TextStyle(color: cs.outline)),
                        ),
                      )
                    : SizedBox(
                        height: 180,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _TempPainter(points, start, 30, cs.primary, cs.outlineVariant),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            Text('最近の記録', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (keys.isEmpty)
              Text('まだ記録がありません', style: TextStyle(color: cs.outline)),
            for (final k in keys.take(20)) _logTile(context, k, s.logs[k]!),
          ],
        );
      },
    );
  }

  Widget _logTile(BuildContext context, String key, DayLog log) {
    final d = parseDay(key);
    final parts = <String>[];
    if (log.temp != null) parts.add('${log.temp!.toStringAsFixed(2)}℃');
    if (log.symptoms.isNotEmpty) parts.add(log.symptoms.join('・'));
    if (log.memo.trim().isNotEmpty) parts.add(log.memo.trim());
    return Card(
      child: ListTile(
        leading: Text(log.mood == null ? '📝' : kMoods[log.mood! - 1],
            style: const TextStyle(fontSize: 26)),
        title: Text(DateFormat('M月d日(E)', 'ja').format(d)),
        subtitle: Text(parts.isEmpty ? '—' : parts.join('  '),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => showDaySheet(context, d),
      ),
    );
  }
}

class _TempPainter extends CustomPainter {
  final List<MapEntry<DateTime, double>> points;
  final DateTime start;
  final int days;
  final Color color;
  final Color gridColor;

  _TempPainter(this.points, this.start, this.days, this.color, this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    var minT = points.map((e) => e.value).reduce(math.min) - 0.2;
    var maxT = points.map((e) => e.value).reduce(math.max) + 0.2;
    if (maxT - minT < 0.6) {
      final mid = (maxT + minT) / 2;
      minT = mid - 0.3;
      maxT = mid + 0.3;
    }
    const left = 40.0, right = 8.0, top = 8.0, bottom = 20.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    double xOf(DateTime d) => left + w * daysBetween(start, d) / (days - 1);
    double yOf(double t) => top + h * (1 - (t - minT) / (maxT - minT));

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final t = minT + (maxT - minT) * i / 3;
      final y = yOf(t);
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      _text(canvas, t.toStringAsFixed(2), Offset(0, y - 6));
    }
    for (final i in [0, 10, 20, 29]) {
      final d = addDays(start, i);
      _text(canvas, '${d.month}/${d.day}', Offset(xOf(d) - 12, size.height - 14));
    }

    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(xOf(points[i].key), yOf(points[i].value));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = color;
    for (final p in points) {
      canvas.drawCircle(Offset(xOf(p.key), yOf(p.value)), 3.5, dot);
    }
  }

  void _text(Canvas canvas, String s, Offset o) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(covariant _TempPainter old) => true;
}

// ---------------------------------------------------------------------------
// 日付ごとの記録シート（周期タブ・記録タブの両方から使用）
// ---------------------------------------------------------------------------

Future<void> showDaySheet(BuildContext context, DateTime date) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
      child: _DaySheet(date: dateOnly(date), parentContext: context),
    ),
  );
}

class _DaySheet extends StatefulWidget {
  final DateTime date;
  final BuildContext parentContext;
  const _DaySheet({required this.date, required this.parentContext});

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  late final TextEditingController _temp;
  late final TextEditingController _memo;
  int? _mood;
  late Set<String> _symptoms;
  String? _tempError;

  @override
  void initState() {
    super.initState();
    final log = Store.instance.logs[dayKey(widget.date)];
    _temp = TextEditingController(text: log?.temp?.toStringAsFixed(2) ?? '');
    _memo = TextEditingController(text: log?.memo ?? '');
    _mood = log?.mood;
    _symptoms = {...?log?.symptoms};
  }

  @override
  void dispose() {
    _temp.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(widget.parentContext)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    double? t;
    final raw = _temp.text.trim().replaceAll(',', '.');
    if (raw.isNotEmpty) {
      t = double.tryParse(raw);
      if (t == null || t < 34 || t > 42) {
        setState(() => _tempError = '34.00〜42.00 の範囲で入力してください');
        return;
      }
    }
    await Store.instance.saveLog(
      dayKey(widget.date),
      DayLog(temp: t, mood: _mood, symptoms: {..._symptoms}, memo: _memo.text),
    );
    if (mounted) Navigator.pop(context);
    _toast('保存しました');
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.date;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('M月d日(E)', 'ja').format(d),
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.water_drop),
                label: const Text('月経開始日にする'),
                onPressed: () async {
                  await Store.instance.addPeriodStart(d);
                  if (mounted) Navigator.pop(context);
                  _toast('月経開始日を記録しました');
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.flag),
                label: const Text('月経終了日にする'),
                onPressed: () async {
                  final ok = await Store.instance.setPeriodEnd(d);
                  if (mounted) Navigator.pop(context);
                  _toast(ok ? '月経終了日を記録しました' : '先に月経開始日を記録してください');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _temp,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '基礎体温 (℃)',
              hintText: '例 36.45',
              errorText: _tempError,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_tempError != null) setState(() => _tempError = null);
            },
          ),
          const SizedBox(height: 16),
          Text('気分', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < kMoods.length; i++)
                ChoiceChip(
                  label: Text(kMoods[i], style: const TextStyle(fontSize: 22)),
                  selected: _mood == i + 1,
                  onSelected: (sel) => setState(() => _mood = sel ? i + 1 : null),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('症状', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in kSymptoms)
                FilterChip(
                  label: Text(s),
                  selected: _symptoms.contains(s),
                  onSelected: (sel) =>
                      setState(() => sel ? _symptoms.add(s) : _symptoms.remove(s)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memo,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'メモ',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _save, child: const Text('保存')),
          ),
        ],
      ),
    );
  }
}
