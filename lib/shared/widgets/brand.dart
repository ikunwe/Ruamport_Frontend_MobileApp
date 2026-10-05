import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.work_outline_rounded, color: lime, size: 32),
      SizedBox(width: 9),
      Text(
        'Ruamport',
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
      ),
    ],
  );
}
