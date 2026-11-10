import 'package:flutter/material.dart';
import 'glass_surface.dart';

class PhotoPageIndicator extends StatelessWidget {
  const PhotoPageIndicator({
    super.key,
    required this.index,
    required this.count,
  });

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: GlassSurface(
      radius: 14,
      blurSigma: 24,
      color: const Color(0x25ffffff),
      borderColor: const Color(0x48ffffff),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          '${index + 1}/$count',
          style: const TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}
