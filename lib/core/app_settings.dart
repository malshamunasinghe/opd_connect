import 'package:flutter/material.dart';

import 'strings.dart';

/// Holds the accessibility preferences from S22 (language, text size,
/// contrast). Loaded from the signed-in user's Firestore profile and applied
/// app-wide through the MaterialApp builder.
class AppSettings extends ChangeNotifier {
  String _lang = 'en';
  double _textScale = 1.0;
  bool _highContrast = false;

  String get lang => _lang;
  double get textScale => _textScale;
  bool get highContrast => _highContrast;

  /// Text sizes offered on S22. 1.15 matches the "Body Large" 18 sp style.
  static const textScales = [1.0, 1.15, 1.3];

  String t(String key) => S.of(_lang, key);

  /// Translated text with {placeholders}, e.g. `tf('forPerson', {'name': 'Nimal'})`.
  String tf(String key, Map<String, String> args) {
    var text = S.of(_lang, key);
    args.forEach((k, v) => text = text.replaceAll('{$k}', v));
    return text;
  }

  void apply({String? lang, double? textScale, bool? highContrast}) {
    var changed = false;
    if (lang != null && S.supported.contains(lang) && lang != _lang) {
      _lang = lang;
      changed = true;
    }
    if (textScale != null && textScale != _textScale) {
      _textScale = textScale.clamp(1.0, 1.3);
      changed = true;
    }
    if (highContrast != null && highContrast != _highContrast) {
      _highContrast = highContrast;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void reset() => apply(lang: 'en', textScale: 1.0, highContrast: false);
}
