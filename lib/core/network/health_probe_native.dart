import 'package:http/http.dart' as http;
import 'backend_cancellation.dart';

bool deviceOffline() => false;
Future<http.Response> probeHealth(Uri uri, BackendCancellation cancel) async {
  final client = http.Client();
  try {
    final request = http.AbortableRequest(
      'GET',
      uri,
      abortTrigger: cancel.whenCancelled,
    );
    request.followRedirects = false;
    request.headers['Cache-Control'] = 'no-store';
    return await http.Response.fromStream(await client.send(request));
  } finally {
    client.close();
  }
}
