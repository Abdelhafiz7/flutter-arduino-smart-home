import 'package:flutter/material.dart';
import '../services/phrase_mapping_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final PhraseMappingService _phraseMapping = PhraseMappingService();
  Map<String, Map<String, List<String>>> _mappings = {};

  @override
  void initState() {
    super.initState();
    _loadMappings();
  }

  void _loadMappings() {
    setState(() {
      _mappings = _phraseMapping.getAllMappings();
    });
  }

  Future<void> _editPhrases(String command) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PhraseEditScreen(command: command),
      ),
    );
    if (result == true) {
      _loadMappings();
    }
  }

  Future<void> _resetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text('Reset all phrase mappings to defaults?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _phraseMapping.resetToDefaults();
      _loadMappings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reset to defaults')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Voice Phrase Mappings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          ..._mappings.entries.map((entry) {
            final command = entry.key;
            final languages = entry.value;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(
                  command,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (languages.containsKey('en'))
                      Text('EN: ${languages['en']!.join(', ')}'),
                    if (languages.containsKey('tr'))
                      Text('TR: ${languages['tr']!.join(', ')}'),
                    if (languages.containsKey('ar'))
                      Text('AR: ${languages['ar']!.join(', ')}'),
                  ],
                ),
                trailing: const Icon(Icons.edit),
                onTap: () => _editPhrases(command),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class PhraseEditScreen extends StatefulWidget {
  final String command;

  const PhraseEditScreen({super.key, required this.command});

  @override
  State<PhraseEditScreen> createState() => _PhraseEditScreenState();
}

class _PhraseEditScreenState extends State<PhraseEditScreen> {
  final PhraseMappingService _phraseMapping = PhraseMappingService();
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    final mappings = _phraseMapping.getAllMappings();
    final commandMappings = mappings[widget.command] ?? {};
    
    for (String lang in ['en', 'tr', 'ar']) {
      final phrases = commandMappings[lang] ?? [];
      _controllers[lang] = TextEditingController(text: phrases.join(', '));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final Map<String, List<String>> languagePhrases = {};
    
    for (String lang in ['en', 'tr', 'ar']) {
      final text = _controllers[lang]!.text.trim();
      if (text.isNotEmpty) {
        languagePhrases[lang] = text
            .split(',')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
      }
    }

    await _phraseMapping.updateMapping(
      widget.command,
      'en',
      languagePhrases['en'] ?? [],
    );
    
    if (languagePhrases.containsKey('tr')) {
      await _phraseMapping.updateMapping(
        widget.command,
        'tr',
        languagePhrases['tr']!,
      );
    }
    
    if (languagePhrases.containsKey('ar')) {
      await _phraseMapping.updateMapping(
        widget.command,
        'ar',
        languagePhrases['ar']!,
      );
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit: ${widget.command}'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Enter phrases separated by commas',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          _buildLanguageField('English (EN)', 'en'),
          const SizedBox(height: 16),
          _buildLanguageField('Turkish (TR)', 'tr'),
          const SizedBox(height: 16),
          _buildLanguageField('Arabic (AR)', 'ar'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageField(String label, String lang) {
    return TextField(
      controller: _controllers[lang],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: 'Separate multiple phrases with commas',
      ),
      maxLines: 3,
    );
  }
}

