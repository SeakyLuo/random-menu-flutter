import 'package:flutter/material.dart';
import '../../core/menu_store.dart';
import '../../ui/menu_popup.dart';
import 'restaurant_cover_action.dart';

class RestaurantDishCoverMenu extends StatefulWidget {
  const RestaurantDishCoverMenu({
    super.key,
    required this.restaurantId,
    required this.dishId,
    this.enabled = true,
  });

  final String? restaurantId;
  final String dishId;
  final bool enabled;

  @override
  State<RestaurantDishCoverMenu> createState() =>
      _RestaurantDishCoverMenuState();
}

class _RestaurantDishCoverMenuState extends State<RestaurantDishCoverMenu> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurantId == null
        ? null
        : MenuScope.of(context).data.restaurants.firstWhere(
            (restaurant) => restaurant.id == widget.restaurantId,
          );
    final isCover =
        restaurant != null && restaurant.coverDishId == widget.dishId;
    final canSet =
        restaurant != null &&
        restaurant.records.any(
          (visit) => visit.items.any(
            (dish) =>
                dish.dishId == widget.dishId &&
                dish.isDish &&
                dish.imagePaths.isNotEmpty,
          ),
        );
    return MenuPopupButton<String>(
      tooltip: '菜品操作',
      enabled: widget.enabled && !_saving,
      itemBuilder: (_) => [
        MenuPopupItem(
          value: 'cover',
          icon: isCover ? Icons.close : Icons.image_outlined,
          enabled: isCover || canSet,
          child: Text(isCover ? '取消设为封面' : '设为餐厅封面'),
        ),
      ],
      onSelected: (_) async {
        setState(() => _saving = true);
        await setRestaurantCover(
          context,
          widget.restaurantId!,
          isCover ? null : widget.dishId,
        );
        if (mounted) setState(() => _saving = false);
      },
    );
  }
}
