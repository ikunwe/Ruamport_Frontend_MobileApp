import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/auth/auth_controller.dart';
import 'core/auth/secure_auth_storage.dart';
import 'core/config/app_config.dart';

import 'app.dart';
export 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseKey,
    debug: false,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      localStorage: const SecureAuthStorage(),
      pkceAsyncStorage: SecurePkceStorage(),
      // /mail/return?code=... เป็นผลขอสิทธิ์ Gmail ไม่ใช่ Supabase OAuth code
      detectSessionInUriPredicate: (uri) =>
          uri.path == '/auth/callback' ||
          uri.scheme == 'io.ruamport.mobile' &&
              uri.host == 'auth' &&
              uri.path == '/callback',
    ),
  );
  final auth = AuthController(Supabase.instance.client);
  // เริ่ม restore ก่อน build แรก เพื่อไม่แสดงหน้า Login แวบระหว่างโหลด session
  final restoring = auth.restore();
  runApp(RuamportApp(auth: auth));
  await restoring;
}
