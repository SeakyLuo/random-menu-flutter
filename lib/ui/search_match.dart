import 'dart:math';
import 'package:flutter/material.dart';

String searchMatchExcerpt(String text, String query) {
  final match = text.toLowerCase().indexOf(query.toLowerCase());
  final lineStart = text.lastIndexOf('\n', match) + 1;
  final start = max(lineStart, match - 6);
  final end = min(text.length, max(start + 80, match + query.length));
  final excerpt = text
      .substring(start, end)
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return '${start > lineStart ? '…' : ''}$excerpt${end < text.length ? '…' : ''}';
}

TextSpan highlightSearchText(
  String text,
  String query,
  Color color, {
  Color? backgroundColor,
}) {
  if (query.isEmpty) return TextSpan(text: text);
  final spans = <InlineSpan>[];
  final lower = text.toLowerCase();
  final term = query.toLowerCase();
  var cursor = 0;
  var match = lower.indexOf(term);
  while (match >= 0) {
    spans.add(TextSpan(text: text.substring(cursor, match)));
    cursor = match + term.length;
    spans.add(
      TextSpan(
        text: text.substring(match, cursor),
        style: TextStyle(
          color: color,
          backgroundColor: backgroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    match = lower.indexOf(term, cursor);
  }
  spans.add(TextSpan(text: text.substring(cursor)));
  return TextSpan(children: spans);
}

class SearchMatchCaption extends StatelessWidget {
  const SearchMatchCaption({
    super.key,
    required this.text,
    required this.query,
    required this.onTap,
  });
  final String text, query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
          child: Container(
            padding: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: scheme.primary.withValues(alpha: .22),
                  width: 2,
                ),
              ),
            ),
            child: Text.rich(
              highlightSearchText(text, query, scheme.primary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
