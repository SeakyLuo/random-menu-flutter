import 'package:flutter/material.dart';
import 'menu_action_sheet.dart';

enum NameManagementAction { rename, delete, addChild, view }

Future<NameManagementAction?> showNameManagementSheet(
  BuildContext context, {
  required String name,
  required String deleteLabel,
  String? addChildLabel,
  String? viewLabel,
  IconData viewIcon = Icons.storefront_outlined,
  bool allowEditing = true,
}) => showMenuActionSheet<NameManagementAction>(
  context: context,
  title: name,
  actions: (context) => [
    if (viewLabel != null)
      MenuSheetAction(
        icon: viewIcon,
        label: viewLabel,
        onTap: () => Navigator.pop(context, NameManagementAction.view),
      ),
    if (addChildLabel != null)
      MenuSheetAction(
        icon: Icons.add,
        label: addChildLabel,
        onTap: () => Navigator.pop(context, NameManagementAction.addChild),
      ),
    if (allowEditing)
      MenuSheetAction(
        icon: Icons.edit_outlined,
        label: '修改名称',
        onTap: () => Navigator.pop(context, NameManagementAction.rename),
      ),
    if (allowEditing)
      MenuSheetAction(
        icon: Icons.delete_outline,
        label: deleteLabel,
        destructive: true,
        onTap: () => Navigator.pop(context, NameManagementAction.delete),
      ),
  ],
);
