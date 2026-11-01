import 'package:flutter/services.dart';

// Android Pattern uses Unicode classes even without an explicit Unicode flag.
// Keep the original expression in storage and compile its supported semantics.
// These previous Dart-translator notes now belong to the native engine:
// Java nested classes include union and intersection, unlike ECMAScript.
// ICU's default dot also excludes NEXT LINE, unlike ECMAScript dot.
// Native matching preserves these cases without rewriting the user's pattern.
const _patternChannel = MethodChannel('com.seakyluo.random_menu/tag_patterns');

Future<void> validateLegacyPatterns(List<String> patterns) async {
  if (patterns.isEmpty) return;
  try {
    await _patternChannel.invokeMethod<void>('validate', {
      'patterns': patterns,
    });
  } on PlatformException catch (error) {
    if (error.code == 'invalid_pattern') _invalidPattern();
    rethrow;
  }
}

Future<List<String>> matchLegacyPatterns(
  List<String> patterns,
  String text,
) async {
  if (patterns.isEmpty) return [];
  try {
    return (await _patternChannel.invokeListMethod<String>('match', {
      'patterns': patterns,
      'text': text,
    }))!;
  } on PlatformException catch (error) {
    if (error.code == 'invalid_pattern') _invalidPattern();
    rethrow;
  }
}

Never _invalidPattern() =>
    throw const FormatException('表达式格式不正确，或当前设备不支持这条规则。请检查后重试。');
