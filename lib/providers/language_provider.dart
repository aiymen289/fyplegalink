import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/translation_service.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _english = 'en';
  static const String _urdu = 'ur';

  String _currentLanguage = _english;
  Map<String, String> _englishTexts = {};
  Map<String, String> _urduTranslations = {};
  bool _isTranslating = false;

  // Getters
  String get currentLanguage => _currentLanguage;
  bool get isUrdu => _currentLanguage == _urdu;
  bool get isTranslating => _isTranslating;

  // Text registration system - Har screen apne texts register karegi
  void registerTexts(Map<String, String> texts) {
    _englishTexts.addAll(texts);

    // Agar Urdu mode hai aur ye texts translate nahi hue hain
    if (isUrdu) {
      for (var key in texts.keys) {
        if (!_urduTranslations.containsKey(key)) {
          _translateSingleText(key, texts[key]!);
        }
      }
    }
  }

  // Get translation for any text
  String translate(String key, {String? defaultValue}) {
    if (_currentLanguage == _english) {
      return _englishTexts[key] ?? defaultValue ?? key;
    } else {
      return _urduTranslations[key] ??
          _englishTexts[key] ??
          defaultValue ??
          key;
    }
  }

  // Global language switch - YE SIRF EK BAAR CALL KARNA HAI
  Future<void> toggleLanguage() async {
    if (_isTranslating) return;

    _isTranslating = true;
    notifyListeners();

    try {
      if (_currentLanguage == _english) {
        // Switch to Urdu - Translate ALL texts
        await _translateAllTextsToUrdu();
        _currentLanguage = _urdu;
      } else {
        // Switch to English
        _currentLanguage = _english;
      }

      // Save preference globally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', _currentLanguage);

      // Notify ALL screens
      notifyListeners();
    } catch (e) {
      print('Language toggle error: $e');
    } finally {
      _isTranslating = false;
    }
  }

  Future<void> _translateAllTextsToUrdu() async {
    try {
      final translationService = TranslationService();
      final translated =
          await translationService.translateMultiple(_englishTexts);
      _urduTranslations = translated;
    } catch (e) {
      print('Bulk translation error: $e');
      _useFallbackTranslations();
    }
  }

  Future<void> _translateSingleText(String key, String englishText) async {
    try {
      final translationService = TranslationService();
      final translated = await translationService.translateText(englishText);
      _urduTranslations[key] = translated;
      notifyListeners();
    } catch (e) {
      print('Single text translation error: $e');
    }
  }

// LanguageProvider.dart mein _useFallbackTranslations method update karein
  void _useFallbackTranslations() {
    // Complete fallback translations
    _urduTranslations = {
      'app_name': 'لیگل کنیکٹ',
      'choose_role': 'اپنا کردار منتخب کریں',
      'client_title': 'کلائنٹ',
      'client_subtitle': 'قانونی مشورہ حاصل کریں',
      'lawyer_title': 'وکیل',
      'lawyer_subtitle': 'قانونی خدمات فراہم کریں',
      'admin_title': 'ایڈمن',
      'admin_subtitle': 'پلیٹ فارم کا انتظام کریں',
      'login_text': 'پہلے سے اکاؤنٹ ہے؟ لاگ ان کریں',
      'version': 'ورژن 1.0.0',
      // Common texts
      'login': 'لاگ ان',
      'register': 'رجسٹر',
      'email': 'ای میل',
      'password': 'پاس ورڈ',
      'confirm_password': 'پاس ورڈ کی تصدیق',
      'name': 'نام',
      'phone': 'فون',
      'address': 'پتہ',
      'submit': 'جمع کرائیں',
      'cancel': 'منسوخ',
      'save': 'محفوظ کریں',
      'edit': 'ترمیم',
      'delete': 'حذف کریں',
      'search': 'تلاش کریں',
    };
  }

  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('app_language') ?? _english;

    // Agar Urdu hai toh load translations
    if (isUrdu && _urduTranslations.isEmpty) {
      await _translateAllTextsToUrdu();
    }

    notifyListeners();
  }
}
