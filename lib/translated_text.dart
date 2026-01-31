import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/language/language_manager.dart';

class TranslatedText extends StatelessWidget {
  final String textKey;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final String? defaultValue;

  const TranslatedText({
    super.key,
    required this.textKey,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.defaultValue,
  });

  @override
  Widget build(BuildContext context) {
    final languageManager = Provider.of<LanguageManager>(context);

    return FutureBuilder<String>(
      future: Future.microtask(
          () => languageManager.translate(textKey, defaultValue: defaultValue)),
      builder: (context, snapshot) {
        final text = snapshot.data ?? defaultValue ?? textKey;

        return Text(
          text,
          style: style,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          textDirection:
              languageManager.isUrdu ? TextDirection.rtl : TextDirection.ltr,
        );
      },
    );
  }
}

// For dynamic text (not in registry)
class DynamicTranslatedText extends StatelessWidget {
  final String englishText;
  final TextStyle? style;
  final TextAlign? textAlign;

  const DynamicTranslatedText({
    super.key,
    required this.englishText,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final languageManager = Provider.of<LanguageManager>(context);

    return FutureBuilder<String>(
      future: languageManager.isUrdu
          ? _translateDynamicText(englishText, languageManager)
          : Future.value(englishText),
      builder: (context, snapshot) {
        final text = snapshot.data ?? englishText;

        return Text(
          text,
          style: style,
          textAlign: textAlign,
          textDirection:
              languageManager.isUrdu ? TextDirection.rtl : TextDirection.ltr,
        );
      },
    );
  }

  Future<String> _translateDynamicText(
      String text, LanguageManager manager) async {
    // This would need integration with translation service
    return text; // Placeholder
  }
}
