import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AllocationChart extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 16,
    );
    double start = -math.pi / 2;
    const colors = [Color(0xFF61FFD0), lime, Color(0xFFFFDC3A)];
    const shares = [.5, .3, .2];
    for (int i = 0; i < 3; i++) {
      final sweep = shares[i] * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep - .035,
        false,
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 25,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(AllocationChart oldDelegate) => false;
}
