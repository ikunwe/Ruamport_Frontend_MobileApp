import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_page.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/auth_scope.dart';
import 'features/auth/auth_gate.dart';
import 'shared/widgets/backend_connection_notice.dart';

class RuamportApp extends StatelessWidget {
  const RuamportApp({super.key, this.auth});
  final AuthController? auth;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ruamport',
    debugShowCheckedModeBanner: false,
    theme: createAppTheme(),
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      builder: (_) => auth == null ? const HomePage() : AuthGate(auth: auth!),
      settings: settings,
    ),
    builder: (context, child) => auth == null
        ? child!
        : AuthScope(
            auth: auth!,
            child: BackendConnectionNotice(
              backend: auth!.backend,
              child: child!,
            ),
          ),
    // OAuth callback ใช้ root เดียวกัน SDK จะอ่าน code จาก URL ให้
    onGenerateInitialRoutes: (_) => [
      MaterialPageRoute<void>(
        builder: (_) => auth == null ? const HomePage() : AuthGate(auth: auth!),
        settings: const RouteSettings(name: '/'),
      ),
    ],
  );
}
