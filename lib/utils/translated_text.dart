import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';

class TranslatedText extends StatefulWidget {
  final String englishText;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool translate; // If false, shows English even in Urdu mode

  const TranslatedText({
    super.key,
    required this.englishText,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.translate = true,
  });

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  late Future<String> _translationFuture;

  @override
  void initState() {
    super.initState();
    _translationFuture = _getTranslation();
  }

  @override
  void didUpdateWidget(TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.englishText != widget.englishText) {
      _translationFuture = _getTranslation();
    }
  }

  Future<String> _getTranslation() async {
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);

    if (!widget.translate || !languageProvider.isUrdu) {
      return widget.englishText;
    }

    return await languageProvider.translate(widget.englishText);
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return FutureBuilder<String>(
      future: _translationFuture,
      builder: (context, snapshot) {
        String displayText;
        bool isLoading = false;

        if (snapshot.connectionState == ConnectionState.waiting) {
          displayText = widget.englishText;
          isLoading = true;
        } else if (snapshot.hasError) {
          displayText = widget.englishText;
        } else {
          displayText = snapshot.data ?? widget.englishText;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                displayText,
                style: widget.style,
                textAlign: widget.textAlign,
                maxLines: widget.maxLines,
                overflow: widget.overflow,
                textDirection: languageProvider.isUrdu && widget.translate
                    ? TextDirection.rtl
                    : TextDirection.ltr,
              ),
            ),
          ],
        );
      },
    );
  }
}

// For buttons and other widgets
class TranslatedButton extends StatelessWidget {
  final String englishText;
  final VoidCallback onPressed;
  final ButtonStyle? style;
  final Widget? icon;

  const TranslatedButton({
    super.key,
    required this.englishText,
    required this.onPressed,
    this.style,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: icon ?? const SizedBox.shrink(),
      label: TranslatedText(englishText: englishText),
    );
  }
}
