import 'bluetooth_service.dart';
import 'command_log_service.dart';

class CommandService {
  static final CommandService _instance = CommandService._internal();
  factory CommandService() => _instance;
  CommandService._internal();

  final BluetoothService _bluetooth = BluetoothService();

  Future<bool> sendCommand(String cmd, {String source = 'Button'}) async {
    final command = cmd.toLowerCase().trim();
    final success = await _bluetooth.sendCommand(command);
    
    await CommandLogService().addLog(
      command,
      source,
      success ? 'Sent' : (_bluetooth.isConnected ? 'Failed' : 'Not connected'),
    );

    return success;
  }
}

