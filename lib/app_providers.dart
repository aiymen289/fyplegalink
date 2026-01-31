import 'package:flutter/material.dart';
import 'core/language/language_manager.dart';
import 'package:provider/provider.dart';

class AppProviders {
  static List<ChangeNotifierProvider> get providers => [
        ChangeNotifierProvider<LanguageManager>(
          create: (_) => LanguageManager(),
          lazy: false, // Initialize immediately
        ),
      ];
}
