import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class PortfolioChart extends CustomPainter {
  PortfolioChart(this.period);
  final String period;
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 1; i < 4; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 4),
        Offset(size.width, size.height * i / 4),
        Paint()..color = Colors.white.withValues(alpha: .05),
      );
    }
    final points = period == '1D'
        ? [.8, .6, .7, .4, .5, .3, .2]
        : [.85, .68, .74, .46, .62, .36, .45, .19, .3, .1];
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = size.width * i / (points.length - 1);
      final y = size.height * points[i];
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x3371FF4B), Color(0x0071FF4B)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(PortfolioChart oldDelegate) =>
      oldDelegate.period != period;
}
