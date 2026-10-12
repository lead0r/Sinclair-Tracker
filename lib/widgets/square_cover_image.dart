import 'package:flutter/material.dart';

import 'persistent_cover_image.dart';

class SquareCoverImage extends StatelessWidget {
  const SquareCoverImage({
    super.key,
    required this.imageUrl,
    required this.size,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.iconSize = 48,
  });

  final String? imageUrl;
  final double size;
  final BorderRadiusGeometry borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      child: url == null || url.isEmpty
          ? Icon(Icons.graphic_eq, size: iconSize)
          : PersistentCoverImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.contain,
            ),
    );
  }
}
