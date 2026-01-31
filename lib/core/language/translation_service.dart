import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class HuggingFaceTranslationService {
  static const String _apiUrl =
      'https://api-inference.huggingface.co/models/Helsinki-NLP/opus-mt-en-ur';
  static final Map<String, String> _translationCache = {};

  // Get translation for ANY text
  static Future<String> translateText(String englishText) async {
    if (englishText.trim().isEmpty) return englishText;

    // Check cache first
    if (_translationCache.containsKey(englishText)) {
      return _translationCache[englishText]!;
    }

    try {
      // Load cache from storage
      await _loadCacheFromStorage();

      // Check again after loading
      if (_translationCache.containsKey(englishText)) {
        return _translationCache[englishText]!;
      }

      // Call Hugging Face API
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'inputs': englishText}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> result = json.decode(response.body);
        if (result.isNotEmpty) {
          String translatedText = result[0]['translation_text'] ?? englishText;

          // Clean the translation
          translatedText = _cleanTranslation(translatedText);

          // Cache it
          _translationCache[englishText] = translatedText;
          await _saveToCache(englishText, translatedText);

          return translatedText;
        }
      }

      return englishText;
    } catch (e) {
      print('Translation error for "$englishText": $e');
      return englishText;
    }
  }

  // Batch translate for performance
  static Future<Map<String, String>> translateMultiple(
      Map<String, String> texts) async {
    final Map<String, String> results = {};

    for (var entry in texts.entries) {
      results[entry.key] = await translateText(entry.value);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    return results;
  }

  static String _cleanTranslation(String text) {
    return text
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .trim();
  }

  static Future<void> _saveToCache(String english, String urdu) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'translation_cache_${english.hashCode}';
    await prefs.setString(cacheKey, urdu);
  }

  static Future<void> _loadCacheFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith('translation_cache_'))
        .toList();

    for (var key in keys) {
      final englishText = key.replaceFirst('translation_cache_', '');
      final urduText = prefs.getString(key) ?? '';
      if (urduText.isNotEmpty) {
        _translationCache[englishText] = urduText;
      }
    }
  }

  // Clear cache (optional)
  static Future<void> clearCache() async {
    _translationCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith('translation_cache_'))
        .toList();
    for (var key in keys) {
      await prefs.remove(key);
    }
  }
}
