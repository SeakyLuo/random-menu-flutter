import 'package:flutter/material.dart';

/// Shared image and title treatment for library cards.
class LibraryPhotoCard extends StatelessWidget {
  const LibraryPhotoCard({
    super.key,
    required this.cover,
    required this.caption,
    required this.hasPhoto,
    required this.label,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  final Widget cover;
  final Widget caption;
  final bool hasPhoto;
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10172c21),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(dark ? 1 : 2),
        decoration: BoxDecoration(
          color: dark
              ? const Color(0x1fffffff)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(dark ? 21 : 20),
          child: Stack(
            children: [
              Positioned.fill(child: cover),
              if (hasPhoto)
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(0, -.1),
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x40000000),
                          Color(0xb3000000),
                          Color(0xd6000000),
                        ],
                        stops: [0, .35, .75, 1],
                      ),
                    ),
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AspectRatio(aspectRatio: 1, child: SizedBox.expand()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: caption,
                  ),
                ],
              ),
              if (onTap != null || onLongPress != null)
                Positioned.fill(
                  child: Semantics(
                    button: true,
                    label: label,
                    child: GestureDetector(
                      onTap: onTap,
                      onLongPress: onLongPress,
                      behavior: HitTestBehavior.opaque,
                    ),
                  ),
                ),
              if (trailing != null)
                Positioned(top: 8, right: 8, child: trailing!),
            ],
          ),
        ),
      ),
    );
  }
}
