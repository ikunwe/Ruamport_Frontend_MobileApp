import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'avatar_image.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.url, this.size = 34});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = url?.trim() ?? '';
    final uri = Uri.tryParse(normalizedUrl);
    final valid =
        uri != null &&
        uri.host.isNotEmpty &&
        (uri.scheme == 'https' || uri.scheme == 'http');
    Widget fallback() =>
        Icon(Icons.person_outline, color: lime, size: size * .6);
    return Semantics(
      label: 'รูปโปรไฟล์',
      image: true,
      child: ClipOval(
        child: Container(
          width: size,
          height: size,
          color: const Color(0xFF20351C),
          alignment: Alignment.center,
          child: !valid
              ? fallback()
              : AvatarImage(
                  key: ValueKey(normalizedUrl),
                  url: normalizedUrl,
                  size: size,
                ),
        ),
      ),
    );
  }
}
