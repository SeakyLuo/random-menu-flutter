import 'package:flutter/material.dart';
import '../../ui/menu_field_label.dart';
import '../../ui/menu_suggestion_input.dart';

class RestaurantCompanionField extends StatelessWidget {
  const RestaurantCompanionField({
    super.key,
    required this.controller,
    required this.choices,
  });
  final TextEditingController controller;
  final List<String> choices;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const MenuFieldLabel(
        '饭搭子',
        icon: Icons.people_outline,
        minHeight: 44,
        bottomSpacing: 4,
      ),
      MenuSuggestionInput(
        controller: controller,
        choices: choices,
        commaSeparated: true,
        showSuggestionsWhenEmpty: true,
        adaptToAvailableSpace: true,
        hintText: '不用写自己，用“，”分隔人名',
      ),
    ],
  );
}
