import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HuggingFaceTranslator {
  static const String _apiUrl =
      'https://api-inference.huggingface.co/models/Helsinki-NLP/opus-mt-en-ur';

  // For better performance, get a free token from https://huggingface.co/settings/tokens
  static const String _token = ''; // Optional - leave empty for public access

  static Future<String> translate(String englishText) async {
    // Check local cache first
    final cached = await _getCachedTranslation(englishText);
    if (cached != null) return cached;

    try {
      final headers = {
        'Content-Type': 'application/json',
        if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
      };

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: headers,
        body: json.encode({
          'inputs': englishText,
          'options': {
            'wait_for_model': true,
            'use_cache': true,
          },
        }),
      );

      if (response.statusCode == 200) {
        final List<dynamic> result = json.decode(response.body);
        if (result.isNotEmpty && result[0]['translation_text'] != null) {
          final translatedText = result[0]['translation_text'] as String;

          // Cache the translation
          await _cacheTranslation(englishText, translatedText);

          return translatedText;
        }
      } else if (response.statusCode == 503) {
        // Model loading, retry
        await Future.delayed(const Duration(seconds: 2));
        return await translate(englishText);
      }

      throw Exception('Translation failed: ${response.statusCode}');
    } catch (e) {
      // Fallback to simple dictionary for common words
      return _fallbackTranslation(englishText);
    }
  }

  static Future<void> _cacheTranslation(String english, String urdu) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'translation_${english.hashCode}';
    await prefs.setString(cacheKey, urdu);
  }

  static Future<String?> _getCachedTranslation(String english) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'translation_${english.hashCode}';
    return prefs.getString(cacheKey);
  }

  static String _fallbackTranslation(String english) {
    // Simple fallback for critical UI text
    final Map<String, String> fallback = {
      'Email': 'ای میل',
      'Password': 'پاس ورڈ',
      'Login': 'لاگ ان',
      'Welcome': 'خوش آمدید',
      'Error': 'خرابی',
      'Loading': 'لوڈ ہو رہا ہے',
      'Save': 'محفوظ کریں',
      'Cancel': 'منسوخ کریں',
      'Delete': 'حذف کریں',
      'Edit': 'ترمیم کریں',
      'Yes': 'جی ہاں',
      'No': 'نہیں',
      'OK': 'ٹھیک ہے',
      'Close': 'بند کریں',
      'Back': 'واپس',
      'Next': 'اگلا',
      'Submit': 'جمع کریں',
      'Search': 'تلاش کریں',
      'Settings': 'ترتیبات',
      'Profile': 'پروفائل',
      'Home': 'ہوم',
      'Logout': 'لاگ آؤٹ',
    };

    return fallback[english] ?? english;
  }
}
