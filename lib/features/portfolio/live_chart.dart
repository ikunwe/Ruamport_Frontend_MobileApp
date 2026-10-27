import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../import/import_models.dart';
import '../import/pdf_preview_view.dart';
import 'portfolio_data.dart';
import 'live_finance_ui.dart';

class LiveChart extends StatefulWidget {
  const LiveChart({
    super.key,
    required this.points,
    required this.field,
    this.comparisonField,
    this.unit = 'THB',
  });
  final List<Map<String, dynamic>> points;
  final String field, unit;
  final String? comparisonField;
  @override
  State<LiveChart> createState() => _LiveChartState();
}

class _LiveChartState extends State<LiveChart> {
  int? selected;
  @override
  void didUpdateWidget(covariant LiveChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) selected = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.points.any(
      (point) =>
          finiteNumber(point[widget.field]) != null ||
          widget.comparisonField != null &&
              finiteNumber(point[widget.comparisonField]) != null,
    )) {
      return const DataNotice('ยังไม่มีจุดกราฟที่พร้อมแสดง');
    }
    return LayoutBuilder(
      builder: (context, bounds) {
        void select(double x) => setState(
          () => selected = (x / bounds.maxWidth * (widget.points.length - 1))
              .round()
              .clamp(0, widget.points.length - 1),
        );
        final point = selected == null ? null : widget.points[selected!];
        return Column(
          children: [
            SizedBox(
              height: 42,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  point == null
                      ? 'แตะกราฟเพื่อดูข้อมูล'
                      : '${point['date']} · ${pdfNumber(point[widget.field])} ${widget.unit}'
                            '${widget.comparisonField == null ? '' : ' / ${pdfNumber(point[widget.comparisonField])} ${widget.unit}'}',
                  style: const TextStyle(fontSize: 10, color: Colors.white54),
                ),
              ),
            ),
            MouseRegion(
              onHover: (event) => select(event.localPosition.dx),
              child: GestureDetector(
                onTapDown: (details) => select(details.localPosition.dx),
                onHorizontalDragUpdate: (details) =>
                    select(details.localPosition.dx),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _LivePainter(
                      widget.points
                          .map((point) => finiteNumber(point[widget.field]))
                          .toList(),
                      widget.comparisonField == null
                          ? []
                          : widget.points
                                .map(
                                  (point) => finiteNumber(
                                    point[widget.comparisonField],
                                  ),
                                )
                                .toList(),
                      selected,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [widget.points.first, widget.points.last]
                  .map(
                    (point) => Text(
                      textValue(point['date']) ?? '—',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white38,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        );
      },
    );
  }
}

class _LivePainter extends CustomPainter {
  const _LivePainter(this.values, this.comparison, this.selected);
  final List<double?> values, comparison;
  final int? selected;
  @override
  void paint(Canvas canvas, Size size) {
    final known = [...values, ...comparison].whereType<double>().toList();
    if (known.isEmpty) return;
    final low = known.reduce(math.min), high = known.reduce(math.max);
    final span = high == low ? math.max(high.abs() * .05, 1.0) : high - low;
    Offset point(int i, double value) => Offset(
      values.length <= 1
          ? size.width / 2
          : i * size.width / (values.length - 1),
      size.height - 8 - (value - low) / span * (size.height - 16),
    );
    for (int i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(0, i * size.height / 3),
        Offset(size.width, i * size.height / 3),
        Paint()..color = Colors.white.withValues(alpha: .04),
      );
    }
    void draw(List<double?> series, Color color) {
      final path = Path();
      bool connected = false;
      for (int i = 0; i < series.length; i++) {
        final value = series[i];
        if (value == null) {
          connected = false;
          continue;
        }
        final p = point(i, value);
        if (connected) {
          path.lineTo(p.dx, p.dy);
        } else {
          path.moveTo(p.dx, p.dy);
        }
        connected = true;
        if (series.length == 1 || selected == i) {
          canvas.drawCircle(p, 4, Paint()..color = color);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }

    draw(values, lime);
    draw(comparison, blue);
  }

  @override
  bool shouldRepaint(covariant _LivePainter oldDelegate) => true;
}
