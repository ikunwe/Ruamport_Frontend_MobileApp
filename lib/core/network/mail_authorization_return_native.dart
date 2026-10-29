import 'package:flutter/widgets.dart';

class MailAuthorizationReturnObserver with WidgetsBindingObserver {
  MailAuthorizationReturnObserver(this.onReturn) {
    WidgetsBinding.instance.addObserver(this);
  }
  final VoidCallback onReturn;
  bool _armed = false, _left = false;
  void arm() {
    _armed = true;
    _left = false;
  }

  void disarm() {
    _armed = false;
    _left = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_armed) return;
    if ([
      AppLifecycleState.inactive,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
    ].contains(state)) {
      _left = true;
    }
    if (state == AppLifecycleState.resumed && _left) {
      disarm();
      onReturn();
    }
  }

  void dispose() {
    disarm();
    WidgetsBinding.instance.removeObserver(this);
  }
}
