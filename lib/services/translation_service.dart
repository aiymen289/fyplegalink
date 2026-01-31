import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TranslationService {
  static const String _apiUrl =
      'https://api-inference.huggingface.co/models/Helsinki-NLP/opus-mt-en-ur';
  static final Map<String, String> _cache = {};

  Future<String> translateText(String englishText) async {
    if (_cache.containsKey(englishText)) {
      print("Using cached translation for: $englishText");
      return _cache[englishText]!;
    }

    try {
      print("Calling API to translate: $englishText"); // <--- Add this
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'inputs': englishText}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result is List && result.isNotEmpty) {
          final translated =
              result[0]['translation_text']?.toString() ?? englishText;
          print("API translated: $englishText → $translated"); // <--- Add this
          _cache[englishText] = translated;
          await _saveToCache(englishText, translated);
          return translated;
        }
      } else {
        print("API call failed with status: ${response.statusCode}");
      }
    } catch (e) {
      print('Translation error: $e');
    }

    return englishText;
  }

  Future<Map<String, String>> translateMultiple(
      Map<String, String> texts) async {
    final Map<String, String> results = {};

    for (var entry in texts.entries) {
      results[entry.key] = await translateText(entry.value);
      await Future.delayed(const Duration(milliseconds: 200)); // Rate limiting
    }

    return results;
  }

  Future<void> _saveToCache(String english, String urdu) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'trans_${english.hashCode}';
    await prefs.setString(cacheKey, urdu);
  }
}
