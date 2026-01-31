import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/language/language_manager.dart';

class LanguageSwitchButton extends StatelessWidget {
  final bool showLabel;

  const LanguageSwitchButton({
    super.key,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final languageManager = Provider.of<LanguageManager>(context);

    return ElevatedButton.icon(
      onPressed: languageManager.isTranslating
          ? null
          : () {
              languageManager.toggleLanguage();
            },
      icon: languageManager.isTranslating
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Icon(
              Icons.translate,
              color: Colors.white,
            ),
      label: showLabel
          ? Text(
              languageManager.isUrdu ? 'English' : 'اردو',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            )
          : const SizedBox.shrink(),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
