import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/panel.dart';

class Metric extends StatelessWidget {
  const Metric({
    super.key,
    required this.label,
    required this.amount,
    this.positive = false,
  });
  final String label, amount;
  final bool positive;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 12),
        FittedBox(
          child: Text(
            amount,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: positive ? lime : Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}
