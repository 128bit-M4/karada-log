import 'package:flutter/material.dart';

import 'notifier.dart';
import 'store.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<bool> _ensureNotificationPermission(BuildContext context) async {
    final ok = await Notifier.requestPermission();
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('通知が許可されていません。端末の設定で通知を許可してください')));
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.instance,
      builder: (context, _) {
        final s = Store.instance;
        final time = TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('設定', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('歩数の目標', style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: () => s.setStepGoal(s.stepGoal - 500),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Center(
                    child: Text('${s.stepGoal} 歩 / 日',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () => s.setStepGoal(s.stepGoal + 500),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const Divider(height: 32),
            Text('リマインダー', style: Theme.of(context).textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('毎日の記録リマインド'),
              subtitle: Text('${two(time.hour)}:${two(time.minute)} に通知'),
              value: s.dailyReminder,
              onChanged: (v) async {
                if (v && !await _ensureNotificationPermission(context)) return;
                await s.setDailyReminder(v);
              },
            ),
            if (s.dailyReminder)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: const Text('通知時刻を変更'),
                  onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: time);
                    if (t != null) {
                      await s.setDailyReminder(true, hour: t.hour, minute: t.minute);
                    }
                  },
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('月経予定日の事前通知'),
              subtitle: const Text('予定日の2日前の朝9時に通知'),
              value: s.periodReminder,
              onChanged: (v) async {
                if (v && !await _ensureNotificationPermission(context)) return;
                await s.setPeriodReminder(v);
              },
            ),
            const Divider(height: 32),
            Text('このアプリについて', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '・データはすべてこの端末の中にだけ保存され、外部には送信されません。\n'
              '・歩数は端末の歩数センサーの値を使っています。アプリを毎日一度でも開くと日別の履歴が正確になります。\n'
              '・距離とカロリーは歩数からの簡易的な目安です。\n'
              '・月経・排卵の予測は目安であり、医療上の診断や避妊の目的には使えません。',
              style: TextStyle(color: Theme.of(context).colorScheme.outline, height: 1.6),
            ),
          ],
        );
      },
    );
  }
}
