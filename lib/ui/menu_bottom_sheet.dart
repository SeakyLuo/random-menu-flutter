import 'package:flutter/material.dart';

Future<T?> showMenuBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = true,
  Color? backgroundColor,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  AnimationStyle? sheetAnimationStyle,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: isScrollControlled,
  useSafeArea: useSafeArea,
  isDismissible: isDismissible,
  enableDrag: enableDrag,
  showDragHandle: false,
  backgroundColor: backgroundColor,
  clipBehavior: clipBehavior,
  constraints: constraints,
  sheetAnimationStyle: sheetAnimationStyle,
  builder: (context) => showDragHandle
      ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MenuSheetHandle(),
            Flexible(child: builder(context)),
          ],
        )
      : builder(context),
);

class MenuSheetHandle extends StatelessWidget {
  const MenuSheetHandle({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    child: Center(
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).bottomSheetTheme.dragHandleColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}
