import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/demo/demo_portfolio.dart';

// Hand-authored UI series, not API observations or calculated performance.
List<double> demoSeries(String period) {
  final scale =
      {
        '1D': 1.0,
        '1W': 2.4,
        '1M': 5.0,
        '3M': 8.0,
        '1Y': 12.0,
        'ALL': 15.0,
      }[period] ??
      5.0;
  return [
    0,
    .08,
    -.03,
    .18,
    .12,
    .36,
    .30,
    .51,
    .43,
    .57,
    .76,
    .68,
    .85,
    .80,
    1,
  ].map((value) => value * scale).toList();
}

class FinanceChart extends StatefulWidget {
  const FinanceChart({
    super.key,
    required this.period,
    this.comparison = false,
    this.marketScale = .64,
  });
  final String period;
  final bool comparison;
  final double marketScale;
  @override
  State<FinanceChart> createState() => _FinanceChartState();
}

class _FinanceChartState extends State<FinanceChart> {
  int? point;
  @override
  void didUpdateWidget(FinanceChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) point = null;
  }

  @override
  Widget build(BuildContext context) {
    final values = demoSeries(widget.period);
    return LayoutBuilder(
      builder: (context, bounds) => Column(
        children: [
          SizedBox(
            height: 24,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                point == null
                    ? 'แตะกราฟเพื่อดูจุดข้อมูลตัวอย่าง'
                    : 'จุดที่ ${point! + 1} · ${percent(values[point!])}',
                style: TextStyle(
                  fontSize: 10,
                  color: point == null ? Colors.white30 : lime,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTapDown: (details) => setState(
              () => point =
                  (details.localPosition.dx /
                          bounds.maxWidth *
                          (values.length - 1))
                      .round()
                      .clamp(0, values.length - 1),
            ),
            onHorizontalDragUpdate: (details) => setState(
              () => point =
                  (details.localPosition.dx /
                          bounds.maxWidth *
                          (values.length - 1))
                      .round()
                      .clamp(0, values.length - 1),
            ),
            child: Semantics(
              label: 'กราฟข้อมูลตัวอย่าง ช่วง ${widget.period}',
              image: true,
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: CustomPaint(
                  painter: _LinePainter(
                    values,
                    widget.comparison,
                    point,
                    widget.marketScale,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'เริ่มช่วง',
                style: TextStyle(fontSize: 9, color: Colors.white30),
              ),
              Text(
                'ช่วงกลาง',
                style: TextStyle(fontSize: 9, color: Colors.white30),
              ),
              Text(
                'ล่าสุด',
                style: TextStyle(fontSize: 9, color: Colors.white30),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.comparison, this.selected, this.marketScale);
  final List<double> values;
  final bool comparison;
  final int? selected;
  final double marketScale;
  @override
  void paint(Canvas canvas, Size size) {
    final minimum = values.reduce(math.min) - 1;
    final maximum = values.reduce(math.max) + 1;
    Offset xy(int index, double value) => Offset(
      index * size.width / (values.length - 1),
      size.height -
          8 -
          (value - minimum) / (maximum - minimum) * (size.height - 16),
    );
    for (var i = 0; i < 4; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = Colors.white.withValues(alpha: .055),
      );
    }
    Path line(List<double> data) {
      final path = Path()..moveTo(xy(0, data[0]).dx, xy(0, data[0]).dy);
      for (var i = 1; i < data.length; i++) {
        final p = xy(i, data[i]);
        path.lineTo(p.dx, p.dy);
      }
      return path;
    }

    final path = line(values);
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
          colors: [Color(0x2878FF61), Color(0x0078FF61)],
        ).createShader(Offset.zero & size),
    );
    if (comparison) {
      canvas.drawPath(
        line(values.map((v) => v * marketScale + .15).toList()),
        Paint()
          ..color = blue
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lime
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    if (selected != null) {
      final p = xy(selected!, values[selected!]);
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()..color = Colors.white24,
      );
      canvas.drawCircle(p, 6, Paint()..color = lime.withValues(alpha: .15));
      canvas.drawCircle(p, 3, Paint()..color = lime);
    }
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) => true;
}

class AllocationRing extends StatefulWidget {
  const AllocationRing({super.key, required this.labels, required this.values});
  final List<String> labels;
  final List<double> values;
  @override
  State<AllocationRing> createState() => _AllocationRingState();
}

class _AllocationRingState extends State<AllocationRing> {
  int? selected;
  @override
  void didUpdateWidget(AllocationRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.labels.join() != widget.labels.join()) selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.values.fold<double>(0, (sum, value) => sum + value);
    const colors = [lime, blue, violet, Color(0xFFFFD675), Color(0xFFFF9A7C)];
    return Column(
      children: [
        Center(
          child: GestureDetector(
            onTapDown: (details) {
              final p = details.localPosition - const Offset(90, 90);
              var angle = math.atan2(p.dy, p.dx) + math.pi / 2;
              if (angle < 0) angle += math.pi * 2;
              var limit = 0.0;
              for (var i = 0; i < widget.values.length; i++) {
                limit += widget.values[i] / total * math.pi * 2;
                if (angle <= limit) {
                  setState(() => selected = i);
                  break;
                }
              }
            },
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RingPainter(widget.values, colors, selected),
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selected == null
                              ? 'ทั้งพอร์ต'
                              : widget.labels[selected!],
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white54,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          selected == null
                              ? '100%'
                              : '${number(widget.values[selected!] / total * 100, 1)}%',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          widget.labels.length,
          (index) => InkWell(
            onTap: () => setState(() => selected = index),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colors[index % colors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.labels[index],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '${number(widget.values[index] / total * 100, 1)}%',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.values, this.colors, this.selected);
  final List<double> values;
  final List<Color> colors;
  final int? selected;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        Rect.fromCircle(center: size.center(Offset.zero), radius: 73),
        start,
        math.max(0, sweep - .035),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (selected == i ? 24 : 20)
          ..color = colors[i % colors.length].withValues(
            alpha: selected == null || selected == i ? 1 : .35,
          ),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => true;
}
