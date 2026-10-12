import 'package:flutter/material.dart';

class SinclairCrossMark extends StatelessWidget {
  const SinclairCrossMark({
    super.key,
    this.size = 34,
    this.color,
    this.backgroundColor,
  });

  final double size;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? scheme.primaryContainer,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: CustomPaint(
        painter: _CrossPainter(color ?? scheme.onPrimaryContainer),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  const _CrossPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final radius = Radius.circular(size.shortestSide * 0.055);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.43,
          size.height * 0.15,
          size.width * 0.14,
          size.height * 0.72,
        ),
        radius,
      ),
      paint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.25,
          size.height * 0.34,
          size.width * 0.50,
          size.height * 0.14,
        ),
        radius,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrossPainter oldDelegate) =>
      oldDelegate.color != color;
}
