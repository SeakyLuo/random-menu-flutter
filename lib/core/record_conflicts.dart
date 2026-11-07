import 'dart:convert';

/// Editors must not overwrite an AI update made after the form was opened.
void requireUnchangedRecord(
  Map<String, dynamic> before,
  Map<String, dynamic>? current, {
  Set<String> ignored = const {},
}) {
  Map<String, dynamic> fields(Map<String, dynamic> value) => {
    for (final entry in value.entries)
      if (!ignored.contains(entry.key)) entry.key: entry.value,
  };
  if (current == null ||
      jsonEncode(fields(before)) != jsonEncode(fields(current))) {
    throw StateError('这条记录已被其他页面或 AI 修改，请重新打开后编辑。本次输入尚未保存。');
  }
}
