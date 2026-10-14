import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// リマインダー通知。id 1 = 毎日の記録リマインド / id 2 = 月経予定日の事前通知
class Notifier {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'リマインダー',
      channelDescription: '記録のお知らせと月経予定日のお知らせ',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
  );

  static Future<void> init() async {
    tzdata.initializeTimeZones();
    // 日本国内利用を想定して日本時間に固定
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: android));
  }

  /// Android 13+ の通知権限を要求する
  static Future<bool> requestPermission() async {
    final impl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await impl?.requestNotificationsPermission();
    return granted ?? false;
  }

  static Future<void> scheduleDaily(int hour, int minute) async {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      1,
      '今日の記録',
      '体調や基礎体温を記録しましょう',
      t,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// 月経予定日の2日前の朝9時に通知（過ぎていれば何もしない）
  static Future<void> schedulePeriod(DateTime nextStart) async {
    final t = tz.TZDateTime(
        tz.local, nextStart.year, nextStart.month, nextStart.day - 2, 9, 0);
    if (!t.isAfter(tz.TZDateTime.now(tz.local))) {
      await _plugin.cancel(2);
      return;
    }
    await _plugin.zonedSchedule(
      2,
      '月経予定日が近づいています',
      '2日後が月経予定日です（目安）',
      t,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);
}
