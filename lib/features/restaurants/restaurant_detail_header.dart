import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_tag.dart';
import '../../ui/widgets.dart';
import 'restaurant_gallery_data.dart';

class RestaurantDetailInfo extends StatefulWidget {
  const RestaurantDetailInfo({super.key, required this.restaurant});
  final Restaurant restaurant;
  @override
  State<RestaurantDetailInfo> createState() => _RestaurantDetailInfoState();
}

class _RestaurantDetailInfoState extends State<RestaurantDetailInfo> {
  bool _addressesOpen = false;
  bool _reviewOpen = false;
  Future<void> _copy(String address) => performAction(
    context,
    () => Clipboard.setData(ClipboardData(text: address)),
    success: '地址已复制',
  );
  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final colors = Theme.of(context).colorScheme;
    final addresses = {
      ...restaurant.addressEntries.map((a) => a.fullAddress),
      ...restaurant.addresses,
    }.toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (restaurant.category.isNotEmpty)
                      MenuTag(restaurant.category),
                    if (restaurant.averageCost > 0)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '¥${money(restaurant.averageCost)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: ' /人',
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              if (addresses.isNotEmpty) ...[
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _addressesOpen = !_addressesOpen),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        MenuIcon(
                          Icons.place_outlined,
                          size: 19,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 9),
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
                            addresses.map(localAddressText).join('、'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        RotatedBox(
                          quarterTurns: _addressesOpen ? 1 : 0,
                          child: MenuIcon(
                            Icons.chevron_right,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_addressesOpen)
                  for (final address in addresses)
                    InkWell(
                      onLongPress: () => _copy(address),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 6, 0, 6),
                        child: Text(
                          address,
                          style: const TextStyle(fontSize: 14, height: 1.5),
                        ),
                      ),
                    ),
              ],
              if (restaurant.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: MenuIcon(
                        Icons.edit_note,
                        size: 19,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final text = '“${restaurant.note}”';
                          final style = TextStyle(
                            fontSize: 14,
                            height: 1.6,
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}
