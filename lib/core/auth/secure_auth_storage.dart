import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _storage = FlutterSecureStorage();

class SecureAuthStorage extends LocalStorage {
  const SecureAuthStorage();
  static const _key = 'ruamport.mobile.auth.session';
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() => _storage.containsKey(key: _key);
  @override
  Future<String?> accessToken() => _storage.read(key: _key);
  @override
  Future<void> persistSession(String persistSessionString) =>
      _storage.write(key: _key, value: persistSessionString);
  @override
  Future<void> removePersistedSession() => _storage.delete(key: _key);
}

class SecurePkceStorage extends GotrueAsyncStorage {
  @override
  Future<String?> getItem({required String key}) =>
      _storage.read(key: 'ruamport.mobile.pkce.$key');
  @override
  Future<void> setItem({required String key, required String value}) =>
      _storage.write(key: 'ruamport.mobile.pkce.$key', value: value);
  @override
  Future<void> removeItem({required String key}) =>
      _storage.delete(key: 'ruamport.mobile.pkce.$key');
}
