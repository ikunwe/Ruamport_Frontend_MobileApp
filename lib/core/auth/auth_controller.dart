import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import 'app_user.dart';

class LoginFailure implements Exception {
  const LoginFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthController extends ChangeNotifier {
  AuthController(this.supabase, {http.Client? httpClient, String? apiUrl})
    : _http = httpClient ?? http.Client(),
      _apiUrl = apiUrl ?? AppConfig.apiUrl {
    _subscription = supabase.auth.onAuthStateChange.listen(
      (state) {
        if (state.event == AuthChangeEvent.signedOut) {
          _epoch++;
          user = null;
          profileError = null;
          restoring = false;
          notifyListeners();
        } else if (state.session != null && !_credentialLogin && user == null) {
          // ออกจาก callback ก่อนเรียก SDK ซ้ำ เพื่อไม่ค้างใน auth event
          unawaited(Future<void>(() => loadProfile()));
        }
      },
      onError: (Object _) {
        error = 'เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
        busy = false;
        restoring = false;
        notifyListeners();
      },
    );
  }
  final SupabaseClient supabase;
  final http.Client _http;
  final String _apiUrl;
  late final StreamSubscription<AuthState> _subscription;
  AppUser? user;
  String? error, profileError;
  bool busy = false, restoring = false;
  bool savingProfile = false;
  bool _credentialLogin = false, _loadingProfile = false, _disposed = false;
  int _epoch = 0;
  bool get hasSession => supabase.auth.currentSession != null;

  Future<String> tokenForApi() async {
    try {
      if (supabase.auth.currentSession?.isExpired == true) {
        await supabase.auth.refreshSession().timeout(
          const Duration(seconds: 20),
        );
      }
    } on AuthException {
      await logout();
      throw const LoginFailure('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null || user == null) {
      throw const LoginFailure('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }
    return token;
  }

  Future<void> restore() async {
    if (hasSession) await loadProfile();
  }

  Future<Map<String, dynamic>> _request(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    String method = 'POST',
  }) async {
    try {
      final uri = Uri.parse('${_apiUrl.replaceFirst(RegExp(r'/$'), '')}$path');
      final headers = <String, String>{
        if (body != null) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final response =
          await (body == null
                  ? _http.get(uri, headers: headers)
                  : method == 'PATCH'
                  ? _http.patch(uri, headers: headers, body: jsonEncode(body))
                  : _http.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(const Duration(seconds: 20));
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        throw const LoginFailure('Backend ตอบกลับไม่ถูกต้อง กรุณาลองใหม่');
      }
      if (response.statusCode >= 400) {
        final detail = data['error'];
        final code = detail is Map ? detail['code'] : null;
        if (response.statusCode == 401 && path != '/auth/login-username') {
          throw const LoginFailure('SESSION_EXPIRED');
        }
        throw LoginFailure(switch (code) {
          'INVALID_CREDENTIALS' => 'Username หรือรหัสผ่านไม่ถูกต้อง',
          'INVALID_USERNAME' => 'Username ต้องมี 3–50 ตัวอักษร และไม่มี @',
          'PASSWORD_REQUIRED' => 'กรุณากรอกรหัสผ่าน',
          'INVALID_PASSWORD' => 'รหัสผ่านต้องมี 8–72 ตัวอักษร',
          'USERNAME_TAKEN' => 'Username นี้มีผู้ใช้แล้ว กรุณาเลือกชื่ออื่น',
          'VALIDATION_ERROR' => 'กรุณาตรวจสอบ Username และรหัสผ่าน',
          'SESSION_REFRESH_FAILED' => 'PASSWORD_UPDATED_SESSION_FAILED',
          'EMAIL_REQUIRED' =>
            'บัญชีนี้ไม่มีอีเมลที่ใช้งานได้ กรุณาเลือกบัญชีอื่น',
          _ =>
            response.statusCode == 429
                ? 'ลองเข้าสู่ระบบหลายครั้งเกินไป กรุณารอสักครู่'
                : 'เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่ (${response.statusCode})',
        });
      }
      return data;
    } on TimeoutException {
      throw const LoginFailure('Backend ใช้เวลาตอบนานเกินไป กรุณาลองใหม่');
    } on http.ClientException {
      throw const LoginFailure(
        'เชื่อมต่อ Backend ไม่สำเร็จ กรุณาตรวจว่า Backend เปิดอยู่และอนุญาต origin ของแอป',
      );
    }
  }

  Future<void> login(String username, String password) async {
    if (busy) return;
    busy = true;
    error = null;
    _credentialLogin = true;
    notifyListeners();
    try {
      final data = await _request(
        '/auth/login-username',
        body: {'username': username.trim(), 'password': password},
      );
      final session = data['session'] as Map<String, dynamic>?;
      if (session?['refresh_token'] is! String ||
          session?['access_token'] is! String) {
        throw const LoginFailure('Backend ไม่ได้ส่ง Session สำหรับเข้าสู่ระบบ');
      }
      // ให้ SDK ตรวจสอบและจัดการอายุ token แทนการเก็บ token เอง
      await supabase.auth
          .setSession(
            session!['refresh_token'] as String,
            accessToken: session['access_token'] as String,
          )
          .timeout(const Duration(seconds: 20));
      await loadProfile();
    } catch (failure) {
      error = _message(failure);
    } finally {
      _credentialLogin = false;
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> social(OAuthProvider provider) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final launched = await supabase.auth
          .signInWithOAuth(
            provider,
            redirectTo: AppConfig.authRedirect,
            queryParams: provider == OAuthProvider.google
                ? {'prompt': 'select_account'}
                : null,
          )
          .timeout(const Duration(seconds: 20));
      if (!launched) {
        throw const LoginFailure('เปิดหน้าเข้าสู่ระบบไม่ได้ กรุณาลองใหม่');
      }
    } catch (failure) {
      error = _message(failure);
    } finally {
      // ไม่รอ OAuth ค้างไว้: หากกดย้อนกลับจากหน้าเลือกบัญชียังกดใหม่ได้
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> loadProfile() async {
    if (_loadingProfile || !hasSession) return;
    final epoch = _epoch;
    _loadingProfile = true;
    restoring = true;
    profileError = null;
    if (!_disposed) notifyListeners();
    try {
      if (supabase.auth.currentSession!.isExpired) {
        await supabase.auth.refreshSession().timeout(
          const Duration(seconds: 20),
        );
      }
      Map<String, dynamic> data;
      try {
        data = await _request(
          '/auth/me',
          token: supabase.auth.currentSession?.accessToken,
        );
      } on LoginFailure catch (failure) {
        if (failure.message != 'SESSION_EXPIRED') rethrow;
        await supabase.auth.refreshSession().timeout(
          const Duration(seconds: 20),
        );
        data = await _request(
          '/auth/me',
          token: supabase.auth.currentSession?.accessToken,
        );
      }
      final account = AppUser.fromJson(data);
      if (account.id != supabase.auth.currentUser?.id) {
        throw const LoginFailure(
          'ข้อมูลผู้ใช้ไม่ตรงกับ Session กรุณาเข้าสู่ระบบใหม่',
        );
      }
      if (epoch == _epoch && !_disposed) user = account;
    } catch (failure) {
      if (epoch == _epoch && !_disposed) {
        profileError = _message(failure);
        if (failure is AuthException ||
            failure is LoginFailure && failure.message == 'SESSION_EXPIRED') {
          await logout();
          error = 'Session หมดอายุ กรุณาเข้าสู่ระบบใหม่';
        }
      }
    } finally {
      _loadingProfile = false;
      if (epoch == _epoch && !_disposed) {
        restoring = false;
        notifyListeners();
      }
    }
  }

  Future<void> logout() async {
    _epoch++;
    user = null;
    error = null;
    profileError = null;
    restoring = false;
    try {
      await supabase.auth
          .signOut(scope: SignOutScope.local)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      if (hasSession) error = 'ออกจากระบบไม่สำเร็จ กรุณาลองใหม่';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> updateCredentials({String? username, String? password}) async {
    if (savingProfile) return;
    final current = user;
    if (current == null || !hasSession) {
      throw const LoginFailure('Session หมดอายุ กรุณาเข้าสู่ระบบใหม่');
    }
    final epoch = _epoch;
    savingProfile = true;
    bool passwordSaved = false;
    notifyListeners();
    try {
      if (supabase.auth.currentSession!.isExpired) {
        await supabase.auth.refreshSession().timeout(
          const Duration(seconds: 20),
        );
      }
      final data = await _request(
        '/auth/credentials',
        method: 'PATCH',
        token: supabase.auth.currentSession?.accessToken,
        body: {
          if (username != null) 'username': username.trim(),
          'password': ?password,
        },
      );
      passwordSaved = password != null;
      if (epoch != _epoch || _disposed) return;
      final session = data['session'] as Map<String, dynamic>?;
      if (password != null &&
          (session?['access_token'] is! String ||
              session?['refresh_token'] is! String)) {
        throw const LoginFailure('PASSWORD_UPDATED_SESSION_FAILED');
      }
      if (session != null) {
        // รับ Session ใหม่ทันที ก่อนเรียก API ครั้งถัดไปหลังเปลี่ยนรหัสผ่าน
        _credentialLogin = true;
        await supabase.auth
            .setSession(
              session['refresh_token'] as String,
              accessToken: session['access_token'] as String,
            )
            .timeout(const Duration(seconds: 20));
      }
      if (epoch != _epoch || _disposed) return;
      if (data['profile'] is! Map<String, dynamic>) {
        throw const LoginFailure(
          'บันทึกแล้วแต่ข้อมูลโปรไฟล์ตอบกลับไม่ครบ กรุณาโหลดใหม่',
        );
      }
      user = AppUser.fromJson({
        'user': {'id': current.id, 'email': current.email},
        'profile': data['profile'],
        'usernameLoginEnabled': data['usernameLoginEnabled'],
      });
    } catch (failure) {
      if (epoch != _epoch || _disposed) return;
      final partialPasswordUpdate =
          passwordSaved ||
          failure is LoginFailure &&
              failure.message == 'PASSWORD_UPDATED_SESSION_FAILED';
      if (partialPasswordUpdate) {
        await logout();
        error =
            'รหัสผ่านอาจเปลี่ยนแล้ว แต่รับ Session ใหม่ไม่สำเร็จ กรุณาเข้าสู่ระบบด้วยรหัสผ่านใหม่';
        throw LoginFailure(error!);
      }
      if (failure is AuthException ||
          failure is LoginFailure && failure.message == 'SESSION_EXPIRED') {
        await logout();
        error = 'Session หมดอายุ กรุณาเข้าสู่ระบบใหม่';
        throw LoginFailure(error!);
      }
      throw LoginFailure(
        failure is LoginFailure
            ? failure.message
            : 'บันทึกข้อมูลไม่สำเร็จ กรุณาลองใหม่',
      );
    } finally {
      _credentialLogin = false;
      savingProfile = false;
      if (!_disposed) notifyListeners();
    }
  }

  String _message(Object failure) => failure is LoginFailure
      ? failure.message == 'SESSION_EXPIRED'
            ? 'Session หมดอายุ กรุณาเข้าสู่ระบบใหม่'
            : failure.message
      : failure is TimeoutException
      ? 'การเข้าสู่ระบบใช้เวลานานเกินไป กรุณาลองใหม่'
      : 'เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    _http.close();
    super.dispose();
  }
}
