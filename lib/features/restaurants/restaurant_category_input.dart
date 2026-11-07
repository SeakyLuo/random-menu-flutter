import 'package:flutter/material.dart';
import '../../ui/menu_suggestion_input.dart';

class RestaurantCategoryInput extends StatelessWidget {
  const RestaurantCategoryInput({
    super.key,
    required this.controller,
    required this.choices,
    this.optionsViewOpenDirection = OptionsViewOpenDirection.down,
  });
  final TextEditingController controller;
  final List<String> choices;
  final OptionsViewOpenDirection optionsViewOpenDirection;

  @override
  Widget build(BuildContext context) => MenuSuggestionInput(
    controller: controller,
    choices: choices,
    optionsViewOpenDirection: optionsViewOpenDirection,
    hintText: '输入菜系',
  );
}
