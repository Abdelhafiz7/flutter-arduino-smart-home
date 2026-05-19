import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/command_service.dart';
import 'voice_control_screen.dart';

class LightingScreen extends StatefulWidget {
  const LightingScreen({super.key});

  @override
  State<LightingScreen> createState() => _LightingScreenState();
}

class _LightingScreenState extends State<LightingScreen> {
  final BluetoothService _bluetooth = BluetoothService();
  final CommandService _command = CommandService();
  bool _isConnected = false;
  
  int _red = 255;
  int _green = 255;
  int _blue = 255;
  int _brightness = 255;

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

  final List<Map<String, dynamic>> _colorPresets = [
    {'name': 'Red', 'color': Colors.red, 'cmd': 'red'},
    {'name': 'Green', 'color': Colors.green, 'cmd': 'green'},
    {'name': 'Blue', 'color': Colors.blue, 'cmd': 'blue'},
    {'name': 'White', 'color': Colors.white, 'cmd': 'white'},
    {'name': 'Yellow', 'color': Colors.yellow, 'cmd': 'yellow'},
    {'name': 'Purple', 'color': Colors.purple, 'cmd': 'purple'},
    {'name': 'Orange', 'color': Colors.orange, 'cmd': 'orange'},
    {'name': 'Pink', 'color': Colors.pink, 'cmd': 'pink'},
    {'name': 'Cyan', 'color': Colors.cyan, 'cmd': 'cyan'},
    {'name': 'Magenta', 'color': Colors.pinkAccent, 'cmd': 'magenta'},
  ];

  final List<Map<String, dynamic>> _effects = [
    {'name': 'Rain', 'icon': Icons.grain, 'cmd': 'rain'},
    {'name': 'Breath', 'icon': Icons.air, 'cmd': 'breath'},
    {'name': 'Police', 'icon': Icons.local_police, 'cmd': 'police'},
    {'name': 'Fire', 'icon': Icons.local_fire_department, 'cmd': 'fire'},
    {'name': 'Party', 'icon': Icons.celebration, 'cmd': 'party'},
    {'name': 'Stop', 'icon': Icons.stop, 'cmd': 'stop'},
    {'name': 'Neon Off', 'icon': Icons.power_off, 'cmd': 'neon off'},
  ];

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
        title: const Text('Lighting Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const VoiceControlScreen()),
              );
            },
            tooltip: 'Voice Control',
          ),
        ],
      ),
      body: SingleChildScrollView(
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
            const SizedBox(height: 16),
            _buildSectionTitle('Color Presets'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colorPresets.map((preset) {
                return ElevatedButton(
                  onPressed: _isConnected
                      ? () => _sendCommand(preset['cmd'])
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: preset['color'],
                    foregroundColor: _getContrastColor(preset['color']),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: Text(preset['name']),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('RGB Control'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildColorSlider('Red', _red.toDouble(), Colors.red, (value) {
                      setState(() => _red = value.round());
                    }),
                    _buildColorSlider('Green', _green.toDouble(), Colors.green, (value) {
                      setState(() => _green = value.round());
                    }),
                    _buildColorSlider('Blue', _blue.toDouble(), Colors.blue, (value) {
                      setState(() => _blue = value.round());
                    }),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(_red, _green, _blue, 1.0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isConnected
                          ? () => _sendCommand('rgb $_red $_green $_blue')
                          : null,
                      icon: const Icon(Icons.send),
                      label: const Text('Send RGB'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Brightness'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _brightness.toDouble(),
                            min: 0,
                            max: 255,
                            divisions: 255,
                            label: _brightness.toString(),
                            onChanged: (value) {
                              setState(() => _brightness = value.round());
                            },
                            onChangeEnd: (value) {
                              if (_isConnected) {
                                _sendCommand('bright ${value.round()}');
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            _brightness.toString(),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('Effects'),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _effects.map((effect) {
                return ElevatedButton.icon(
                  onPressed: _isConnected
                      ? () => _sendCommand(effect['cmd'])
                      : null,
                  icon: Icon(effect['icon']),
                  label: Text(effect['name']),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildColorSlider(String label, double value, Color color, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value.round().toString()),
          ],
        ),
        Slider(
          value: value,
          min: 0,
          max: 255,
          divisions: 255,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Color _getContrastColor(Color color) {
    final luminance = color.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}

