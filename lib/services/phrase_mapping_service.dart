import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PhraseMappingService {
  static final PhraseMappingService _instance =
      PhraseMappingService._internal();
  factory PhraseMappingService() => _instance;
  PhraseMappingService._internal();

  static const String _key = 'phrase_mappings';
  Map<String, Map<String, List<String>>> _mappings = {};

  static Future<void> initialize() async {
    await _instance._loadMappings();
    await _instance._loadMappings();
    // Force update defaults to ensure new synonyms are applied
    // In production this should be versioned
    await _instance._loadDefaults();
    print(
        "DEBUG: Phrase mappings loaded: ${_instance._mappings.keys.length} commands");
  }

  Future<void> _loadMappings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      _mappings = Map<String, Map<String, List<String>>>.from(
        json.decode(jsonString).map((key, value) => MapEntry(
              key,
              Map<String, List<String>>.from(value.map((k, v) => MapEntry(
                    k,
                    List<String>.from(v),
                  ))),
            )),
      );
    }
  }

  Future<void> _saveMappings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(_mappings));
  }

  Future<void> _loadDefaults() async {
    _mappings = {
      'light on': {
        'en': [
          'light on',
          'turn on light',
          'lights on',
          'open light',
          'open lights'
        ],
        'tr': ['ışığı aç', 'lambayı aç', 'ışık aç', 'lama aç', 'lamba aç'],
      },
      'light off': {
        'en': [
          'light off',
          'turn off light',
          'lights off',
          'light of',
          'lights of',
          'turn of light',
          'close light'
        ],
        'tr': [
          'ışığı kapat',
          'lambayı kapat',
          'ışık kapat',
          'lama kapat',
          'lamba kapat',
          'ışık kapa',
          'lambayı kapa'
        ],
      },
      'fan on': {
        'en': ['fan on', 'turn on fan', 'open fan', 'start fan'],
        'tr': [
          'fan aç',
          'vantilatör aç',
          'pervane aç',
          'fen aç',
          'fanı aç',
          'havalandırma aç'
        ],
      },
      'fan off': {
        'en': [
          'fan off',
          'turn off fan',
          'fan of',
          'turn of fan',
          'close fan',
          'stop fan'
        ],
        'tr': [
          'fan kapat',
          'vantilatör kapat',
          'pervane kapat',
          'fen kapat',
          'fanı kapat',
          'havalandırma kapat',
          'fan dur',
          'pervane dur'
        ],
      },
      'all on': {
        'en': ['all on', 'turn everything on', 'all one', 'open all'],
        'tr': [
          'hepsini aç',
          'hepsi açık',
          'her şeyi aç',
          'tümünü aç',
          'bütün ışıkları aç',
          'herşeyi aç'
        ],
      },
      'all off': {
        'en': [
          'all off',
          'turn everything off',
          'all of',
          'close all',
          'stop all'
        ],
        'tr': [
          'hepsini kapat',
          'hepsi kapalı',
          'her şeyi kapat',
          'tümünü kapat',
          'bütün ışıkları kapat',
          'herşeyi kapat',
          'komple kapat'
        ],
      },
      'red': {
        'en': ['red', 'color red'],
        'tr': ['kırmızı', 'kırımzı', 'kırmız', 'al'],
      },
      'green': {
        'en': ['green', 'color green'],
        'tr': ['yeşil', 'yesil'],
      },
      'blue': {
        'en': ['blue', 'color blue'],
        'tr': ['mavi'],
      },
      'white': {
        'en': ['white', 'color white'],
        'tr': ['beyaz'],
      },
      'yellow': {
        'en': ['yellow'],
        'tr': ['sarı', 'sari'],
      },
      'purple': {
        'en': ['purple'],
        'tr': ['mor'],
      },
      'orange': {
        'en': ['orange'],
        'tr': ['turuncu', 'portakal'],
      },
      'pink': {
        'en': ['pink'],
        'tr': ['pembe'],
      },
      'cyan': {
        'en': ['cyan'],
        'tr': ['camgöbeği', 'cam göbeği', 'turkuaz'],
      },
      'magenta': {
        'en': ['magenta'],
        'tr': ['macenta'],
      },
      'fire': {
        'en': ['fire', 'fire mode', 'fire effect'],
        'tr': ['ateş'],
      },
      'rain': {
        'en': ['rain', 'rain mode', 'rain effect'],
        'tr': ['yağmur'],
      },
      'police': {
        'en': ['police', 'police mode'],
        'tr': ['polis'],
      },
      'party': {
        'en': ['party', 'party mode'],
        'tr': ['parti'],
      },
      'breath': {
        'en': ['breath', 'breathing', 'breath mode'],
        'tr': ['nefes'],
      },
      'stop': {
        'en': ['stop', 'stop effect', 'stop animation'],
        'tr': ['dur'],
      },
      'neon on': {
        'en': ['neon on', 'turn on neon', 'start neon', 'open neon'],
        'tr': ['neon aç'],
      },
      'neon off': {
        'en': ['neon off', 'turn off neon', 'neon of', 'close neon'],
        'tr': ['neon kapat'],
      },
    };
    await _saveMappings();
  }

  String? findCommand(String phrase, String language) {
    for (var entry in _mappings.entries) {
      final phrases = entry.value[language] ?? [];
      if (phrases.any((p) => phrase.toLowerCase().contains(p.toLowerCase()))) {
        return entry.key;
      }
    }

    // Fuzzy matching fallback
    String? bestMatchCommand;
    int bestDistance = 100;

    for (var entry in _mappings.entries) {
      final phrases = entry.value[language] ?? [];
      for (var p in phrases) {
        int dist = _levenshtein(phrase.toLowerCase(), p.toLowerCase());
        int threshold = p.length > 4 ? 2 : 1;

        if (dist <= threshold && dist < bestDistance) {
          bestDistance = dist;
          bestMatchCommand = entry.key;
        }
      }
    }

    return bestMatchCommand;
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < t.length + 1; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        int cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
      for (int j = 0; j < t.length + 1; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }

  List<String> getPhrases(String command, String language) {
    return _mappings[command]?[language] ?? [];
  }

  Map<String, Map<String, List<String>>> getAllMappings() {
    return Map.from(_mappings);
  }

  Future<void> updateMapping(
      String command, String language, List<String> phrases) async {
    if (!_mappings.containsKey(command)) {
      _mappings[command] = {};
    }
    _mappings[command]![language] = phrases;
    await _saveMappings();
  }

  Future<void> addCommand(
      String command, Map<String, List<String>> languagePhrases) async {
    _mappings[command] = languagePhrases;
    await _saveMappings();
  }

  Future<void> resetToDefaults() async {
    _mappings.clear();
    await _loadDefaults();
  }
}
