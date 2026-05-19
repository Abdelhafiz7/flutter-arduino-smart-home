import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/command_service.dart';

class RelaysScreen extends StatefulWidget {
  const RelaysScreen({super.key});

  @override
  State<RelaysScreen> createState() => _RelaysScreenState();
}

class _RelaysScreenState extends State<RelaysScreen> {
  final BluetoothService _bluetooth = BluetoothService();
  final CommandService _command = CommandService();
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _bluetooth.connectionStream.listen((connected) {
      if (mounted) {
        setState(() => _isConnected = connected);
      }
    });
    _isConnected = _bluetooth.isConnected;
  }

  Future<void> _sendCommand(String cmd) async {
    if (!_isConnected) {
      _showNotConnected();
      return;
    }
    await _command.sendCommand(cmd, source: 'Button');
  }

  void _showNotConnected() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please connect to Bluetooth device first'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relay Controls'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_isConnected)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Not connected to Bluetooth device'),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            _buildControlCard(
              'Light',
              Icons.lightbulb,
              Colors.amber,
              () => _sendCommand('light on'),
              () => _sendCommand('light off'),
            ),
            const SizedBox(height: 16),
            _buildControlCard(
              'Fan',
              Icons.ac_unit,
              Colors.blue,
              () => _sendCommand('fan on'),
              () => _sendCommand('fan off'),
            ),
            const SizedBox(height: 16),
            _buildControlCard(
              'All Devices',
              Icons.power,
              Colors.green,
              () => _sendCommand('all on'),
              () => _sendCommand('all off'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onOn,
    VoidCallback onOff,
  ) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? onOn : null,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('ON'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isConnected ? onOff : null,
                    icon: const Icon(Icons.power_off),
                    label: const Text('OFF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

