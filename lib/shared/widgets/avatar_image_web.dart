import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../core/theme/app_colors.dart';

class AvatarImage extends StatefulWidget {
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
  State<AvatarImage> createState() => _AvatarImageState();
}

class _AvatarImageState extends State<AvatarImage> {
  bool loading = true, failed = false;
  web.HTMLImageElement? image;
  JSFunction? loadedListener, errorListener;

  void detach() {
    if (loadedListener != null) {
      image?.removeEventListener('load', loadedListener);
    }
    if (errorListener != null) {
      image?.removeEventListener('error', errorListener);
    }
    image = null;
    loadedListener = null;
    errorListener = null;
  }

  @override
  void didUpdateWidget(covariant AvatarImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      detach();
      loading = true;
      failed = false;
    }
  }

  void created(Object element) {
    detach();
    final img = element as web.HTMLImageElement;
    final url = widget.url;
    image = img;
    void settle(bool error) {
      if (!mounted || widget.url != url || image != img) return;
      setState(() {
        loading = false;
        failed = error;
      });
    }

    loadedListener = ((web.Event _) => settle(false)).toJS;
    errorListener = ((web.Event _) => settle(true)).toJS;
    img.addEventListener('load', loadedListener);
    img.addEventListener('error', errorListener);
    // เหมือน <img referrerpolicy="no-referrer"> ของ Angular ไม่โหลดผ่าน CanvasKit/XHR
    img.referrerPolicy = 'no-referrer';
    img.alt = '';
    img.style.width = '100%';
    img.style.height = '100%';
    img.style.objectFit = widget.fit == BoxFit.contain ? 'contain' : 'cover';
    img.style.borderRadius = widget.fit == BoxFit.contain ? '0' : '50%';
    img.style.pointerEvents = 'none';
    img.src = url;
  }

  @override
  void dispose() {
    detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return widget.fallback ??
          Icon(Icons.person_outline, color: lime, size: widget.size * .6);
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: HtmlElementView.fromTagName(
              key: ValueKey(widget.url),
              tagName: 'img',
              onElementCreated: created,
            ),
          ),
          if (loading) const ColoredBox(color: Color(0xFF20351C)),
          if (loading)
            widget.fallback ??
                Center(
                  child: SizedBox(
                    width: widget.size * .35,
                    height: widget.size * .35,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: lime,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
