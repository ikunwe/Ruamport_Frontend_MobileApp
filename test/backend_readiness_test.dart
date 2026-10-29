import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:project_portfoliomanagement_mobile/core/network/backend_client.dart';
import 'package:project_portfoliomanagement_mobile/core/network/backend_cancellation.dart';

class RecordingClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];
  final aborted = <http.BaseRequest>[];
  late Future<http.Response> Function(http.BaseRequest) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (request is http.Abortable) {
      request.abortTrigger?.then((_) => aborted.add(request));
    }
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
    );
  }
}

class Outcome<T> {
  Outcome(Future<T> future) {
    future.then<void>(
      (value) {
        data = value;
      },
      onError: (Object error) {
        failure = error;
      },
    );
  }
  T? data;
  Object? failure;
}

void main() {
  const base = 'http://localhost:3000/api/v1';
  http.Response good() =>
      http.Response('{"status":"ok","service":"portfolio-api"}', 200);
  Future<http.Response> call(
    BackendClient backend, {
    String method = 'GET',
    String path = '/trades/holdings',
    BackendCancellation? cancel,
    Future<String?> Function()? token,
    Duration timeout = const Duration(seconds: 180),
  }) {
    final uri = Uri.parse('$base$path');
    return backend.send(
      method: method,
      uri: uri,
      timeout: timeout,
      cancel: [cancel],
      tokenProvider: token,
      createRequest: (abort) =>
          http.AbortableRequest(method, uri, abortTrigger: abort),
    );
  }

  int healthCalls(RecordingClient client) =>
      client.requests.where((r) => r.url.path.endsWith('/health')).length;
  int businessCalls(RecordingClient client) =>
      client.requests.length - healthCalls(client);

  testWidgets(
    'shares one token-free health flight and checks current token after readiness',
    (tester) async {
      final client = RecordingClient();
      final probe = Completer<http.Response>();
      var token = 'old', tokenCalls = 0;
      client.handler = (request) async => request.url.path.endsWith('/health')
          ? probe.future
          : http.Response('{}', 200);
      final backend = BackendClient(apiUrl: base, client: client);
      Future<String?> session() async {
        tokenCalls++;
        return token;
      }

      final a = Outcome(call(backend, token: session)),
          b = Outcome(call(backend, path: '/auth/me', token: session));
      await tester.pump();
      expect(healthCalls(client), 1);
      expect(businessCalls(client), 0);
      expect(tokenCalls, 0);
      expect(
        client.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
      token = 'new';
      probe.complete(good());
      await tester.pump();
      expect(a.failure, isNull);
      expect(b.failure, isNull);
      expect(businessCalls(client), 2);
      expect(
        client.requests
            .skip(1)
            .every((r) => r.headers['Authorization'] == 'Bearer new'),
        isTrue,
      );
      expect(backend.readiness.connecting.value, isFalse);
      backend.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'two health network failures wait 500 and 1000ms before success',
    (tester) async {
      final client = RecordingClient();
      var count = 0;
      client.handler = (request) async {
        if (!request.url.path.endsWith('/health')) {
          return http.Response('{}', 200);
        }
        if (++count < 3) throw http.ClientException('network');
        return good();
      };
      final backend = BackendClient(apiUrl: base, client: client);
      final result = Outcome(call(backend));
      await tester.pump();
      expect(count, 1);
      expect(businessCalls(client), 0);
      await tester.pump(const Duration(milliseconds: 499));
      expect(count, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(count, 2);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(count, 3);
      expect(result.data?.statusCode, 200);
      backend.dispose();
      await tester.pump();
    },
  );

  testWidgets(
    'aborts health timeouts and stops at four attempts within ten seconds; manual retry works',
    (tester) async {
      final client = RecordingClient();
      var available = false;
      client.handler = (request) => available
          ? Future.value(
              request.url.path.endsWith('/health')
                  ? good()
                  : http.Response('{}', 200),
            )
          : Completer<http.Response>().future;
      final backend = BackendClient(apiUrl: base, client: client);
      final result = Outcome(call(backend));
      await tester.pump();
      for (final wait in [500, 1000, 2000, null]) {
        await tester.pump(const Duration(milliseconds: 1500));
        if (wait != null) await tester.pump(Duration(milliseconds: wait));
      }
      expect(healthCalls(client), 4);
      expect(client.aborted.length, 4);
      expect(businessCalls(client), 0);
      expect(result.failure, isA<BackendNotReady>());
      expect(backend.readiness.connecting.value, isFalse);
      available = true;
      final retry = Outcome(call(backend));
      await tester.pump();
      expect(retry.data?.statusCode, 200);
      backend.dispose();
      await tester.pump();
    },
  );

  for (final body in [
    '<html>other service</html>',
    '{}',
    '{"status":"ok","service":"wrong"}',
  ]) {
    testWidgets('invalid health is not retried: $body', (tester) async {
      final client = RecordingClient()
        ..handler = (_) async => http.Response(body, 200);
      final backend = BackendClient(apiUrl: base, client: client);
      final result = Outcome(call(backend));
      await tester.pump();
      await tester.pump(const Duration(seconds: 15));
      expect(result.failure, isA<BackendNotReady>());
      expect(healthCalls(client), 1);
      expect(businessCalls(client), 0);
      backend.dispose();
      await tester.pump();
    });
  }
  for (final status in [204, 401, 429, 503]) {
    testWidgets('health HTTP $status stops without retries or business calls', (
      tester,
    ) async {
      final client = RecordingClient()
        ..handler = (_) async => http.Response('{}', status);
      final backend = BackendClient(apiUrl: base, client: client);
      final result = Outcome(call(backend));
      await tester.pump();
      await tester.pump(const Duration(seconds: 15));
      expect(result.failure, isA<BackendNotReady>());
      expect(client.requests.length, 1);
      backend.dispose();
      await tester.pump();
    });
  }

  testWidgets(
    'GET retries twice at 500/1500ms, invalidates health and obtains a fresh token each time',
    (tester) async {
      final client = RecordingClient();
      var count = 0, tokens = 0;
      client.handler = (request) async {
        if (request.url.path.endsWith('/health')) return good();
        if (++count < 3) throw http.ClientException('network');
        return http.Response('{}', 200);
      };
      final backend = BackendClient(apiUrl: base, client: client);
      final result = Outcome(
        call(backend, token: () async => 'token-${++tokens}'),
      );
      await tester.pump();
      expect(count, 1);
      await tester.pump(const Duration(milliseconds: 499));
      expect(count, 1);
      await tester.pump(const Duration(milliseconds: 1));
      expect(count, 2);
      await tester.pump(const Duration(milliseconds: 1499));
      expect(count, 2);
      await tester.pump(const Duration(milliseconds: 1));
      expect(count, 3);
      expect(healthCalls(client), 3);
      expect(tokens, 3);
      expect(result.data?.statusCode, 200);
      expect(client.requests.last.headers['Authorization'], 'Bearer token-3');
      backend.dispose();
      await tester.pump();
    },
  );

  testWidgets('permanent network failure has at most three business attempts', (
    tester,
  ) async {
    final client = RecordingClient()
      ..handler = (request) async {
        if (request.url.path.endsWith('/health')) return good();
        throw http.ClientException('network');
      };
    final backend = BackendClient(apiUrl: base, client: client);
    final result = Outcome(call(backend));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(seconds: 20));
    expect(businessCalls(client), 3);
    expect(result.failure, isA<http.ClientException>());
    backend.dispose();
    await tester.pump();
  });

  testWidgets(
    'a failed health recheck terminates the logical GET without another outer retry',
    (tester) async {
      final client = RecordingClient();
      var health = 0;
      client.handler = (request) async {
        if (request.url.path.endsWith('/health')) {
          return ++health == 1 ? good() : http.Response('{}', 503);
        }
        throw http.ClientException('network');
      };
      final backend = BackendClient(apiUrl: base, client: client);
      final result = Outcome(call(backend));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 20));
      expect(result.failure, isA<BackendNotReady>());
      expect(health, 2);
      expect(businessCalls(client), 1);
      backend.dispose();
      await tester.pump();
    },
  );

  for (final status in [200, 401, 429, 503]) {
    testWidgets(
      'business HTTP $status and PARTIAL/retryAt are returned unchanged without retry',
      (tester) async {
        final client = RecordingClient();
        final response = http.Response(
          '{"status":"INCOMPLETE","retryAt":"2026-11-01"}',
          status,
        );
        client.handler = (request) async =>
            request.url.path.endsWith('/health') ? good() : response;
        final backend = BackendClient(apiUrl: base, client: client);
        final result = Outcome(call(backend));
        await tester.pump();
        await tester.pump(const Duration(seconds: 20));
        expect(businessCalls(client), 1);
        expect(result.data?.statusCode, status);
        expect(result.data?.body, response.body);
        backend.dispose();
        await tester.pump();
      },
    );
  }

  for (final entry in [
    ('POST', '/auth/login-username'),
    ('POST', '/trades/import'),
    ('POST', '/trades/upload-preview'),
    ('POST', '/trades/simulate-sale'),
    ('PATCH', '/auth/credentials'),
    ('DELETE', '/mail/gmail/connection'),
    ('PUT', '/test'),
  ]) {
    testWidgets(
      '${entry.$1} ${entry.$2} waits for health but is never resent',
      (tester) async {
        final client = RecordingClient()
          ..handler = (request) async {
            if (request.url.path.endsWith('/health')) return good();
            throw http.ClientException('network');
          };
        final backend = BackendClient(apiUrl: base, client: client);
        final result = Outcome(call(backend, method: entry.$1, path: entry.$2));
        await tester.pump();
        await tester.pump(const Duration(seconds: 20));
        expect(businessCalls(client), 1);
        expect(result.failure, isA<http.ClientException>());
        backend.dispose();
        await tester.pump();
      },
    );
  }

  testWidgets(
    'one cancelled waiter does not abort shared health; last waiter aborts it',
    (tester) async {
      final client = RecordingClient()
        ..handler = (_) => Completer<http.Response>().future;
      final backend = BackendClient(apiUrl: base, client: client);
      final a = BackendCancellation(), b = BackendCancellation();
      final first = Outcome(call(backend, cancel: a)),
          second = Outcome(call(backend, cancel: b));
      await tester.pump();
      a.cancel();
      await tester.pump();
      expect(first.failure, isA<BackendCancelled>());
      expect(client.aborted, isEmpty);
      expect(healthCalls(client), 1);
      b.cancel();
      await tester.pump();
      expect(second.failure, isA<BackendCancelled>());
      expect(client.aborted.length, 1);
      expect(backend.readiness.connecting.value, isFalse);
      backend.dispose();
      await tester.pump();
    },
  );

  for (final phase in ['health', 'delay', 'api']) {
    testWidgets(
      'logout, account change or page cancellation during $phase stops future attempts',
      (tester) async {
        final client = RecordingClient()
          ..handler = (request) async {
            if (request.url.path.endsWith('/health')) {
              return phase == 'health'
                  ? Completer<http.Response>().future
                  : good();
            }
            if (phase == 'delay') throw http.ClientException('network');
            return Completer<http.Response>().future;
          };
        final backend = BackendClient(apiUrl: base, client: client);
        final cancel = BackendCancellation();
        final result = Outcome(call(backend, cancel: cancel));
        await tester.pump();
        final calls = client.requests.length;
        cancel.cancel();
        await tester.pump();
        await tester.pump(const Duration(seconds: 20));
        expect(result.failure, isA<BackendCancelled>());
        expect(client.requests.length, calls);
        expect(backend.readiness.connecting.value, isFalse);
        backend.dispose();
        await tester.pump();
      },
    );
  }

  testWidgets(
    'Analytics has one 180-second deadline including health and retry delay, with actual abort',
    (tester) async {
      final client = RecordingClient();
      final first = Completer<http.Response>();
      var count = 0;
      client.handler = (request) async {
        if (request.url.path.endsWith('/health')) return good();
        if (++count == 1) return first.future;
        return Completer<http.Response>().future;
      };
      final backend = BackendClient(apiUrl: base, client: client);
      final result = Outcome(
        call(backend, path: '/trades/analytics/performance'),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 100));
      first.completeError(http.ClientException('network'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 79500));
      expect(result.failure, isA<TimeoutException>());
      expect(count, 2);
      expect(client.aborted.contains(client.requests.last), isTrue);
      await tester.pump(const Duration(seconds: 200));
      expect(count, 2);
      backend.dispose();
      await tester.pump();
    },
  );

  testWidgets('READY expires after five seconds with no idle health polling', (
    tester,
  ) async {
    final client = RecordingClient()
      ..handler = (r) async =>
          r.url.path.endsWith('/health') ? good() : http.Response('{}', 200);
    final backend = BackendClient(
      apiUrl: base,
      client: client,
      now: tester.binding.clock.now,
    );
    Outcome(call(backend));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 4999));
    Outcome(call(backend));
    await tester.pump();
    expect(healthCalls(client), 1);
    await tester.pump(const Duration(milliseconds: 1));
    Outcome(call(backend));
    await tester.pump();
    expect(healthCalls(client), 2);
    await tester.pump(const Duration(minutes: 1));
    expect(healthCalls(client), 2);
    backend.dispose();
    await tester.pump();
  });

  testWidgets(
    'offline hint stops immediately; abort and timeout do not trigger network retry',
    (tester) async {
      final client = RecordingClient()..handler = (_) async => good();
      final offline = BackendClient(
        apiUrl: base,
        client: client,
        offline: () => true,
      );
      final stopped = Outcome(call(offline));
      await tester.pump();
      expect(stopped.failure, isA<BackendNotReady>());
      expect(client.requests, isEmpty);
      offline.dispose();
      for (final error in [
        http.RequestAbortedException(),
        TimeoutException('endpoint'),
      ]) {
        final c = RecordingClient()
          ..handler = (r) async {
            if (r.url.path.endsWith('/health')) return good();
            throw error;
          };
        final backend = BackendClient(apiUrl: base, client: c);
        final result = Outcome(call(backend));
        await tester.pump();
        await tester.pump(const Duration(seconds: 20));
        expect(result.failure, same(error));
        expect(businessCalls(c), 1);
        backend.dispose();
        await tester.pump();
      }
    },
  );

  testWidgets(
    'invalid origins and production localhost are rejected without a token or request',
    (tester) async {
      for (final options in ['origin', 'production', 'external']) {
        final client = RecordingClient()..handler = (_) async => good();
        var tokens = 0;
        final backend = BackendClient(
          apiUrl: base,
          client: client,
          production: options == 'production',
          healthUrl: options == 'origin' ? 'https://example.com/health' : null,
        );
        final uri = Uri.parse(
          options == 'external'
              ? 'http://localhost.example.com/api/v1/auth/me'
              : '$base/auth/me',
        );
        final result = Outcome(
          backend.send(
            method: 'GET',
            uri: uri,
            tokenProvider: () async {
              tokens++;
              return 'secret';
            },
            createRequest: (abort) =>
                http.AbortableRequest('GET', uri, abortTrigger: abort),
          ),
        );
        await tester.pump();
        expect(result.failure, isA<BackendNotReady>());
        expect(tokens, 0);
        expect(client.requests, isEmpty);
        backend.dispose();
        await tester.pump();
      }
    },
  );

  for (final path in [
    '/auth/callback',
    '/mail/connection',
    '/trades/unknown',
  ]) {
    testWidgets('GET $path is not in the retry allowlist', (tester) async {
      final client = RecordingClient()
        ..handler = (r) async {
          if (r.url.path.endsWith('/health')) return good();
          throw http.ClientException('network');
        };
      final backend = BackendClient(apiUrl: base, client: client);
      final result = Outcome(call(backend, path: path));
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      expect(result.failure, isA<http.ClientException>());
      expect(businessCalls(client), 1);
      backend.dispose();
      await tester.pump();
    });
  }
}
