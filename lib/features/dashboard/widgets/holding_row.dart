import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class Holding extends StatelessWidget {
  const Holding(this.symbol, this.name, this.value, this.gain, {super.key});
  final String symbol, name, value, gain;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            symbol.substring(0, 1),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(symbol, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                name,
                style: const TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(value),
            Text(gain, style: const TextStyle(fontSize: 11, color: lime)),
          ],
        ),
      ],
    ),
  );
}
