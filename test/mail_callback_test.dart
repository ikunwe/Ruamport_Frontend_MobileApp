import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_portfoliomanagement_mobile/core/network/mail_callback.dart';
import 'package:project_portfoliomanagement_mobile/features/import/import_api.dart';
import 'package:project_portfoliomanagement_mobile/features/import/import_controller.dart';

void main() {
  test(
    'deep link waits for older lifecycle status and fetches fresh connection after callback',
    () async {
      final oldResponse = Completer<http.Response>();
      var requests = 0;
      final controller = ImportController(
        ImportApi(
          tokenProvider: () async => 'token',
          checkReadiness: false,
          apiUrl: 'http://localhost:3000/api/v1',
          client: MockClient((request) async {
            requests++;
            if (requests == 1) return oldResponse.future;
            return http.Response('{"supported":true,"connected":true}', 200);
          }),
        ),
        mail: true,
      );
      addTearDown(controller.dispose);
      final lifecycle = controller.loadConnection();
      await Future<void>.delayed(Duration.zero);
      final callback = controller.resumeMailAuthorization(fromCallback: true);
      oldResponse.complete(
        http.Response('{"supported":true,"connected":false}', 200),
      );
      await lifecycle;
      await callback;
      expect(requests, 2);
      expect(controller.connection?['connected'], true);
      expect(controller.awaitingMailCallback, false);
    },
  );
  test('only exact mail deep links become navigation hints, never OAuth sessions', () {
    expect(
      MailCallbackResult.parse(
        Uri.parse('io.ruamport.mobile://mail/return?mailConnection=connected'),
      )?.errorCode,
      isNull,
    );
    expect(
      MailCallbackResult.parse(
        Uri.parse('io.ruamport.mobile://mail/return?mailConnection=connected'),
      ),
      isNotNull,
    );
    expect(
      MailCallbackResult.parse(
        Uri.parse(
          'io.ruamport.mobile://mail/return?mailConnection=error&code=MAIL_CONSENT_DENIED',
        ),
      )?.errorCode,
      'MAIL_CONSENT_DENIED',
    );
    for (final link in [
      'io.ruamport.mobile://auth/callback?code=oauth-code',
      'https://mail/return?mailConnection=connected',
      'io.ruamport.mobile://evil/return?mailConnection=connected',
      'io.ruamport.mobile://mail/other?mailConnection=connected',
      'io.ruamport.mobile://mail/return?mailConnection=connected&code=secret',
      'io.ruamport.mobile://mail/return?mailConnection=connected&access_token=secret',
      'io.ruamport.mobile://mail/return?mailConnection=connected&mailConnection=error',
      'io.ruamport.mobile://mail/return?mailConnection=error&code=arbitrary-token',
      'io.ruamport.mobile://mail/return?mailConnection=connected#access_token=secret',
    ]) {
      expect(MailCallbackResult.parse(Uri.parse(link)), isNull, reason: link);
    }
  });

  test(
    'inbox retains a cold callback until a screen is ready and consumes once',
    () {
      final inbox = MailCallbackInbox();
      addTearDown(inbox.dispose);
      var notifications = 0;
      inbox.addListener(() => notifications++);
      inbox.accept(
        Uri.parse('io.ruamport.mobile://auth/callback?code=oauth-code'),
      );
      expect(inbox.take(), isNull);
      expect(notifications, 0);
      inbox.accept(
        Uri.parse(
          'io.ruamport.mobile://mail/return?mailConnection=error&code=MAIL_CONSENT_DENIED',
        ),
      );
      expect(notifications, 1);
      expect(inbox.take()?.errorCode, 'MAIL_CONSENT_DENIED');
      expect(inbox.take(), isNull);
    },
  );

  test(
    'native connect declares mobile; a success link cannot fake a connected mailbox',
    () async {
      final requests = <http.Request>[];
      final api = ImportApi(
        tokenProvider: () async => 'token',
        checkReadiness: false,
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/connect')) {
            expect(jsonDecode(request.body), {'client': 'mobile'});
            expect(request.headers['Authorization'], 'Bearer token');
            return http.Response(
              jsonEncode({
                'authorizationUrl':
                    'https://accounts.google.com/o/oauth2/v2/auth',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'supported': true,
              'connected': false,
              'connection': null,
            }),
            200,
          );
        }),
        apiUrl: 'http://localhost:3000/api/v1',
      );
      final controller = ImportController(api, mail: true);
      addTearDown(controller.dispose);
      await controller.loadConnection();
      await controller.connect();
      await controller.resumeMailAuthorization(fromCallback: true);
      expect(controller.connection?['connected'], false);
      expect(controller.awaitingMailCallback, false);
      expect(
        requests.where((r) => r.url.path.endsWith('/connection')).length,
        2,
      );
      await controller.resumeMailAuthorization(
        fromCallback: true,
        callbackCode: 'MAIL_CONSENT_DENIED',
      );
      expect(controller.error, importMessage('MAIL_CONSENT_DENIED'));
      expect(controller.connection?['connected'], false);
    },
  );
}
