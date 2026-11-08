import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../ui/menu_icon.dart';
import '../../ui/menu_popup.dart';
import '../../ui/widgets.dart';

class VisitCouponCard extends StatelessWidget {
  const VisitCouponCard({
    super.key,
    required this.coupon,
    required this.notApplied,
    required this.onEdit,
    required this.onRemove,
  });

  final VisitCoupon coupon;
  final bool notApplied;
  final VoidCallback onEdit, onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final border = colors.primary.withValues(alpha: dark ? .32 : .24);
    final amount = TextSpan(
      children: [
        const TextSpan(text: '￥', style: TextStyle(fontSize: 14)),
        TextSpan(text: money(coupon.discount)),
      ],
      style: TextStyle(
        fontSize: 28,
        height: 1.1,
        fontWeight: FontWeight.w600,
        color: colors.primary,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: amount,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final split = math.min(
          math.max(96.0, painter.width + 24),
          constraints.maxWidth * .42,
        );
        painter.dispose();
        final shape = _TicketShape(split: split, color: border);
        return Material(
          color: Color.alphaBlend(
            colors.primary.withValues(alpha: dark ? .10 : .06),
            colors.surface,
          ),
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onEdit,
            customBorder: shape,
            child: CustomPaint(
              foregroundPainter: _TicketPerforation(split, border),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: split,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text.rich(amount, textAlign: TextAlign.center),
                            const SizedBox(height: 5),
                            Text(
                              '每张优惠',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    coupon.threshold == null ? '立减券' : '满减券',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      height: 1.4,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    coupon.threshold == null
                                        ? '无门槛'
                                        : '满 ￥${money(coupon.threshold!)} 可用',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${coupon.quantity} 张',
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.5,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  if (notApplied) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '未达门槛，本次不抵扣',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.5,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            MenuPopupButton<String>(
                              tooltip: '用券操作',
                              buttonBuilder: (open) => IconButton(
                                tooltip: '用券操作',
                                constraints: const BoxConstraints.tightFor(
                                  width: 44,
                                  height: 44,
                                ),
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                alignment: Alignment.topCenter,
                                padding: const EdgeInsets.only(top: 1),
                                onPressed: open,
                                icon: MenuIcon(
                                  Icons.more_horiz,
                                  size: 20,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              onSelected: (_) => onRemove(),
                              itemBuilder: (_) => const [
                                MenuPopupItem(
                                  value: 'remove',
                                  icon: Icons.delete_outline,
                                  destructive: true,
                                  child: Text('移除用券'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TicketShape extends ShapeBorder {
  const _TicketShape({
    required this.split,
    required this.color,
    this.radius = 12,
    this.notch = 6,
    this.stroke = 1,
  });

  final double split, radius, notch, stroke;
  final Color color;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) => _TicketShape(
    split: split * t,
    color: color,
    radius: radius * t,
    notch: notch * t,
    stroke: stroke * t,
  );

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path.combine(
    PathOperation.difference,
    Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius))),
    Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(rect.left + split, rect.top),
          radius: notch,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(rect.left + split, rect.bottom),
          radius: notch,
        ),
      ),
  );

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) =>
      canvas.drawPath(
        getOuterPath(rect, textDirection: textDirection),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
}

class _TicketPerforation extends CustomPainter {
  const _TicketPerforation(this.split, this.color);
  final double split;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final pen = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var y = 10.0; y < size.height - 10; y += 8) {
      canvas.drawLine(
        Offset(split, y),
        Offset(split, math.min(y + 4, size.height - 10)),
        pen,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TicketPerforation oldDelegate) =>
      split != oldDelegate.split || color != oldDelegate.color;
}
