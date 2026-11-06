import 'package:flutter/material.dart';

// Aurai's icon language: a 24-point grid, 1.65-point rounded strokes.
// Navigation keeps the same outline in both states; color conveys selection.
class MenuIcon extends StatelessWidget {
  const MenuIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });
  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final dimension = size ?? theme.size ?? 24;
    return Semantics(
      label: semanticLabel,
      child: SizedBox.square(
        dimension: dimension,
        child: CustomPaint(
          painter: _MenuIconPainter(
            _glyphFor(icon),
            color ?? theme.color ?? Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

enum _Glyph {
  random,
  reset,
  circle,
  funnel,
  list,
  book,
  shop,
  person,
  bowl,
  menu,
  filter,
  search,
  searchOff,
  heart,
  heartFilled,
  plus,
  photo,
  brokenPhoto,
  back,
  next,
  close,
  check,
  checkCircle,
  trash,
  edit,
  note,
  blocked,
  appearance,
  sparkle,
  export,
  import,
  archive,
  link,
  calendar,
  pin,
  clock,
  sort,
  more,
  people,
  chart,
  camera,
  crop,
  drag,
  eye,
  eyeOff,
  copy,
  arrowUp,
  arrowDown,
  plusCircle,
  minusCircle,
  tag,
  hourglass,
}

_Glyph _glyphFor(IconData icon) => switch (icon) {
  Icons.casino ||
  Icons.casino_outlined ||
  Icons.shuffle ||
  Icons.shuffle_rounded => _Glyph.random,
  Icons.radio_button_unchecked => _Glyph.circle,
  Icons.restart_alt => _Glyph.reset,
  Icons.format_list_bulleted => _Glyph.list,
  Icons.filter_alt_outlined => _Glyph.funnel,
  Icons.menu_book || Icons.menu_book_outlined => _Glyph.book,
  Icons.storefront || Icons.storefront_outlined => _Glyph.shop,
  Icons.person_outline_rounded ||
  Icons.person_rounded ||
  Icons.person_outline ||
  Icons.person => _Glyph.person,
  Icons.ramen_dining_outlined ||
  Icons.ramen_dining_rounded ||
  Icons.soup_kitchen_outlined ||
  Icons.restaurant_menu ||
  Icons.restaurant_outlined ||
  Icons.restaurant_rounded ||
  Icons.restaurant => _Glyph.bowl,
  Icons.receipt_long_outlined ||
  Icons.list_alt ||
  Icons.list_alt_outlined => _Glyph.menu,
  Icons.filter_alt ||
  Icons.tune_rounded ||
  Icons.filter_alt_off_outlined ||
  Icons.filter_list ||
  Icons.filter_list_rounded => _Glyph.filter,
  Icons.search => _Glyph.search,
  Icons.search_off || Icons.search_off_outlined => _Glyph.searchOff,
  Icons.favorite_border || Icons.favorite_outline => _Glyph.heart,
  Icons.favorite => _Glyph.heartFilled,
  Icons.add || Icons.add_rounded => _Glyph.plus,
  Icons.add_photo_alternate_outlined ||
  Icons.photo_outlined ||
  Icons.photo_library_outlined ||
  Icons.image_outlined ||
  Icons.photo_library => _Glyph.photo,
  Icons.broken_image_outlined => _Glyph.brokenPhoto,
  Icons.arrow_back || Icons.arrow_back_rounded => _Glyph.back,
  Icons.chevron_right ||
  Icons.skip_next_rounded ||
  Icons.arrow_forward ||
  Icons.arrow_forward_rounded => _Glyph.next,
  Icons.close || Icons.close_rounded => _Glyph.close,
  Icons.check || Icons.done => _Glyph.check,
  Icons.check_circle_outline_rounded ||
  Icons.check_circle_outline ||
  Icons.check_circle => _Glyph.checkCircle,
  Icons.delete_outline ||
  Icons.delete_outline_rounded ||
  Icons.delete => _Glyph.trash,
  Icons.edit_outlined || Icons.edit => _Glyph.edit,
  Icons.edit_note ||
  Icons.notes ||
  Icons.note_outlined ||
  Icons.description_outlined => _Glyph.note,
  Icons.do_not_disturb_alt_outlined || Icons.block => _Glyph.blocked,
  Icons.palette_outlined || Icons.brightness_6_outlined => _Glyph.appearance,
  Icons.auto_awesome_outlined || Icons.auto_awesome => _Glyph.sparkle,
  Icons.ios_share_rounded ||
  Icons.ios_share ||
  Icons.share_outlined ||
  Icons.share ||
  Icons.upload_outlined => _Glyph.export,
  Icons.file_download_outlined ||
  Icons.download_outlined ||
  Icons.download => _Glyph.import,
  Icons.inventory_2_outlined ||
  Icons.folder_outlined ||
  Icons.backup_outlined => _Glyph.archive,
  Icons.link => _Glyph.link,
  Icons.date_range_outlined ||
  Icons.calendar_month_outlined ||
  Icons.calendar_today_outlined ||
  Icons.event_outlined => _Glyph.calendar,
  Icons.place_outlined || Icons.location_on_outlined => _Glyph.pin,
  Icons.history ||
  Icons.history_rounded ||
  Icons.schedule ||
  Icons.access_time => _Glyph.clock,
  Icons.sort ||
  Icons.sort_rounded ||
  Icons.swap_vert ||
  Icons.sort_by_alpha => _Glyph.sort,
  Icons.more_vert || Icons.more_horiz => _Glyph.more,
  Icons.people_outline ||
  Icons.group_outlined ||
  Icons.people ||
  Icons.groups_outlined => _Glyph.people,
  Icons.bar_chart ||
  Icons.bar_chart_outlined ||
  Icons.insights_outlined ||
  Icons.analytics_outlined => _Glyph.chart,
  Icons.camera_alt_outlined ||
  Icons.photo_camera_outlined ||
  Icons.camera_alt => _Glyph.camera,
  Icons.crop || Icons.crop_free || Icons.crop_square => _Glyph.crop,
  Icons.drag_handle || Icons.drag_indicator || Icons.reorder => _Glyph.drag,
  Icons.visibility_outlined || Icons.visibility => _Glyph.eye,
  Icons.visibility_off_outlined || Icons.visibility_off => _Glyph.eyeOff,
  Icons.copy || Icons.content_copy => _Glyph.copy,
  Icons.arrow_upward || Icons.arrow_upward_rounded => _Glyph.arrowUp,
  Icons.arrow_downward || Icons.arrow_downward_rounded => _Glyph.arrowDown,
  Icons.add_circle_outline => _Glyph.plusCircle,
  Icons.remove_circle_outline => _Glyph.minusCircle,
  Icons.label_outline => _Glyph.tag,
  Icons.hourglass_top => _Glyph.hourglass,
  _ => throw ArgumentError('Missing MenuIcon drawing for ${icon.codePoint}'),
};

class _MenuIconPainter extends CustomPainter {
  const _MenuIconPainter(this.glyph, this.color);
  final _Glyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.65
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void path(Path value) => canvas.drawPath(value, pen);
    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), pen);
    void box(double x, double y, double w, double h, double r) =>
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h),
            Radius.circular(r),
          ),
          pen,
        );
    switch (glyph) {
      case _Glyph.random:
        path(
          Path()
            ..moveTo(3, 6)
            ..lineTo(6, 6)
            ..cubicTo(10, 6, 14, 18, 18, 18)
            ..lineTo(21, 18)
            ..moveTo(18, 15)
            ..lineTo(21, 18)
            ..lineTo(18, 21)
            ..moveTo(3, 18)
            ..lineTo(6, 18)
            ..cubicTo(8, 18, 9, 15.5, 10.5, 13.5)
            ..moveTo(13.5, 10.5)
            ..cubicTo(15, 8.5, 16, 6, 18, 6)
            ..lineTo(21, 6)
            ..moveTo(18, 3)
            ..lineTo(21, 6)
            ..lineTo(18, 9),
        );
      case _Glyph.circle:
        canvas.drawCircle(const Offset(12, 12), 9, pen);
      case _Glyph.reset:
        path(
          Path()
            ..moveTo(20, 8)
            ..cubicTo(17, 2, 8, 2, 4, 8)
            ..moveTo(4, 3)
            ..lineTo(4, 8)
            ..lineTo(9, 8)
            ..moveTo(4, 16)
            ..cubicTo(7, 22, 16, 22, 20, 16)
            ..moveTo(20, 21)
            ..lineTo(20, 16)
            ..lineTo(15, 16),
        );
      case _Glyph.book:
        path(
          Path()
            ..moveTo(12, 5)
            ..cubicTo(9, 3, 5, 3, 3, 4.5)
            ..lineTo(3, 19)
            ..cubicTo(5, 17.5, 9, 17.5, 12, 20)
            ..cubicTo(15, 17.5, 19, 17.5, 21, 19)
            ..lineTo(21, 4.5)
            ..cubicTo(19, 3, 15, 3, 12, 5)
            ..lineTo(12, 20)
            ..moveTo(6, 8)
            ..quadraticBezierTo(8, 7.5, 9, 8.5)
            ..moveTo(15, 8.5)
            ..quadraticBezierTo(17, 7.5, 18, 8),
        );
      case _Glyph.shop:
        path(
          Path()
            ..moveTo(4, 10)
            ..lineTo(4, 20.5)
            ..lineTo(20, 20.5)
            ..lineTo(20, 10)
            ..moveTo(3, 8)
            ..lineTo(5, 3.5)
            ..lineTo(19, 3.5)
            ..lineTo(21, 8)
            ..cubicTo(21, 11, 17, 11, 16.5, 8)
            ..cubicTo(16, 11, 12, 11, 12, 8)
            ..cubicTo(12, 11, 8, 11, 7.5, 8)
            ..cubicTo(7, 11, 3, 11, 3, 8)
            ..moveTo(10, 20.5)
            ..lineTo(10, 14)
            ..lineTo(15, 14)
            ..lineTo(15, 20.5),
        );
      case _Glyph.person:
        canvas.drawCircle(const Offset(12, 7), 3.5, pen);
        path(
          Path()
            ..moveTo(4, 20)
            ..cubicTo(4, 11, 20, 11, 20, 20),
        );
      case _Glyph.bowl:
        path(
          Path()
            ..moveTo(3.5, 12)
            ..cubicTo(4, 18, 7, 21, 12, 21)
            ..cubicTo(17, 21, 20, 18, 20.5, 12)
            ..close()
            ..moveTo(8, 7.5)
            ..cubicTo(6, 5.5, 10, 4.5, 8, 2.5)
            ..moveTo(13, 7.5)
            ..cubicTo(11, 5.5, 15, 4.5, 13, 2.5)
            ..moveTo(18, 7.5)
            ..lineTo(20, 4.5),
        );
      case _Glyph.menu:
        box(5, 4, 14, 17, 2.5);
        box(9, 2, 6, 4, 1.5);
        line(8.5, 10, 15.5, 10);
        line(8.5, 14, 15.5, 14);
        line(8.5, 18, 13, 18);
      case _Glyph.funnel:
        path(
          Path()
            ..moveTo(4.5, 4.5)
            ..lineTo(19.5, 4.5)
            ..quadraticBezierTo(20.5, 4.5, 19.85, 5.3)
            ..lineTo(14.05, 12.25)
            ..quadraticBezierTo(13.5, 12.9, 13.5, 13.7)
            ..lineTo(13.5, 19)
            ..quadraticBezierTo(13.5, 19.5, 13, 19.5)
            ..lineTo(11, 19.5)
            ..quadraticBezierTo(10.5, 19.5, 10.5, 19)
            ..lineTo(10.5, 13.7)
            ..quadraticBezierTo(10.5, 12.9, 9.95, 12.25)
            ..lineTo(4.15, 5.3)
            ..quadraticBezierTo(3.5, 4.5, 4.5, 4.5)
            ..close(),
        );
      case _Glyph.list:
        for (final y in [6.0, 12.0, 18.0]) {
          line(9, y, 21, y);
          canvas.drawCircle(Offset(4, y), .7, pen);
        }
      case _Glyph.filter:
        line(3, 6, 21, 6);
        line(6, 12, 18, 12);
        line(10, 18, 14, 18);
      case _Glyph.search:
      case _Glyph.searchOff:
        canvas.drawCircle(const Offset(10.5, 10.5), 7, pen);
        line(15.5, 15.5, 20.5, 20.5);
        if (glyph == _Glyph.searchOff) {
          line(8, 8, 13, 13);
          line(13, 8, 8, 13);
        }
      case _Glyph.heart:
      case _Glyph.heartFilled:
        if (glyph == _Glyph.heartFilled) pen.style = PaintingStyle.fill;
        path(
          Path()
            ..moveTo(12, 20.5)
            ..cubicTo(8, 17, 3, 13.5, 3, 9)
            ..cubicTo(3, 3, 10, 2.5, 12, 7)
            ..cubicTo(14, 2.5, 21, 3, 21, 9)
            ..cubicTo(21, 13.5, 16, 17, 12, 20.5)
            ..close(),
        );
      case _Glyph.plus:
        line(12, 4, 12, 20);
        line(4, 12, 20, 12);
      case _Glyph.photo:
      case _Glyph.brokenPhoto:
        box(3, 4, 18, 16, 3);
        canvas.drawCircle(const Offset(8, 9), 1.5, pen);
        path(
          Path()
            ..moveTo(4, 17)
            ..lineTo(10, 12)
            ..lineTo(14, 16)
            ..lineTo(17, 13)
            ..lineTo(21, 17),
        );
        if (glyph == _Glyph.brokenPhoto) line(3, 3, 21, 21);
      case _Glyph.back:
        path(
          Path()
            ..moveTo(11, 5)
            ..lineTo(4, 12)
            ..lineTo(11, 19)
            ..moveTo(4, 12)
            ..lineTo(20, 12),
        );
      case _Glyph.next:
        path(
          Path()
            ..moveTo(9, 5)
            ..lineTo(16, 12)
            ..lineTo(9, 19),
        );
      case _Glyph.close:
        line(6, 6, 18, 18);
        line(18, 6, 6, 18);
      case _Glyph.check:
      case _Glyph.checkCircle:
        if (glyph == _Glyph.checkCircle) {
          canvas.drawCircle(const Offset(12, 12), 9, pen);
        }
        path(
          Path()
            ..moveTo(7, 12)
            ..lineTo(10.5, 15.5)
            ..lineTo(17, 8.5),
        );
      case _Glyph.trash:
        line(3.5, 6, 20.5, 6);
        line(9, 3, 15, 3);
        path(
          Path()
            ..moveTo(5.5, 6)
            ..lineTo(6.5, 20)
            ..quadraticBezierTo(12, 22, 17.5, 20)
            ..lineTo(18.5, 6),
        );
        line(10, 10, 10, 17);
        line(14, 10, 14, 17);
      case _Glyph.edit:
        path(
          Path()
            ..moveTo(4, 15.5)
            ..lineTo(15.5, 4)
            ..quadraticBezierTo(17, 2.5, 18.5, 4)
            ..lineTo(20, 5.5)
            ..quadraticBezierTo(21.5, 7, 20, 8.5)
            ..lineTo(8.5, 20)
            ..lineTo(3, 21)
            ..close()
            ..moveTo(13.5, 6)
            ..lineTo(18, 10.5),
        );
      case _Glyph.note:
        box(5, 3, 15, 18, 2.5);
        line(8.5, 3, 8.5, 21);
        for (final y in [7.0, 12.0, 17.0]) {
          line(3.5, y, 6.5, y);
        }
        line(11.5, 8, 17, 8);
        line(11.5, 12, 17, 12);
        line(11.5, 16, 15, 16);
      case _Glyph.blocked:
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        line(5.5, 5.5, 18.5, 18.5);
      case _Glyph.appearance:
        path(
          Path()
            ..moveTo(10, 3)
            ..cubicTo(5.8, 3.7, 3, 7.2, 3, 11.5)
            ..cubicTo(3, 16.5, 6.8, 20.5, 11.8, 20.5)
            ..cubicTo(16, 20.5, 19.5, 17.8, 20.5, 14)
            ..cubicTo(17.3, 15.3, 13.7, 14.6, 11.4, 12)
            ..cubicTo(9.1, 9.5, 8.6, 6, 10, 3)
            ..close(),
        );
        line(17.5, 3, 17.5, 9);
        line(14.5, 6, 20.5, 6);
      case _Glyph.sparkle:
        path(
          Path()
            ..moveTo(12, 3)
            ..quadraticBezierTo(12, 11, 4, 12)
            ..quadraticBezierTo(12, 13, 12, 21)
            ..quadraticBezierTo(12, 13, 20, 12)
            ..quadraticBezierTo(12, 11, 12, 3)
            ..close(),
        );
        line(20, 2, 20, 6);
        line(18, 4, 22, 4);
      case _Glyph.export:
      case _Glyph.import:
        path(
          Path()
            ..moveTo(4, 13)
            ..lineTo(4, 20)
            ..lineTo(20, 20)
            ..lineTo(20, 13),
        );
        if (glyph == _Glyph.export) {
          path(
            Path()
              ..moveTo(12, 15)
              ..lineTo(12, 3)
              ..moveTo(7, 8)
              ..lineTo(12, 3)
              ..lineTo(17, 8),
          );
        } else {
          path(
            Path()
              ..moveTo(12, 3)
              ..lineTo(12, 15)
              ..moveTo(7, 10)
              ..lineTo(12, 15)
              ..lineTo(17, 10),
          );
        }
      case _Glyph.archive:
        box(3, 3, 18, 5, 1.5);
        box(5, 8, 14, 13, 2);
        line(9, 12, 15, 12);
      case _Glyph.link:
        path(
          Path()
            ..moveTo(10, 14)
            ..lineTo(14, 10)
            ..moveTo(8, 16)
            ..lineTo(6.5, 17.5)
            ..cubicTo(2, 22, 0, 15, 4, 12)
            ..lineTo(8, 8)
            ..cubicTo(10, 6, 13, 7, 13.5, 8.5)
            ..moveTo(16, 8)
            ..lineTo(17.5, 6.5)
            ..cubicTo(22, 2, 24, 9, 20, 12)
            ..lineTo(16, 16)
            ..cubicTo(14, 18, 11, 17, 10.5, 15.5),
        );
      case _Glyph.calendar:
        box(3, 5, 18, 16, 2.5);
        line(3, 10, 21, 10);
        line(8, 2.5, 8, 7);
        line(16, 2.5, 16, 7);
        line(7, 14, 10, 14);
        line(14, 14, 17, 14);
        line(7, 17.5, 10, 17.5);
      case _Glyph.pin:
        path(
          Path()
            ..moveTo(12, 21)
            ..cubicTo(9, 17.5, 5, 13, 5, 9)
            ..cubicTo(5, 0, 19, 0, 19, 9)
            ..cubicTo(19, 13, 15, 17.5, 12, 21)
            ..close(),
        );
        canvas.drawCircle(const Offset(12, 9), 2.5, pen);
      case _Glyph.clock:
        path(
          Path()
            ..moveTo(4, 9)
            ..cubicTo(6, 1, 20, 1, 21, 11)
            ..cubicTo(22, 22, 6, 25, 3, 15)
            ..moveTo(3, 4)
            ..lineTo(3, 10)
            ..lineTo(9, 10)
            ..moveTo(12, 6)
            ..lineTo(12, 12)
            ..lineTo(16, 14.5),
        );
      case _Glyph.sort:
        path(
          Path()
            ..moveTo(7, 4)
            ..lineTo(7, 20)
            ..moveTo(4, 7)
            ..lineTo(7, 4)
            ..lineTo(10, 7)
            ..moveTo(17, 4)
            ..lineTo(17, 20)
            ..moveTo(14, 17)
            ..lineTo(17, 20)
            ..lineTo(20, 17),
        );
      case _Glyph.more:
        for (final x in [5.0, 12.0, 19.0]) {
          canvas.drawCircle(Offset(x, 12), 1.3, Paint()..color = color);
        }
      case _Glyph.people:
        canvas.drawCircle(const Offset(9, 7), 3, pen);
        path(
          Path()
            ..moveTo(2.5, 20)
            ..cubicTo(2.5, 11, 15.5, 11, 15.5, 20)
            ..moveTo(16, 4.5)
            ..cubicTo(20.5, 4.5, 20.5, 10, 16, 10)
            ..moveTo(18, 13)
            ..cubicTo(21, 13.5, 22, 16, 22, 19),
        );
      case _Glyph.chart:
        box(3.5, 12, 3.5, 8.5, 1);
        box(10.25, 3.5, 3.5, 17, 1);
        box(17, 8, 3.5, 12.5, 1);
      case _Glyph.camera:
        path(
          Path()
            ..moveTo(4, 6)
            ..lineTo(7, 6)
            ..lineTo(9, 3)
            ..lineTo(15, 3)
            ..lineTo(17, 6)
            ..lineTo(20, 6)
            ..quadraticBezierTo(22, 6, 22, 8)
            ..lineTo(22, 18)
            ..quadraticBezierTo(22, 20, 20, 20)
            ..lineTo(4, 20)
            ..quadraticBezierTo(2, 20, 2, 18)
            ..lineTo(2, 8)
            ..quadraticBezierTo(2, 6, 4, 6)
            ..close(),
        );
        canvas.drawCircle(const Offset(12, 12.5), 4, pen);
      case _Glyph.crop:
        path(
          Path()
            ..moveTo(6, 2)
            ..lineTo(6, 18)
            ..lineTo(22, 18)
            ..moveTo(2, 6)
            ..lineTo(18, 6)
            ..lineTo(18, 22),
        );
      case _Glyph.drag:
        line(5, 9, 19, 9);
        line(5, 15, 19, 15);
      case _Glyph.eye:
      case _Glyph.eyeOff:
        path(
          Path()
            ..moveTo(2.5, 12)
            ..cubicTo(7, 4.5, 17, 4.5, 21.5, 12)
            ..cubicTo(17, 19.5, 7, 19.5, 2.5, 12),
        );
        canvas.drawCircle(const Offset(12, 12), 2.7, pen);
        if (glyph == _Glyph.eyeOff) line(4, 4, 20, 20);
      case _Glyph.copy:
        box(7, 7, 14, 14, 2.5);
        path(
          Path()
            ..moveTo(17, 4)
            ..lineTo(17, 3)
            ..lineTo(3, 3)
            ..lineTo(3, 17)
            ..lineTo(4, 17),
        );
      case _Glyph.plusCircle:
      case _Glyph.minusCircle:
        canvas.drawCircle(const Offset(12, 12), 9, pen);
        line(8, 12, 16, 12);
        if (glyph == _Glyph.plusCircle) line(12, 8, 12, 16);
      case _Glyph.tag:
        path(
          Path()
            ..moveTo(3, 3)
            ..lineTo(12, 3)
            ..lineTo(21, 12)
            ..lineTo(12, 21)
            ..lineTo(3, 12)
            ..close(),
        );
        canvas.drawCircle(const Offset(7.5, 7.5), 1.2, pen);
      case _Glyph.hourglass:
        path(
          Path()
            ..moveTo(5, 3)
            ..lineTo(19, 3)
            ..lineTo(19, 6)
            ..lineTo(12, 12)
            ..lineTo(19, 18)
            ..lineTo(19, 21)
            ..lineTo(5, 21)
            ..lineTo(5, 18)
            ..lineTo(12, 12)
            ..lineTo(5, 6)
            ..close(),
        );
      case _Glyph.arrowUp:
      case _Glyph.arrowDown:
        final down = glyph == _Glyph.arrowDown;
        final y = down ? 19.0 : 5.0;
        line(12, down ? 4 : 20, 12, y);
        path(
          Path()
            ..moveTo(6, down ? 13 : 11)
            ..lineTo(12, y)
            ..lineTo(18, down ? 13 : 11),
        );
    }
  }

  @override
  bool shouldRepaint(_MenuIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
