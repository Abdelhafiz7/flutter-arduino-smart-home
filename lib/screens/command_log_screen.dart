import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/command_log_service.dart';

class CommandLogScreen extends StatefulWidget {
  const CommandLogScreen({super.key});

  @override
  State<CommandLogScreen> createState() => _CommandLogScreenState();
}

class _CommandLogScreenState extends State<CommandLogScreen> {
  List<CommandLogEntry> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  void _loadLogs() {
    setState(() {
      _logs = CommandLogService().getLogs();
    });
  }

  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Log'),
        content: const Text('Clear all command logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await CommandLogService().clearLogs();
      _loadLogs();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Sent':
        return Colors.green;
      case 'Not connected':
        return Colors.orange;
      case 'Failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'Voice':
        return Icons.mic;
      case 'Schedule':
        return Icons.schedule;
      case 'Button':
      default:
        return Icons.touch_app;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Command Log'),
        actions: [
          if (_logs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: _clearLogs,
              tooltip: 'Clear log',
            ),
        ],
      ),
      body: _logs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No commands logged yet'),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => _loadLogs(),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(log.status).withOpacity(0.2),
                        child: Icon(
                          _getSourceIcon(log.source),
                          color: _getStatusColor(log.status),
                        ),
                      ),
                      title: Text(
                        log.command,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                _getSourceIcon(log.source),
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                log.source,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(log.status).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  log.status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _getStatusColor(log.status),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

