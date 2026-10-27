import 'package:flutter/foundation.dart';

class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xjpwzrekndnwyojhncua.supabase.co',
  );
  // Publishable key เดียวกับเว็บ ใช้ใน client ได้ ไม่ใช่ service role key
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_mPtBq7GxSGgPrHcb2-Atgg_xy5K8em3',
  );
  static String get apiUrl =>
      const String.fromEnvironment('API_BASE_URL', defaultValue: '').isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
      : !kIsWeb && defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:3000/api/v1'
      : 'http://localhost:3000/api/v1';

  static String get authRedirect => kIsWeb
      ? '${Uri.base.origin}/auth/callback'
      : 'io.ruamport.mobile://auth/callback';
}
