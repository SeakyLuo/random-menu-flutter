import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../ui/library_layout.dart';

class SliverRestaurantGrid extends StatelessWidget {
  const SliverRestaurantGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.mainAxisSpacing = 18,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double mainAxisSpacing;

  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) => SliverMasonryGrid.count(
      crossAxisCount: LibraryLayout.restaurantColumns(
        context,
        constraints.crossAxisExtent,
      ),
      crossAxisSpacing: 16,
      mainAxisSpacing: mainAxisSpacing,
      childCount: itemCount,
      itemBuilder: itemBuilder,
    ),
  );
}
