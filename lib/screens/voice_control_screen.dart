import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/bluetooth_service.dart';
import '../services/command_service.dart';
import '../services/phrase_mapping_service.dart';

class VoiceControlScreen extends StatefulWidget {
  const VoiceControlScreen({super.key});

  @override
  State<VoiceControlScreen> createState() => _VoiceControlScreenState();
}

class _VoiceControlScreenState extends State<VoiceControlScreen> {
  final BluetoothService _bluetooth = BluetoothService();
  final CommandService _command = CommandService();
  final PhraseMappingService _phraseMapping = PhraseMappingService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isConnected = false;
  bool _isListening = false;
  String _recognizedText = '';
  String _selectedLanguage = 'auto';
  bool _speechAvailable = false;

  final Map<String, String> _languageCodes = {
    'auto': 'Auto',
    'en': 'English',
    'tr': 'Turkish',
  };

  @override
  void initState() {
    super.initState();
    _checkSpeechAvailability();
    _bluetooth.connectionStream.listen((connected) {
      if (mounted) {
        setState(() => _isConnected = connected);
      }
    });
    _isConnected = _bluetooth.isConnected;
  }

  Future<void> _checkSpeechAvailability() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (mounted) {
          setState(() {
            if (status == 'done' || status == 'notListening') {
              _isListening = false;
            }
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Speech recognition error: $error')),
          );
        }
      },
    );
    setState(() => _speechAvailable = available);
  }

  void _startListening() async {
    if (!_speechAvailable || _isListening) return;

    String localeId = 'en_US';
    if (_selectedLanguage == 'tr') {
      localeId = 'tr_TR';
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
        });

        if (result.finalResult) {
          _processVoiceCommand(result.recognizedWords);
        }
      },
      localeId: localeId,
      listenMode: stt.ListenMode.confirmation,
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void _processVoiceCommand(String rawText) {
    if (rawText.isEmpty) return;

    // Remove punctuation
    String text = rawText.replaceAll(RegExp(r'[^\w\s]'), '');

    String? command;

    // Try to find command in selected language or auto-detect
    if (_selectedLanguage == 'auto') {
      for (String lang in ['en', 'tr']) {
        command = _phraseMapping.findCommand(text, lang);
        if (command != null) break;
      }
    } else {
      command = _phraseMapping.findCommand(text, _selectedLanguage);
    }

    // Handle brightness commands
    if (command == null) {
      final brightnessMatch =
          RegExp(r'(\d+)', caseSensitive: false).firstMatch(text);
      if (brightnessMatch != null) {
        final number = brightnessMatch.group(1);
        if (text.toLowerCase().contains('bright') ||
            text.toLowerCase().contains('parlaklık') ||
            text.toLowerCase().contains('سطوع')) {
          command = 'bright $number';
        }
      }
    }

    if (command != null) {
      // Direct execute without confirmation
      _sendCommand(command);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Command not recognized: $text'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _showConfirmationDialog(String command, String recognizedText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Command'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recognized: "$recognizedText"'),
            const SizedBox(height: 8),
            Text('Command: "$command"'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendCommand(command);
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCommand(String cmd) async {
    if (!_isConnected) {
      _showNotConnected();
      return;
    }
    await _command.sendCommand(cmd, source: 'Voice');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Command sent: $cmd'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
        title: const Text('Voice Control'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      'Select Language',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButton<String>(
                      value: _selectedLanguage,
                      isExpanded: true,
                      items: _languageCodes.entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedLanguage = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isListening ? Colors.red : Colors.blue,
              ),
              child: IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 48,
                  color: Colors.white,
                ),
                onPressed: _speechAvailable && _isConnected
                    ? (_isListening ? _stopListening : _startListening)
                    : null,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isListening ? 'Listening...' : 'Tap to speak',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            if (_recognizedText.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recognized Text:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _recognizedText,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            if (!_speechAvailable)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Speech recognition not available. Please check permissions.',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
