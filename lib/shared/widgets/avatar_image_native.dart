import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AvatarImage extends StatelessWidget {
  const AvatarImage({
    super.key,
    required this.url,
    required this.size,
    this.fit = BoxFit.cover,
    this.fallback,
  });
  final String url;
  final double size;
  final BoxFit fit;
  final Widget? fallback;
  @override
  Widget build(BuildContext context) => Image.network(
    url,
    width: size,
    height: size,
    fit: fit,
    loadingBuilder: (_, child, progress) => progress == null
        ? child
        : fallback ??
              Center(
                child: SizedBox(
                  width: size * .35,
                  height: size * .35,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: lime,
                  ),
                ),
              ),
    errorBuilder: (_, _, _) =>
        fallback ?? Icon(Icons.person_outline, color: lime, size: size * .6),
  );
}
