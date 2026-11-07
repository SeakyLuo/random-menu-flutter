import 'dart:math';
import '../../core/models.dart';

enum RecipeSearchField { all, name, tags, note }

int _textScore(String text, String query, [int offset = 0]) {
  if (text.isEmpty) return 0;
  var score = 0;
  if (text == query) {
    score = 100;
  } else if (text.startsWith(query)) {
    score = 95;
  } else if (text.endsWith(query)) {
    score = 90;
  } else if (text.contains(query)) {
    score = 85;
  } else {
    final length = max(text.length, query.length);
    if ((text.length - query.length).abs() * 100 ~/ length > 60) {
      return max(offset, 0);
    }
    var previous = List.generate(query.length + 1, (i) => i);
    for (var i = 1; i <= text.length; i++) {
      final current = List.filled(query.length + 1, 0)..[0] = i;
      for (var j = 1; j <= query.length; j++) {
        current[j] = min(
          min(previous[j] + 1, current[j - 1] + 1),
          previous[j - 1] + (text[i - 1] == query[j - 1] ? 0 : 1),
        );
      }
      previous = current;
    }
    final ratio = previous.last * 100 ~/ max(text.length, query.length);
    if (ratio <= 60) score = 85 - ratio;
  }
  return max(score + offset, 0);
}

int recipeSearchScore(Recipe recipe, String query, RecipeSearchField field) {
  query = query.toLowerCase();
  final name = _textScore(recipe.name.toLowerCase(), query);
  final tags = recipe.tags.fold(
    0,
    (score, tag) => max(score, _textScore(tag.toLowerCase(), query, -15)),
  );
  var note = _textScore(recipe.note.toLowerCase(), query, -30);
  if (note == 70) note = 120;
  final score = switch (field) {
    RecipeSearchField.all => name + tags + note,
    RecipeSearchField.name => name,
    RecipeSearchField.tags => tags,
    RecipeSearchField.note => note,
  };
  if (score == 0) return 0;
  return score + (recipe.favorite ? 10 : 0) - recipe.hiddenRounds;
}

void mergeRecipe(Recipe target, Recipe incoming) {
  target.imagePaths = {...target.imagePaths, ...incoming.imagePaths}.toList();
  target.tags = {...target.tags, ...incoming.tags}.toList();
  target.favorite = target.favorite || incoming.favorite;
  if (incoming.note.isNotEmpty && incoming.note != target.note) {
    target.note = target.note.isEmpty
        ? incoming.note
        : '${target.note}\n${incoming.note}';
  }
}

List<String> orderedRecipeTags(MenuData data) {
  final tags = [...data.recipeTags];
  if (data.recipeTagSort == 'name') {
    tags.sort();
  } else {
    final counts = {for (final tag in tags) tag: 0};
    final positions = {for (var i = 0; i < tags.length; i++) tags[i]: i};
    for (final recipe in data.recipes) {
      for (final tag in recipe.tags) {
        counts[tag] = counts[tag]! + 1;
      }
    }
    tags.sort((a, b) {
      final count = counts[b]!.compareTo(counts[a]!);
      return count == 0 ? positions[a]!.compareTo(positions[b]!) : count;
    });
  }
  return tags;
}
