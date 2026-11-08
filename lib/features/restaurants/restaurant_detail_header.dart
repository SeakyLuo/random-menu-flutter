import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_tag.dart';
import 'restaurant_gallery_data.dart';
import 'restaurant_price.dart';
import '../../ui/menu_bottom_sheet.dart';

class RestaurantDetailInfo extends StatefulWidget {
  const RestaurantDetailInfo({
    super.key,
    required this.restaurant,
    required this.currentCity,
  });
  final Restaurant restaurant;
  final String? currentCity;
  @override
  State<RestaurantDetailInfo> createState() => _RestaurantDetailInfoState();
}

class _RestaurantDetailInfoState extends State<RestaurantDetailInfo> {
  bool _reviewOpen = false;
  Future<void> _showAddresses(List<String> addresses) =>
      showMenuBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '分店地址',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * .6,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: MenuIcon(
                        Icons.place_outlined,
                        size: 18,
                        color: Theme.of(
                          sheetContext,
                        ).colorScheme.onSurfaceVariant,
                      ),
                      title: Text(
                        addresses[index],
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final colors = Theme.of(context).colorScheme;
    final addresses = {
      for (final address in restaurant.addresses) address: address,
      for (final address in restaurant.addressEntries)
        address.fullAddress: restaurantDetailAddress(
          restaurant,
          address,
          currentCity: widget.currentCity,
        ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                restaurant.name,
                style: const TextStyle(
                  fontSize: 20,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (restaurant.category.isNotEmpty || restaurant.averageCost > 0)
                const SizedBox(height: 10),
              if (restaurant.category.isNotEmpty || restaurant.averageCost > 0)
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: restaurant.category.isNotEmpty
                            ? MenuTag(
                                restaurant.category,
                                selected: true,
                                compact: true,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    if (restaurant.averageCost > 0) ...[
                      const SizedBox(width: 12),
                      RestaurantPrice(restaurant.averageCost),
                    ],
                  ],
                ),
              if (addresses.isNotEmpty) ...[
                const SizedBox(height: 4),
                Semantics(
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showAddresses(addresses.keys.toList()),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 32),
                      child: Row(
                        children: [
                          MenuIcon(
                            Icons.place_outlined,
                            size: 17,
                            color: colors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          if (addresses.length > 1) ...[
                            Text(
                              '${addresses.length} 个分店',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: Text(
                              addresses.values.join('、'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          MenuIcon(
                            Icons.chevron_right,
                            size: 16,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (restaurant.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: MenuIcon(
                          Icons.edit_note,
                          size: 17,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final text = '“${restaurant.note}”';
                            final style = TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: colors.onSurface,
                            );
                            final painter = TextPainter(
                              text: TextSpan(text: text, style: style),
                              maxLines: 2,
                              textDirection: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                            )..layout(maxWidth: constraints.maxWidth);
                            final overflow = painter.didExceedMaxLines;
                            painter.dispose();
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text,
                                  style: style,
                                  maxLines: _reviewOpen ? null : 2,
                                  overflow: _reviewOpen
                                      ? TextOverflow.visible
                                      : TextOverflow.ellipsis,
                                ),
                                if (overflow)
                                  TextButton(
                                    onPressed: () => setState(
                                      () => _reviewOpen = !_reviewOpen,
                                    ),
                                    child: Text(_reviewOpen ? '收起' : '展开'),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
