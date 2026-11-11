import 'package:flutter/material.dart';
import 'menu_action_sheet.dart';

enum NameManagementAction { rename, delete, addChild }

Future<NameManagementAction?> showNameManagementSheet(
  BuildContext context, {
  required String name,
  required String deleteLabel,
  String? addChildLabel,
}) => showMenuActionSheet<NameManagementAction>(
  context: context,
  title: name,
  actions: (context) => [
    if (addChildLabel != null)
      MenuSheetAction(
        icon: Icons.add,
        label: addChildLabel,
        onTap: () => Navigator.pop(context, NameManagementAction.addChild),
      ),
    MenuSheetAction(
      icon: Icons.edit_outlined,
      label: '修改名称',
      onTap: () => Navigator.pop(context, NameManagementAction.rename),
    ),
    MenuSheetAction(
      icon: Icons.delete_outline,
      label: deleteLabel,
      destructive: true,
      onTap: () => Navigator.pop(context, NameManagementAction.delete),
    ),
  ],
);
