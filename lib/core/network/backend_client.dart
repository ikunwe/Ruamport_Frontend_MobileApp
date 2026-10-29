import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'backend_cancellation.dart';
import 'health_probe.dart' as platform;

class BackendNotReady implements Exception {
  const BackendNotReady();
  String get message => 'เชื่อมต่อระบบไม่ได้ กรุณาลองใหม่';
}

typedef HealthProbe = Future<http.Response> Function(Uri, BackendCancellation);
typedef BackendRequestFactory = http.BaseRequest Function(Future<void> abort);

class _HealthFlight {
  final cancel = BackendCancellation();
  late final Future<void> future;
  int users = 0;
  bool done = false;
}

class BackendReadiness {
  BackendReadiness({
    required this.api,
    required this.health,
    required this.probe,
    DateTime Function()? now,
    bool Function()? offline,
    bool? production,
  }) : now = now ?? DateTime.now,
       offline = offline ?? platform.deviceOffline,
       production = production ?? kReleaseMode;
  final Uri api, health;
  final HealthProbe probe;
  final DateTime Function() now;
  final bool Function() offline;
  final bool production;
  final connecting = ValueNotifier(false);
  _HealthFlight? _flight;
  DateTime? _readyUntil;
  bool _disposed = false;
  void invalidate() => _readyUntil = null;

  Future<void> ensureReady(BackendCancellation waiter) async {
    waiter.check();
    if (_disposed ||
        api.origin != health.origin ||
        health.userInfo.isNotEmpty ||
        !['http', 'https'].contains(api.scheme) ||
        production && ['localhost', '127.0.0.1', '::1'].contains(health.host) ||
        offline()) {
      throw const BackendNotReady();
    }
    if (_readyUntil?.isAfter(now()) == true) return;
    var flight = _flight;
    if (flight == null) {
      flight = _HealthFlight();
      _flight = flight;
      connecting.value = true;
      final current = flight;
      flight.future = _probe(flight).whenComplete(() {
        current.done = true;
        if (identical(_flight, current)) {
          _flight = null;
          if (!_disposed) connecting.value = false;
        }
      });
    }
    flight.users++;
    try {
      await waiter.wait(flight.future);
    } finally {
      flight.users--;
      if (flight.users == 0 && !flight.done) {
        flight.cancel.cancel();
        if (identical(_flight, flight)) {
          _flight = null;
          if (!_disposed) connecting.value = false;
        }
      }
    }
  }

  Future<void> _probe(_HealthFlight flight) async {
    final round = BackendScope(const Duration(seconds: 10), [flight.cancel]);
    try {
      for (var attempt = 0; attempt < 4; attempt++) {
        round.check();
        final single = BackendScope(const Duration(milliseconds: 1500), [
          round,
        ]);
        try {
          final response = await single.wait(probe(health, single));
          single.check();
          round.check();
          if (response.statusCode != 200) throw const BackendNotReady();
          Object? body;
          try {
            body = jsonDecode(response.body);
          } catch (_) {
            throw const BackendNotReady();
          }
          if (body is! Map ||
              body['status'] != 'ok' ||
              body['service'] != 'portfolio-api') {
            throw const BackendNotReady();
          }
          _readyUntil = now().add(const Duration(seconds: 5));
          return;
        } catch (error) {
          round.check();
          if (attempt == 3 ||
              offline() ||
              error is http.RequestAbortedException ||
              !(error is http.ClientException || error is TimeoutException)) {
            throw const BackendNotReady();
          }
        } finally {
          single.dispose();
        }
        await round.delay(Duration(milliseconds: [500, 1000, 2000][attempt]));
      }
    } on TimeoutException {
      throw const BackendNotReady();
    } finally {
      round.dispose();
    }
  }

  void dispose() {
    _disposed = true;
    _flight?.cancel.cancel();
    _readyUntil = null;
    connecting.dispose();
  }
}

class BackendClient {
  BackendClient({
    required String apiUrl,
    String? healthUrl,
    http.Client? client,
    HealthProbe? healthProbe,
    DateTime Function()? now,
    bool Function()? offline,
    bool? production,
    this.checkReadiness = true,
  }) : api = Uri.parse(apiUrl),
       _http = client ?? http.Client() {
    readiness = BackendReadiness(
      api: api,
      health: Uri.parse(
        healthUrl ?? '${apiUrl.replaceFirst(RegExp(r'/$'), '')}/health',
      ),
      probe:
          healthProbe ??
          (client == null ? platform.probeHealth : _probeWithClient),
      now: now,
      offline: offline,
      production: production,
    );
  }
  final Uri api;
  final http.Client _http;
  final bool checkReadiness;
  late final BackendReadiness readiness;
  final _lifetime = BackendCancellation();
  Future<http.Response> _response(http.BaseRequest request) async =>
      http.Response.fromStream(await _http.send(request));
  Future<http.Response> _probeWithClient(
    Uri uri,
    BackendCancellation cancel,
  ) async => http.Response.fromStream(
    await _http.send(
      http.AbortableRequest('GET', uri, abortTrigger: cancel.whenCancelled),
    ),
  );

  String? path(Uri uri) {
    final root = api.path.replaceFirst(RegExp(r'/$'), '');
    if (uri.origin != api.origin ||
        uri.userInfo.isNotEmpty ||
        !(uri.path == root || uri.path.startsWith('$root/'))) {
      return null;
    }
    return uri.path.substring(root.length);
  }

  bool retryable(String path) =>
      RegExp(
        r'^/(auth/me|trades/(holdings|documents|transactions|portfolio-history|exchange-rate|market-indices|analytics/(performance|win-rate)))$',
      ).hasMatch(path) ||
      RegExp(r'^/trades/documents/[^/]+$').hasMatch(path) ||
      RegExp(r'^/trades/stocks/[^/]+/news$').hasMatch(path);

  Future<http.Response> send({
    required String method,
    required Uri uri,
    required BackendRequestFactory createRequest,
    Future<String?> Function()? tokenProvider,
    Duration timeout = const Duration(seconds: 30),
    Iterable<BackendCancellation?> cancel = const [],
  }) async {
    final scope = BackendScope(timeout, [_lifetime, ...cancel]);
    try {
      final target = path(uri);
      if (target == null) throw const BackendNotReady();
      for (var attempt = 0; ; attempt++) {
        scope.check();
        if (checkReadiness && target != '/health') {
          await scope.wait(readiness.ensureReady(scope));
        }
        final token = target == '/health' || tokenProvider == null
            ? null
            : await scope.wait(tokenProvider());
        scope.check();
        final request = createRequest(scope.whenCancelled);
        if (request.method != method || request.url != uri) {
          throw const BackendNotReady();
        }
        if (token != null) request.headers['Authorization'] = 'Bearer $token';
        try {
          final response = await scope.wait(_response(request));
          scope.check();
          return response;
        } on http.RequestAbortedException {
          rethrow;
        } on http.ClientException {
          readiness.invalidate();
          if (method != 'GET' ||
              !retryable(target) ||
              attempt >= 2 ||
              readiness.offline()) {
            rethrow;
          }
          await scope.delay(Duration(milliseconds: [500, 1500][attempt]));
        }
      }
    } finally {
      scope.dispose();
    }
  }

  void dispose() {
    _lifetime.cancel();
    readiness.dispose();
    _http.close();
  }
}
