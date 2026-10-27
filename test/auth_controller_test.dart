import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:project_portfoliomanagement_mobile/core/auth/auth_controller.dart';
import 'package:project_portfoliomanagement_mobile/core/auth/auth_scope.dart';
import 'package:project_portfoliomanagement_mobile/core/theme/app_theme.dart';
import 'package:project_portfoliomanagement_mobile/features/auth/login_page.dart';
import 'package:project_portfoliomanagement_mobile/app.dart';
import 'package:project_portfoliomanagement_mobile/features/profile/account_sheet.dart';

void main() {
  final user = {
    'id': 'test-user',
    'email': 'test@example.com',
    'aud': 'authenticated',
    'app_metadata': <String, dynamic>{},
    'user_metadata': {'name': 'Provider name'},
    'created_at': '2026-01-01T00:00:00Z',
  };
  String token(String id) {
    String encode(Map<String, dynamic> value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    return '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': 'test-user', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600, 'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000, 'jti': id})}.dGVzdA';
  }

  Map<String, dynamic> session(String id) => {
    'access_token': token(id),
    'refresh_token': 'refresh-$id',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': user,
  };
  http.Response json(Object data, [int status = 200]) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json'},
  );
  final profile = {
    'user': user,
    'profile': {
      'username': 'real.username',
      'full_name': 'Backend name',
      'avatar_url': null,
    },
    'usernameLoginEnabled': true,
  };
  late SupabaseClient supabase;
  late AuthController auth;
  late Future<http.Response> Function(http.Request) backend;
  late String initialToken;
  int refreshCalls = 0;

  setUp(() {
    refreshCalls = 0;
    final first = session('first');
    initialToken = first['access_token'] as String;
    backend = (request) async => request.url.path.endsWith('login-username')
        ? json({'session': first})
        : json(profile);
    supabase = SupabaseClient(
      'https://test.supabase.co',
      'test-publishable-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/user')) return json(user);
        if (request.url.path.endsWith('/token')) {
          refreshCalls++;
          return json(session('refreshed'));
        }
        if (request.url.path.endsWith('/logout')) return http.Response('', 204);
        throw StateError('Unexpected auth endpoint: ${request.url.path}');
      }),
    );
    auth = AuthController(
      supabase,
      httpClient: MockClient((request) => backend(request)),
      apiUrl: 'http://localhost:3000/api/v1',
    );
  });
  tearDown(() async {
    auth.dispose();
    await supabase.dispose();
  });

  testWidgets(
    'profile save sends only credentials and updates dashboard immediately',
    (tester) async {
      await tester.runAsync(() => auth.login('real.username', 'password'));
      Map<String, dynamic>? payload;
      final handler = backend;
      backend = (request) async {
        if (!request.url.path.endsWith('/credentials')) return handler(request);
        expect(request.method, 'PATCH');
        expect(request.headers['authorization'], 'Bearer $initialToken');
        payload = jsonDecode(request.body) as Map<String, dynamic>;
        return json({
          'profile': {...profile['profile'] as Map, 'username': 'new.username'},
          'usernameLoginEnabled': true,
          'session': null,
        });
      };
      await tester.pumpWidget(RuamportApp(auth: auth));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('ข้อมูลโปรไฟล์'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AccountSheet),
        matching: find.byType(TextFormField),
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: fields.at(0),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: fields.at(2),
                matching: find.byType(TextField),
              ),
            )
            .readOnly,
        isTrue,
      );
      await tester.enterText(fields.at(1), 'new.username');
      final save = find.widgetWithText(FilledButton, 'บันทึกการแก้ไข');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(payload, {'username': 'new.username'});
      expect(find.text('บันทึกข้อมูลโปรไฟล์เรียบร้อยแล้ว'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('ปิดโปรไฟล์'));
      await tester.tap(find.byTooltip('ปิดโปรไฟล์'));
      await tester.pumpAndSettle();
      expect(find.text('สวัสดี, new.username'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'password update installs the new session before the next backend request',
    () async {
      await auth.login('real.username', 'password');
      final handler = backend;
      final changed = session('password-updated');
      backend = (request) async {
        if (request.url.path.endsWith('/credentials')) {
          expect(jsonDecode(request.body), {'password': 'new password'});
          return json({
            'profile': profile['profile'],
            'usernameLoginEnabled': true,
            'session': changed,
          });
        }
        expect(
          request.headers['authorization'],
          'Bearer ${changed['access_token']}',
        );
        return handler(request);
      };
      await auth.updateCredentials(password: 'new password');
      expect(
        supabase.auth.currentSession?.accessToken,
        changed['access_token'],
      );
      expect(auth.savingProfile, isFalse);
      expect(auth.user?.username, 'real.username');
      await auth.loadProfile();
      expect(auth.profileError, isNull);
    },
  );

  test(
    'duplicate username preserves profile and clears the saving state',
    () async {
      await auth.login('real.username', 'password');
      backend = (_) async => json({
        'error': {'code': 'USERNAME_TAKEN'},
      }, 409);
      await expectLater(
        auth.updateCredentials(username: 'taken'),
        throwsA(
          isA<LoginFailure>().having(
            (failure) => failure.message,
            'message',
            contains('มีผู้ใช้แล้ว'),
          ),
        ),
      );
      expect(auth.user?.username, 'real.username');
      expect(auth.hasSession, isTrue);
      expect(auth.savingProfile, isFalse);
    },
  );

  test(
    'partial password update signs out with a message to use the new password',
    () async {
      await auth.login('real.username', 'password');
      backend = (_) async => json({
        'error': {'code': 'SESSION_REFRESH_FAILED'},
      }, 500);
      await expectLater(
        auth.updateCredentials(password: 'new password'),
        throwsA(isA<LoginFailure>()),
      );
      expect(auth.user, isNull);
      expect(auth.hasSession, isFalse);
      expect(auth.error, contains('รหัสผ่านใหม่'));
      expect(auth.savingProfile, isFalse);
    },
  );

  test('restores an SDK session by fetching the backend profile', () async {
    auth.dispose();
    final saved = session('restored');
    await supabase.auth.setSession(
      saved['refresh_token'] as String,
      accessToken: saved['access_token'] as String,
    );
    auth = AuthController(
      supabase,
      httpClient: MockClient((request) => backend(request)),
      apiUrl: 'http://localhost:3000/api/v1',
    );
    await auth.restore();
    expect(auth.user?.username, 'real.username');
    expect(auth.restoring, isFalse);
    expect(auth.profileError, isNull);
  });

  testWidgets(
    'real auth entry reaches dashboard and logout returns directly to login',
    (tester) async {
      await tester.pumpWidget(RuamportApp(auth: auth));
      await tester.pumpAndSettle();
      final start = find.text('Get started');
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'), findsOneWidget);
      expect(find.text('ดูตัวอย่าง Dashboard'), findsNothing);
      await tester.runAsync(() => auth.login('real.username', 'password'));
      await tester.pumpAndSettle();
      expect(find.text('สวัสดี, real.username'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() => auth.logout());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'เข้าสู่ระบบ'), findsOneWidget);
      expect(find.text('Get started'), findsNothing);
      expect(find.text('สวัสดี, real.username'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byIcon(Icons.arrow_back));
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
    },
  );

  testWidgets(
    'login error appears immediately and button becomes usable again',
    (tester) async {
      backend = (_) async => json({
        'error': {'code': 'INVALID_CREDENTIALS'},
      }, 401);
      await tester.pumpWidget(
        MaterialApp(
          theme: createAppTheme(),
          home: AuthScope(auth: auth, child: const LoginPage()),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(0), 'wrong.user');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'wrong password',
      );
      final button = find.widgetWithText(FilledButton, 'เข้าสู่ระบบ');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Username หรือรหัสผ่านไม่ถูกต้อง'), findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(auth.busy, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    '401 invalid credentials updates error and stops loading without a session',
    () async {
      backend = (_) async => json({
        'error': {'code': 'INVALID_CREDENTIALS'},
      }, 401);
      await auth.login('wrong.user', 'wrong password');
      expect(auth.error, 'Username หรือรหัสผ่านไม่ถูกต้อง');
      expect(auth.busy, isFalse);
      expect(auth.user, isNull);
      expect(auth.hasSession, isFalse);
    },
  );

  test(
    'uses backend credentials session and Bearer token; profile comes from /me',
    () async {
      final requests = <http.Request>[];
      final handler = backend;
      backend = (request) async {
        requests.add(request);
        return handler(request);
      };
      await auth.login(' real.username ', 'actual password');
      expect(auth.error, isNull);
      expect(auth.user?.displayName, 'real.username');
      expect(auth.user?.fullName, 'Backend name');
      expect(auth.user?.email, 'test@example.com');
      expect(jsonDecode(requests.first.body), {
        'username': 'real.username',
        'password': 'actual password',
      });
      expect(requests.last.url.path, '/api/v1/auth/me');
      expect(requests.last.headers['authorization'], 'Bearer $initialToken');
      expect(auth.hasSession, isTrue);
      await auth.logout();
      expect(auth.user, isNull);
      expect(auth.hasSession, isFalse);
    },
  );

  test(
    'refreshes expired/rejected token once and retries /me with new token',
    () async {
      final handler = backend;
      var meCalls = 0;
      backend = (request) async {
        if (!request.url.path.endsWith('/me')) return handler(request);
        meCalls++;
        return meCalls == 1
            ? json({
                'error': {'code': 'UNAUTHORIZED'},
              }, 401)
            : json(profile);
      };
      await auth.login('real.username', 'password');
      expect(auth.user?.username, 'real.username');
      expect(meCalls, 2);
      expect(refreshCalls, 1);
      expect(supabase.auth.currentSession?.accessToken, isNot(initialToken));
    },
  );

  test(
    'profile outage keeps session for retry but does not enter dashboard with fake user',
    () async {
      final handler = backend;
      backend = (request) async => request.url.path.endsWith('/me')
          ? json({
              'error': {'code': 'UNAVAILABLE'},
            }, 503)
          : handler(request);
      await auth.login('real.username', 'password');
      expect(auth.hasSession, isTrue);
      expect(auth.user, isNull);
      expect(auth.profileError, contains('503'));
      expect(auth.busy, isFalse);
      backend = handler;
      await auth.loadProfile();
      expect(auth.user?.username, 'real.username');
      expect(auth.profileError, isNull);
    },
  );

  test('a late profile response cannot restore a user after logout', () async {
    final handler = backend;
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    backend = (request) async {
      if (!request.url.path.endsWith('/me')) return handler(request);
      started.complete();
      return pending.future;
    };
    final login = auth.login('real.username', 'password');
    await started.future;
    await auth.logout();
    pending.complete(json(profile));
    await login;
    expect(auth.user, isNull);
    expect(auth.hasSession, isFalse);
    expect(auth.restoring, isFalse);
  });
}
