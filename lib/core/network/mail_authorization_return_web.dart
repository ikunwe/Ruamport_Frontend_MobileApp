import 'dart:js_interop';
import 'package:web/web.dart' as web;

class MailAuthorizationReturnObserver {
  MailAuthorizationReturnObserver(this.onReturn) {
    _leave = ((web.Event _) {
      if (_armed) _left = true;
    }).toJS;
    _returned = ((web.Event event) {
      // Back/Forward cache can restore this exact Dart state without rebuilding the sheet.
      if (event.type == 'pageshow' &&
          (event as web.PageTransitionEvent).persisted &&
          _armed) {
        _left = true;
      }
      _check();
    }).toJS;
    _visibility = ((web.Event _) {
      if (web.document.visibilityState == 'hidden' && _armed) _left = true;
      _check();
    }).toJS;
    web.window.addEventListener('pagehide', _leave);
    web.window.addEventListener('blur', _leave);
    web.window.addEventListener('pageshow', _returned);
    web.window.addEventListener('focus', _returned);
    web.document.addEventListener('visibilitychange', _visibility);
  }
  final void Function() onReturn;
  bool _armed = false, _left = false;
  late final JSFunction _leave, _returned, _visibility;
  void arm() {
    _armed = true;
    _left = false;
  }

  void disarm() {
    _armed = false;
    _left = false;
  }

  void _check() {
    if (_armed && _left && web.document.visibilityState == 'visible') {
      disarm();
      onReturn();
    }
  }

  void dispose() {
    disarm();
    web.window.removeEventListener('pagehide', _leave);
    web.window.removeEventListener('blur', _leave);
    web.window.removeEventListener('pageshow', _returned);
    web.window.removeEventListener('focus', _returned);
    web.document.removeEventListener('visibilitychange', _visibility);
  }
}
