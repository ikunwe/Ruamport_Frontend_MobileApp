import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = 18,
    this.accent = false,
  });
  final Widget child;
  final double padding;
  final bool accent;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(8),
      gradient: accent
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF152617), surface],
            )
          : null,
      border: Border.all(
        color: accent
            ? lime.withValues(alpha: .18)
            : Colors.white.withValues(alpha: .08),
      ),
    ),
    child: Material(
      type: MaterialType.transparency,
      borderRadius: BorderRadius.circular(8),
      child: Padding(padding: EdgeInsets.all(padding), child: child),
    ),
  );
}
