import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import 'store.dart';

class StepsPage extends StatelessWidget {
  const StepsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final s = Store.instance;
        final cs = Theme.of(context).colorScheme;
        final steps = s.todaySteps;
        final goal = s.stepGoal;
        final pct = goal == 0 ? 0.0 : (steps / goal).clamp(0.0, 1.0);
        final fmt = NumberFormat('#,###');
        final km = steps * 0.0007; // 歩幅およそ70cm
        final kcal = steps * 0.04; // 目安

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('今日の歩数', style: Theme.of(context).textTheme.titleLarge),
            Text(DateFormat('M月d日(E)', 'ja').format(DateTime.now()),
                style: TextStyle(color: cs.outline)),
            const SizedBox(height: 16),
            _statusBanner(context, s),
            Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: pct,
                        strokeWidth: 16,
                        strokeCap: StrokeCap.round,
                        backgroundColor: cs.primaryContainer,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(fmt.format(steps),
                            style: const TextStyle(
                                fontSize: 44, fontWeight: FontWeight.bold)),
                        Text('目標 ${fmt.format(goal)} 歩',
                            style: TextStyle(color: cs.outline)),
                        Text('${(pct * 100).round()}%',
                            style: TextStyle(
                                color: cs.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _stat(context, Icons.straighten, '距離', '${km.toStringAsFixed(2)} km'),
                const SizedBox(width: 12),
                _stat(context, Icons.local_fire_department, '消費目安',
                    '${kcal.round()} kcal'),
              ],
            ),
            const SizedBox(height: 24),
            Text('直近7日間', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _weekChart(context, s),
          ],
        );
      },
    );
  }

  Widget _statusBanner(BuildContext context, Store s) {
    if (s.stepStatus == StepStatus.denied) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('歩数の計測には「身体の動き（アクティビティ）」の許可が必要です。'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: s.startSteps, child: const Text('もう一度許可する')),
                OutlinedButton(onPressed: openAppSettings, child: const Text('設定を開く')),
              ]),
            ],
          ),
        ),
      );
    }
    if (s.stepStatus == StepStatus.unavailable) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('この端末では歩数センサーを利用できませんでした。'),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _stat(BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        color: cs.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: cs.outline, fontSize: 12)),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekChart(BuildContext context, Store s) {
    final cs = Theme.of(context).colorScheme;
    final today = dateOnly(DateTime.now());
    final days = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
    final values = days.map(s.stepsOn).toList();
    var maxV = s.stepGoal;
    for (final v in values) {
      if (v > maxV) maxV = v;
    }
    const chartH = 140.0;
    return SizedBox(
      height: chartH + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    values[i] >= 1000
                        ? '${(values[i] / 1000).toStringAsFixed(1)}k'
                        : '${values[i]}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    width: 22,
                    height: maxV == 0 ? 2 : (chartH * values[i] / maxV).clamp(2.0, chartH),
                    decoration: BoxDecoration(
                      color: values[i] >= s.stepGoal ? cs.primary : cs.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(DateFormat('E', 'ja').format(days[i]),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: i == days.length - 1 ? FontWeight.bold : null)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
