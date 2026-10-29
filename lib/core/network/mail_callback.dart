import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class MailCallbackResult {
  const MailCallbackResult(this.errorCode);
  final String? errorCode;

  static MailCallbackResult? parse(Uri uri) {
    if (uri.scheme != 'io.ruamport.mobile' ||
        uri.host != 'mail' ||
        uri.path != '/return' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        uri.queryParametersAll.values.any((v) => v.length != 1) ||
        uri.queryParameters.keys.any(
          (k) => !['mailConnection', 'code'].contains(k),
        )) {
      return null;
    }
    final status = uri.queryParameters['mailConnection'];
    if (status == 'connected' && !uri.queryParameters.containsKey('code')) {
      return const MailCallbackResult(null);
    }
    final code = uri.queryParameters['code'];
    if (status == 'error' &&
        code != null &&
        RegExp(r'^(?:MAIL|GMAIL)_[A-Z_]{1,64}$').hasMatch(code)) {
      return MailCallbackResult(code);
    }
    return null;
  }
}

// Navigation hint only: connection status must always be read from authenticated Backend.
class MailCallbackInbox extends ChangeNotifier {
  StreamSubscription<Uri>? _subscription;
  MailCallbackResult? _pending;
  Uri? _initial;
  Timer? _initialTimer;
  bool _starting = false;

  Future<void> start() async {
    if (kIsWeb || _starting) return;
    _starting = true;
    final links = AppLinks();
    _subscription = links.uriLinkStream.listen((uri) {
      final initial = _initial;
      _initial = null;
      if (initial == uri) return;
      accept(uri);
    }, onError: (Object _) {});
    try {
      final initial = await links.getInitialLink().timeout(
        const Duration(seconds: 2),
      );
      if (initial != null) {
        _initial = initial;
        // Suppress only startup replay, not a later authorization with the same result URL.
        _initialTimer = Timer(
          const Duration(seconds: 2),
          () => _initial = null,
        );
        // uriLinkStream can already have delivered this link during startup.
        if (_pending == null) accept(initial);
      }
    } catch (_) {
      // Manual return and authenticated status refresh remain available.
    }
  }

  void accept(Uri uri) {
    final parsed = MailCallbackResult.parse(uri);
    if (parsed == null) return;
    _pending = parsed;
    notifyListeners();
  }

  MailCallbackResult? take() {
    final value = _pending;
    _pending = null;
    return value;
  }

  @override
  void dispose() {
    _initialTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final mailCallbackInbox = MailCallbackInbox();
