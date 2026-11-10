import 'package:flutter/material.dart';

class MenuPillTabs extends StatelessWidget {
  const MenuPillTabs({super.key, required this.tabs, this.controller});

  final List<Widget> tabs;
  final TabController? controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 10),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        padding: EdgeInsets.zero,
        indicatorSize: TabBarIndicatorSize.label,
        indicator: ShapeDecoration(
          color: colors.primary.withValues(alpha: .12),
          shape: const StadiumBorder(),
        ),
        automaticIndicatorColorAdjustment: false,
        splashBorderRadius: BorderRadius.circular(24),
        labelColor: colors.primary,
        unselectedLabelColor: colors.onSurfaceVariant,
        labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        dividerColor: Colors.transparent,
        tabs: tabs,
      ),
    );
  }
}
