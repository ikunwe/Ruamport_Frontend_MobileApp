import 'dart:js_interop';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'backend_cancellation.dart';

bool deviceOffline() => !web.window.navigator.onLine;
Future<http.Response> probeHealth(Uri uri, BackendCancellation cancel) async {
  final controller = web.AbortController();
  final detach = cancel.listen(() => controller.abort());
  try {
    final response = await web.window
        .fetch(
          uri.toString().toJS,
          web.RequestInit(
            method: 'GET',
            cache: 'no-store',
            credentials: 'omit',
            redirect: 'error',
            signal: controller.signal,
          ),
        )
        .toDart;
    final body = (await response.text().toDart).toDart;
    return http.Response(body, response.status);
  } catch (_) {
    cancel.check();
    throw http.ClientException('Health network request failed', uri);
  } finally {
    detach();
  }
}
