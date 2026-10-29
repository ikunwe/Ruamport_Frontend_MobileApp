import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_portfoliomanagement_mobile/core/network/mail_authorization_return_native.dart';

void main() {
  testWidgets(
    'checks return once after departure, never on initial focus or after disposal',
    (tester) async {
      var calls = 0;
      final observer = MailAuthorizationReturnObserver(() => calls++);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.arm();
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(calls, 0);
      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(calls, 1);
      observer.arm();
      observer.disarm();
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(calls, 1);
      observer.arm();
      observer.dispose();
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(calls, 1);
    },
  );
}
