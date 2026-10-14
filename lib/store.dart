import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cycle.dart';
import 'notifier.dart';

String two(int n) => n.toString().padLeft(2, '0');
String dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
DateTime parseDay(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

class Period {
  DateTime start;
  DateTime? end;
  Period(this.start, [this.end]);

  Map<String, dynamic> toJson() =>
      {'s': dayKey(start), if (end != null) 'e': dayKey(end!)};

  factory Period.fromJson(Map<String, dynamic> j) => Period(
        parseDay(j['s'] as String),
        j['e'] == null ? null : parseDay(j['e'] as String),
      );
}

class DayLog {
  double? temp;
  int? mood; // 1(つらい)〜5(絶好調)
  Set<String> symptoms;
  String memo;

  DayLog({this.temp, this.mood, Set<String>? symptoms, this.memo = ''})
      : symptoms = symptoms ?? <String>{};

  bool get isEmpty =>
      temp == null && mood == null && symptoms.isEmpty && memo.trim().isEmpty;

  Map<String, dynamic> toJson() => {
        't': temp,
        'm': mood,
        's': symptoms.toList(),
        'n': memo,
      };

  factory DayLog.fromJson(Map<String, dynamic> j) => DayLog(
        temp: (j['t'] as num?)?.toDouble(),
        mood: j['m'] as int?,
        symptoms: ((j['s'] as List?) ?? const []).map((e) => e as String).toSet(),
        memo: (j['n'] as String?) ?? '',
      );
}

enum StepStatus { unknown, ready, denied, unavailable }

class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  late SharedPreferences _p;

  // 設定
  int stepGoal = 8000;
  bool dailyReminder = false;
  int reminderHour = 21;
  int reminderMinute = 0;
  bool periodReminder = false;

  // 女性の健康管理
  List<Period> periods = [];
  Map<String, DayLog> logs = {};

  // 歩数
  StepStatus stepStatus = StepStatus.unknown;
  int todaySteps = 0;
  Map<String, int> stepHistory = {};
  String? _stepDay;
  int _carry = 0; // 端末再起動前までに数えた今日の歩数
  int _offset = 0; // 今日の開始時点のセンサー累積値
  int _lastRaw = 0;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  StreamSubscription<StepCount>? _sub;

  Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    stepGoal = _p.getInt('stepGoal') ?? 8000;
    dailyReminder = _p.getBool('dailyReminder') ?? false;
    reminderHour = _p.getInt('reminderHour') ?? 21;
    reminderMinute = _p.getInt('reminderMinute') ?? 0;
    periodReminder = _p.getBool('periodReminder') ?? false;

    try {
      periods = (jsonDecode(_p.getString('periods') ?? '[]') as List)
          .map((e) => Period.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      periods.sort((a, b) => a.start.compareTo(b.start));
      logs = (jsonDecode(_p.getString('logs') ?? '{}') as Map).map((k, v) =>
          MapEntry(k as String, DayLog.fromJson(Map<String, dynamic>.from(v as Map))));
      stepHistory = (jsonDecode(_p.getString('stepHistory') ?? '{}') as Map)
          .map((k, v) => MapEntry(k as String, v as int));
      final st = jsonDecode(_p.getString('stepState') ?? '{}') as Map;
      _stepDay = st['d'] as String?;
      _carry = (st['c'] as int?) ?? 0;
      _offset = (st['o'] as int?) ?? 0;
      _lastRaw = (st['l'] as int?) ?? 0;
    } catch (_) {
      // 壊れたデータは無視して初期状態で起動
    }

    if (_stepDay == dayKey(DateTime.now())) {
      final v = _carry + _lastRaw - _offset;
      todaySteps = v < 0 ? 0 : v;
    }
  }

  // ---------------- 歩数 ----------------

  Future<void> startSteps() async {
    var st = await Permission.activityRecognition.status;
    if (!st.isGranted) st = await Permission.activityRecognition.request();
    if (!st.isGranted) {
      stepStatus = StepStatus.denied;
      notifyListeners();
      return;
    }
    await _sub?.cancel();
    _sub = Pedometer.stepCountStream.listen(
      (StepCount e) {
        stepStatus = StepStatus.ready;
        onRawSteps(e.steps);
      },
      onError: (Object _) {
        stepStatus = StepStatus.unavailable;
        notifyListeners();
      },
    );
  }

  /// raw = 端末の起動以降のセンサー累積歩数
  void onRawSteps(int raw) {
    final today = dayKey(DateTime.now());
    var forceSave = false;
    if (_stepDay == null) {
      _stepDay = today;
      _carry = 0;
      _offset = raw;
      forceSave = true;
    } else {
      final soFar = _carry + _lastRaw - _offset;
      if (_stepDay != today) {
        // 日付が変わった：前日分を履歴へ
        stepHistory[_stepDay!] = soFar < 0 ? 0 : soFar;
        stepHistory.removeWhere(
            (k, _) => daysBetween(parseDay(k), DateTime.now()) > 60);
        _stepDay = today;
        _carry = 0;
        _offset = raw;
        forceSave = true;
      } else if (raw < _lastRaw) {
        // 端末再起動でセンサー値がリセットされた
        _carry = soFar < 0 ? 0 : soFar;
        _offset = 0;
        forceSave = true;
      }
    }
    _lastRaw = raw;
    final v = _carry + raw - _offset;
    todaySteps = v < 0 ? 0 : v;

    final now = DateTime.now();
    if (forceSave || now.difference(_lastSave).inSeconds >= 5) {
      flushSteps();
      _lastSave = now;
    }
    notifyListeners();
  }

  void flushSteps() {
    _p.setString(
        'stepState',
        jsonEncode({'d': _stepDay, 'c': _carry, 'o': _offset, 'l': _lastRaw}));
    _p.setString('stepHistory', jsonEncode(stepHistory));
  }

  int stepsOn(DateTime d) {
    final k = dayKey(d);
    if (k == dayKey(DateTime.now())) return todaySteps;
    return stepHistory[k] ?? 0;
  }

  Future<void> setStepGoal(int v) async {
    stepGoal = v.clamp(1000, 50000);
    await _p.setInt('stepGoal', stepGoal);
    notifyListeners();
  }

  // ---------------- 周期 ----------------

  Future<void> _savePeriods() async {
    periods.sort((a, b) => a.start.compareTo(b.start));
    await _p.setString('periods', jsonEncode(periods.map((e) => e.toJson()).toList()));
    notifyListeners();
    reschedule();
  }

  Future<void> addPeriodStart(DateTime d) async {
    final day = dateOnly(d);
    if (periods.any((p) => p.start == day)) return;
    periods.add(Period(day));
    await _savePeriods();
  }

  /// 終了日を記録。対象の月経開始が無ければ false
  Future<bool> setPeriodEnd(DateTime d) async {
    final day = dateOnly(d);
    Period? target;
    for (final p in periods) {
      if (!p.start.isAfter(day)) target = p;
    }
    if (target == null) return false;
    target.end = day;
    await _savePeriods();
    return true;
  }

  Future<void> deletePeriod(Period p) async {
    periods.remove(p);
    await _savePeriods();
  }

  // ---------------- 日々の記録 ----------------

  Future<void> saveLog(String key, DayLog log) async {
    if (log.isEmpty) {
      logs.remove(key);
    } else {
      logs[key] = log;
    }
    await _p.setString(
        'logs', jsonEncode(logs.map((k, v) => MapEntry(k, v.toJson()))));
    notifyListeners();
  }

  // ---------------- 通知設定 ----------------

  Future<void> setDailyReminder(bool on, {int? hour, int? minute}) async {
    dailyReminder = on;
    if (hour != null) reminderHour = hour;
    if (minute != null) reminderMinute = minute;
    await _p.setBool('dailyReminder', dailyReminder);
    await _p.setInt('reminderHour', reminderHour);
    await _p.setInt('reminderMinute', reminderMinute);
    notifyListeners();
    reschedule();
  }

  Future<void> setPeriodReminder(bool on) async {
    periodReminder = on;
    await _p.setBool('periodReminder', on);
    notifyListeners();
    reschedule();
  }

  Future<void> reschedule() async {
    try {
      if (dailyReminder) {
        await Notifier.scheduleDaily(reminderHour, reminderMinute);
      } else {
        await Notifier.cancel(1);
      }
      final info = computeCycle(periods, DateTime.now());
      if (periodReminder && info.nextStart != null) {
        await Notifier.schedulePeriod(info.nextStart!);
      } else {
        await Notifier.cancel(2);
      }
    } catch (_) {
      // 通知が使えない端末でもアプリは動かす
    }
  }
}
