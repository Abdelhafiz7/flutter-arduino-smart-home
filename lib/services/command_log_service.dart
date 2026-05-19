import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CommandLogEntry {
  final String command;
  final String source;
  final DateTime timestamp;
  final String status;

  CommandLogEntry({
    required this.command,
    required this.source,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'command': command,
    'source': source,
    'timestamp': timestamp.toIso8601String(),
    'status': status,
  };

  factory CommandLogEntry.fromJson(Map<String, dynamic> json) => CommandLogEntry(
    command: json['command'],
    source: json['source'],
    timestamp: DateTime.parse(json['timestamp']),
    status: json['status'],
  );
}

class CommandLogService {
  static final CommandLogService _instance = CommandLogService._internal();
  factory CommandLogService() => _instance;
  CommandLogService._internal();

  static const String _key = 'command_log';
  static const int _maxEntries = 30;
  List<CommandLogEntry> _logs = [];

  static Future<void> initialize() async {
    await _instance._loadLogs();
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      final List<dynamic> decoded = json.decode(jsonString);
      _logs = decoded.map((e) => CommandLogEntry.fromJson(e)).toList();
    }
  }

  Future<void> _saveLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(_logs.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }

  Future<void> addLog(String command, String source, String status) async {
    _logs.insert(0, CommandLogEntry(
      command: command,
      source: source,
      timestamp: DateTime.now(),
      status: status,
    ));

    if (_logs.length > _maxEntries) {
      _logs = _logs.take(_maxEntries).toList();
    }

    await _saveLogs();
  }

  List<CommandLogEntry> getLogs() {
    return List.from(_logs);
  }

  Future<void> clearLogs() async {
    _logs.clear();
    await _saveLogs();
  }
}

