import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'notification_service.dart';
import 'bluetooth_service.dart';
import 'command_service.dart';

class Schedule {
  final int id;
  final String name;
  final String command;
  final DateTime time;
  final List<int> weekdays; // 1=Monday, 7=Sunday, 0=once
  final bool enabled;
  final int? notifyBeforeMinutes;

  Schedule({
    required this.id,
    required this.name,
    required this.command,
    required this.time,
    required this.weekdays,
    required this.enabled,
    this.notifyBeforeMinutes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'command': command,
        'time': time.toIso8601String(),
        'weekdays': weekdays,
        'enabled': enabled,
        'notifyBeforeMinutes': notifyBeforeMinutes,
      };

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
        id: json['id'],
        name: json['name'],
        command: json['command'],
        time: DateTime.parse(json['time']),
        weekdays: List<int>.from(json['weekdays']),
        enabled: json['enabled'],
        notifyBeforeMinutes: json['notifyBeforeMinutes'],
      );

  bool isRecurring() => weekdays.isNotEmpty && !weekdays.contains(0);
}

class ScheduleService {
  static final ScheduleService _instance = ScheduleService._internal();
  factory ScheduleService() => _instance;
  ScheduleService._internal();

  static const String _key = 'schedules';
  final List<Schedule> _schedules = [];
  final CommandService _command = CommandService();
  final BluetoothService _bluetooth = BluetoothService();
  Timer? _timer;
  final Set<String> _executedSchedules = {}; // format: "id-yyyyMMddHHmm"

  static Future<void> initialize() async {
    await _instance._loadSchedules();
    await _instance._loadSchedules();
    _instance._startMonitoring();
  }

  void _startMonitoring() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkSchedules();
    });
  }

  Future<void> _loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      final List<dynamic> decoded = json.decode(jsonString);
      _schedules.clear();
      _schedules.addAll(decoded.map((e) => Schedule.fromJson(e)));
    }
    await _scheduleNotifications();
  }

  Future<void> _saveSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(_schedules.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }

  Future<void> addSchedule(Schedule schedule) async {
    _schedules.add(schedule);
    await _saveSchedules();
    await _scheduleNotifications();
  }

  Future<void> updateSchedule(Schedule schedule) async {
    final index = _schedules.indexWhere((s) => s.id == schedule.id);
    if (index != -1) {
      _schedules[index] = schedule;
      await _saveSchedules();
      await _scheduleNotifications();
    }
  }

  Future<void> deleteSchedule(int id) async {
    _schedules.removeWhere((s) => s.id == id);
    await NotificationService.cancelNotification(id);
    await _saveSchedules();
    await _scheduleNotifications();
  }

  List<Schedule> getSchedules() {
    return List.from(_schedules);
  }

  Future<void> _scheduleNotifications() async {
    await NotificationService.cancelAllNotifications();

    for (var schedule in _schedules) {
      if (!schedule.enabled) continue;

      try {
        if (schedule.isRecurring()) {
          // Schedule for each weekday
          for (int weekday in schedule.weekdays) {
            await _scheduleRecurring(schedule, weekday);
          }
        } else {
          // One-time schedule
          if (schedule.time.isAfter(DateTime.now())) {
            await NotificationService.scheduleNotification(
              id: schedule.id,
              title: 'Smart Home',
              body: _getNotificationMessage(schedule.command),
              scheduledDate: schedule.time,
            );
          }
        }
      } catch (e) {
        print("Error scheduling notification for ${schedule.id}: $e");
      }
    }
  }

  Future<void> _scheduleRecurring(Schedule schedule, int weekday) async {
    final now = DateTime.now();
    final scheduleTime = TimeOfDay.fromDateTime(schedule.time);
    var nextDate = DateTime(
        now.year, now.month, now.day, scheduleTime.hour, scheduleTime.minute);

    // Calculate next occurrence
    int daysUntil = (weekday - now.weekday) % 7;
    if (daysUntil == 0 && nextDate.isBefore(now)) {
      daysUntil = 7;
    }
    nextDate = nextDate.add(Duration(days: daysUntil));

    if (nextDate.isAfter(now)) {
      await NotificationService.scheduleNotification(
        id: schedule.id * 10 + weekday, // Unique ID for each weekday
        title: 'Smart Home',
        body: _getNotificationMessage(schedule.command),
        scheduledDate: nextDate,
      );
    }
  }

  void _checkSchedules() {
    final now = DateTime.now();

    for (var schedule in _schedules) {
      if (!schedule.enabled) continue;

      bool isTime = false;

      if (schedule.isRecurring()) {
        // Recurring: Check weekday and HH:mm
        if (schedule.weekdays.contains(now.weekday) &&
            schedule.time.hour == now.hour &&
            schedule.time.minute == now.minute) {
          isTime = true;
        }
      } else {
        // One-time: Check exact Date and HH:mm
        if (schedule.time.year == now.year &&
            schedule.time.month == now.month &&
            schedule.time.day == now.day &&
            schedule.time.hour == now.hour &&
            schedule.time.minute == now.minute) {
          isTime = true;
        }
      }

      if (isTime) {
        String executionKey =
            "${schedule.id}-${DateFormat('yyyyMMddHHmm').format(now)}";

        if (!_executedSchedules.contains(executionKey)) {
          executeSchedule(schedule);
          _executedSchedules.add(executionKey);

          // Cleanup old keys periodically?
          // For now simply limit set size if it grows too big
          if (_executedSchedules.length > 100) {
            _executedSchedules.clear();
            _executedSchedules.add(executionKey);
          }
        }
      }
    }
  }

  Future<void> executeSchedule(Schedule schedule) async {
    if (_bluetooth.isConnected) {
      await _command.sendCommand(schedule.command, source: 'Schedule');
      await NotificationService.showNotification(
        'Smart Home',
        _getNotificationMessage(schedule.command),
      );
    } else {
      await NotificationService.showNotification(
        'Smart Home',
        '${_getNotificationMessage(schedule.command)}\nTap to connect.',
      );
    }
  }

  String _getNotificationMessage(String command) {
    final cmd = command.toLowerCase().trim();
    if (cmd == "light on") return "The light is turned ON";
    if (cmd == "light off") return "The light is turned OFF";
    if (cmd == "fan on") return "The fan is turned ON";
    if (cmd == "fan off") return "The fan is turned OFF";
    if (cmd == "all on") return "Everything is turned ON";
    if (cmd == "all off") return "Everything is turned OFF";
    if (cmd == "neon on") return "Neon light is turned ON";
    if (cmd == "neon off") return "Neon light is turned OFF";

    // Default fallback
    return "Scheduled Command: $command";
  }
}
