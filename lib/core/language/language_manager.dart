import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'translation_service.dart';

class LanguageManager extends ChangeNotifier {
  static const String _english = 'en';
  static const String _urdu = 'ur';

  String _currentLanguage = _english;
  Map<String, String> _englishTexts = {};
  Map<String, String> _urduTranslations = {};
  bool _isTranslating = false;

  String get currentLanguage => _currentLanguage;
  bool get isUrdu => _currentLanguage == _urdu;
  bool get isTranslating => _isTranslating;

  LanguageManager() {
    _loadSavedLanguage();
    _initializeDefaultTexts();
  }

  // ========== TEXT REGISTRATION SYSTEM ==========
  // Har screen apne texts register karegi
  void registerTexts(Map<String, String> texts) {
    _englishTexts.addAll(texts);

    // Agar Urdu mode hai, toh translate karein
    if (isUrdu && !_urduTranslations.containsKey(texts.values.first)) {
      _translateNewTexts(texts);
    }
  }

  // Get translation for a key
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

  // ========== LANGUAGE SWITCHING ==========
  Future<void> toggleLanguage() async {
    if (_isTranslating) return;

    _isTranslating = true;
    notifyListeners();

    try {
      if (_currentLanguage == _english) {
        // English → Urdu
        await _translateToUrdu();
        _currentLanguage = _urdu;
      } else {
        // Urdu → English
        _currentLanguage = _english;
      }

      // Save preference
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', _currentLanguage);
    } catch (e) {
      print('Language toggle error: $e');
    } finally {
      _isTranslating = false;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (languageCode == _currentLanguage) return;

    _isTranslating = true;
    notifyListeners();

    try {
      if (languageCode == _urdu && _currentLanguage == _english) {
        await _translateToUrdu();
      }

      _currentLanguage = languageCode;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', languageCode);
    } catch (e) {
      print('Set language error: $e');
    } finally {
      _isTranslating = false;
      notifyListeners();
    }
  }

  // ========== PRIVATE METHODS ==========
  Future<void> _loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString('app_language') ?? _english;

    // Load cached Urdu translations
    await _loadCachedTranslations();
  }

  void _initializeDefaultTexts() {
    // Common app texts
    _englishTexts = {
      'app_name': 'Legal Connect',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'view': 'View',
      'search': 'Search',
      'settings': 'Settings',
      'profile': 'Profile',
      'logout': 'Logout',
      'login': 'Login',
      'register': 'Register',
      'welcome': 'Welcome',
      'home': 'Home',
      'back': 'Back',
      'next': 'Next',
      'previous': 'Previous',
      'submit': 'Submit',
      'reset': 'Reset',
      'confirm': 'Confirm',
      'yes': 'Yes',
      'no': 'No',
      'ok': 'OK',
    };
  }

  Future<void> _translateToUrdu() async {
    if (_urduTranslations.isNotEmpty &&
        _urduTranslations.length == _englishTexts.length) {
      return; // Already translated
    }

    try {
      final translated =
          await HuggingFaceTranslationService.translateMultiple(_englishTexts);
      _urduTranslations = translated;
    } catch (e) {
      print('Bulk translation error: $e');
      // Use fallback
      _useFallbackTranslations();
    }
  }

  Future<void> _translateNewTexts(Map<String, String> newTexts) async {
    try {
      final translated =
          await HuggingFaceTranslationService.translateMultiple(newTexts);
      _urduTranslations.addAll(translated);
      notifyListeners();
    } catch (e) {
      print('New texts translation error: $e');
    }
  }

  Future<void> _loadCachedTranslations() async {
    // Implementation for loading cached translations
    // You can store translations in SQLite or SharedPreferences
  }

  void _useFallbackTranslations() {
    // Simple fallback dictionary
    _urduTranslations = {
      'app_name': 'لیگل کنیکٹ',
      'loading': 'لوڈ ہو رہا ہے...',
      'error': 'خرابی',
      'success': 'کامیابی',
      'cancel': 'منسوخ کریں',
      'save': 'محفوظ کریں',
      'delete': 'حذف کریں',
      'edit': 'ترمیم کریں',
      'view': 'دیکھیں',
      'search': 'تلاش کریں',
      'settings': 'ترتیبات',
      'profile': 'پروفائل',
      'logout': 'لاگ آؤٹ',
      'login': 'لاگ ان',
      'register': 'رجسٹر کریں',
      'welcome': 'خوش آمدید',
      'home': 'ہوم',
      'back': 'واپس',
      'next': 'اگلا',
      'previous': 'پچھلا',
      'submit': 'جمع کروائیں',
      'reset': 'دوبارہ ترتیب دیں',
      'confirm': 'تصدیق کریں',
      'yes': 'جی ہاں',
      'no': 'نہیں',
      'ok': 'ٹھیک ہے',
    };
  }

  // Clear all translations (for debugging)
  Future<void> clearTranslations() async {
    _urduTranslations.clear();
    await HuggingFaceTranslationService.clearCache();
    notifyListeners();
  }
}
