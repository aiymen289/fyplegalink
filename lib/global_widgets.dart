import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

// 1. Language Switch Button (Use in ANY screen)
class GlobalLanguageSwitch extends StatelessWidget {
  const GlobalLanguageSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LanguageProvider>(context);

    return IconButton(
      icon: provider.isTranslating
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Icon(Icons.translate, color: Colors.white),
      onPressed: provider.isTranslating
          ? null
          : () {
              provider.toggleLanguage();
            },
      tooltip: provider.isUrdu ? 'Switch to English' : 'اردو میں تبدیلی',
    );
  }
}

// 2. Text that automatically translates
class TranslatableText extends StatelessWidget {
  final String textKey;
  final String englishText;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TranslatableText({
    super.key,
    required this.textKey,
    required this.englishText,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<LanguageProvider>(context);

    // Register this text with provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      provider.registerTexts({textKey: englishText});
    });

    final text = provider.translate(textKey, defaultValue: englishText);

    return Text(
      text,
      style: style,
      textAlign:
          textAlign ?? (provider.isUrdu ? TextAlign.right : TextAlign.left),
      textDirection: provider.isUrdu ? TextDirection.rtl : TextDirection.ltr,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
