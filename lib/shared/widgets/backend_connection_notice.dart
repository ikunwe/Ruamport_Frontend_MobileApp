import 'package:flutter/material.dart';
import '../../core/network/backend_client.dart';

class BackendConnectionNotice extends StatelessWidget {
  const BackendConnectionNotice({
    super.key,
    required this.backend,
    required this.child,
  });
  final BackendClient backend;
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      ValueListenableBuilder<bool>(
        valueListenable: backend.readiness.connecting,
        builder: (context, connecting, _) => connecting
            ? Positioned(
                top: MediaQuery.paddingOf(context).top + 8,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  child: Center(
                    child: Material(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 9),
                            Text(
                              'กำลังเชื่อมต่อระบบ…',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    ],
  );
}
