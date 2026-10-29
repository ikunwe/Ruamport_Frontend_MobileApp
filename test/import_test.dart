import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_portfoliomanagement_mobile/core/theme/app_theme.dart';
import 'package:project_portfoliomanagement_mobile/features/import/import_api.dart';
import 'package:project_portfoliomanagement_mobile/features/import/import_controller.dart';
import 'package:project_portfoliomanagement_mobile/features/import/import_models.dart';
import 'package:project_portfoliomanagement_mobile/features/import/investment_import_sheet.dart';
import 'package:project_portfoliomanagement_mobile/features/import/pdf_preview_view.dart';

Map<String, dynamic> previewJson({
  String id = 'doc-1',
  String type = 'DIME_OFFSHORE_CONFIRMATION_NOTE',
}) => {
  'record': {'id': id, 'status': 'PREVIEW', 'canImport': true, 'orderCount': 1},
  'file': {'name': 'confirmation.pdf', 'size': 100, 'pageCount': 1},
  'document': {'type': type, 'documentNumber': 'PDF-123'},
  'orders': [
    {
      'orderId': 'ORDER-1',
      'symbol': 'NVDA',
      'fundName': 'KKP US500',
      'tradeDate': '2026-10-01',
      'transactionType': 'BUY',
      'units': 2.5,
      'unitPrice': 100,
      'navPerUnit': 12.3456,
      'pricePerShare': 30,
      'currency': type.contains('OFFSHORE') ? 'USD' : 'THB',
      'grossAmount': {'foreign': 250, 'thb': 8000},
      'feeIncludeVat': {'foreign': 1, 'thb': 32},
      'totalAmount': {'foreign': 251, 'thb': 8032},
    },
  ],
  'display': {
    'totalBuy': 8000,
    'totalSell': 0,
    'totalFeeIncludeVatAfterDiscount': 32,
    'totalFeesAndTaxes': 32,
  },
  'summary': {'totalBuy': 77777, 'totalSubscription': 500},
  'calculation': {'totalFeesAndTaxes': 99999},
  'validation': {
    'isValid': false,
    'blocksImport': false,
    'warnings': [
      {
        'code': 'TOTAL_BUY_MISMATCH',
        'calculatedValue': 7999,
        'pdfValue': 8000,
        'currency': 'THB',
        'blocking': false,
      },
    ],
  },
  'diagnostics': {
    'validation': {
      'warnings': [
        {'message': 'internal diagnostic must stay hidden'},
      ],
    },
  },
};
Map<String, dynamic> mailFile(
  String status,
  String id, {
  Map<String, dynamic>? preview,
}) => {
  'status': status,
  'source': {
    'messageId': id,
    'attachmentId': 'attachment',
    'filename': '$id.pdf',
  },
  'record': {
    'id': id,
    'status': status == 'ALREADY_IMPORTED' ? 'IMPORTED' : 'PREVIEW',
    'canImport': status != 'ALREADY_IMPORTED',
  },
  'preview': ?preview,
};
Map<String, dynamic> batch({
  List<Map<String, dynamic>> results = const [],
  bool more = false,
  String? next,
  String retry = 'retry-1',
  int found = 1,
}) => {
  'months': 'all',
  'results': results,
  'hasMore': more,
  'nextCursor': next,
  'retryCursor': retry,
  'progress': {'foundPdfCount': found, 'readyPdfCount': 1},
};
http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);
ImportApi apiFor(
  Future<http.Response> Function(http.Request) handler, {
  Future<void> Function()? unauthorized,
}) => ImportApi(
  checkReadiness: false,
  tokenProvider: () async => 'access-token',
  onUnauthorized: unauthorized,
  client: MockClient(handler),
  apiUrl: 'http://localhost:3000/api/v1',
);
final file = SelectedPdf(
  name: 'confirmation.pdf',
  bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 test fixture')),
);
const connected = {
  'supported': true,
  'connected': true,
  'connection': {'email': 'test@gmail.com'},
};

void main() {
  test(
    'returning from Google without consent stops pending state and permits a new connect',
    () async {
      var requests = 0;
      final controller = ImportController(
        apiFor((request) async {
          if (request.url.path.endsWith('/connect')) {
            requests++;
            return jsonResponse({
              'authorizationUrl':
                  'https://accounts.google.com/o/oauth2/v2/auth',
            });
          }
          return jsonResponse({
            'supported': true,
            'connected': false,
            'connection': null,
          });
        }),
        mail: true,
      );
      addTearDown(controller.dispose);
      await controller.loadConnection();
      await controller.connect();
      expect(controller.awaitingMailCallback, isTrue);
      await controller.resumeMailAuthorization();
      expect(controller.awaitingMailCallback, isFalse);
      expect(controller.connection?['connected'], isFalse);
      expect(controller.loadingConnection, isFalse);
      expect(await controller.connect(), isNotNull);
      expect(requests, 2);
    },
  );

  test(
    'failed status check on return also releases the connect button and preserves the error',
    () async {
      var fail = false;
      final controller = ImportController(
        apiFor((request) async {
          if (request.url.path.endsWith('/connect')) {
            return jsonResponse({
              'authorizationUrl':
                  'https://accounts.google.com/o/oauth2/v2/auth',
            });
          }
          if (fail) throw http.ClientException('network');
          return jsonResponse({
            'supported': true,
            'connected': false,
            'connection': null,
          });
        }),
        mail: true,
      );
      addTearDown(controller.dispose);
      await controller.loadConnection();
      await controller.connect();
      fail = true;
      await controller.resumeMailAuthorization();
      expect(controller.awaitingMailCallback, isFalse);
      expect(controller.loadingConnection, isFalse);
      expect(controller.error, importMessage('NETWORK'));
    },
  );
  test(
    'mail connect stays pending until callback and prevents duplicate authorization requests',
    () async {
      var requests = 0, linked = false;
      final controller = ImportController(
        apiFor((request) async {
          if (request.url.path.endsWith('/connect')) {
            requests++;
            return jsonResponse({
              'authorizationUrl':
                  'https://accounts.google.com/o/oauth2/v2/auth?state=test',
            });
          }
          return jsonResponse({
            'supported': true,
            'connected': linked,
            'connection': null,
          });
        }),
        mail: true,
      );
      addTearDown(controller.dispose);
      await controller.loadConnection();
      expect(await controller.connect(), isNotNull);
      expect(controller.awaitingMailCallback, isTrue);
      expect(controller.busy, isFalse);
      expect(await controller.connect(), isNull);
      expect(requests, 1);
      linked = true;
      await controller.loadConnection();
      expect(controller.awaitingMailCallback, isFalse);
    },
  );

  test(
    'failed launcher or error callback stops the mail connection spinner and permits retry',
    () async {
      final controller = ImportController(
        apiFor(
          (request) async => request.url.path.endsWith('/connect')
              ? jsonResponse({
                  'authorizationUrl':
                      'https://accounts.google.com/o/oauth2/v2/auth',
                })
              : jsonResponse({
                  'supported': true,
                  'connected': false,
                  'connection': null,
                }),
        ),
        mail: true,
      );
      addTearDown(controller.dispose);
      await controller.loadConnection();
      await controller.connect();
      controller.connectionLaunchFailed(const ImportFailure('NETWORK'));
      expect(controller.awaitingMailCallback, isFalse);
      expect(controller.error, importMessage('NETWORK'));
      await controller.connect();
      expect(controller.awaitingMailCallback, isTrue);
      await controller.loadConnection(callbackCode: 'MAIL_CONSENT_DENIED');
      expect(controller.awaitingMailCallback, isFalse);
      expect(controller.error, importMessage('MAIL_CONSENT_DENIED'));
    },
  );
  for (final type in [
    'DIME_THAI_STOCK_CONFIRMATION_NOTE',
    'DIME_MUTUAL_FUND_CONFIRMATION_NOTE',
  ]) {
    testWidgets('preview uses native THB fields for $type', (tester) async {
      final data = previewJson(type: type);
      final order = objectList(data['orders']).single;
      order['currency'] = 'THB';
      order['totalAmount'] = 500;
      order['feeIncludeVat'] = 2;
      final preview = PdfPreview(data);
      await tester.pumpWidget(
        MaterialApp(
          theme: createAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PdfPreviewView(preview: preview, record: preview.record),
            ),
          ),
        ),
      );
      expect(
        find.text(preview.fund ? '12.3456 THB' : '30.0000 THB'),
        findsOneWidget,
      );
      expect(find.text('500.00 THB'), findsWidgets);
      expect(find.text('99,999.00 THB'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'unsupported mailbox offers no Gmail connect or Outlook selector',
    (tester) async {
      final api = apiFor(
        (_) async => jsonResponse({'supported': false, 'connected': false}),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: createAppTheme(),
          home: Scaffold(body: InvestmentImportSheet(mail: true, api: api)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('เชื่อมต่อ Gmail'), findsNothing);
      expect(find.text('Outlook'), findsNothing);
      expect(
        find.text(importMessage('MAIL_PROVIDER_UNSUPPORTED')),
        findsOneWidget,
      );
    },
  );

  test(
    'uploads a multipart PDF with Bearer token and password, never JSON orders',
    () async {
      final api = apiFor((request) async {
        expect(request.url.path, '/api/v1/trades/upload-preview');
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer access-token');
        expect(
          request.headers['content-type'],
          contains('multipart/form-data; boundary='),
        );
        expect(request.body, contains('filename="confirmation.pdf"'));
        expect(
          request.body.toLowerCase(),
          contains('content-type: application/pdf'),
        );
        expect(request.body, contains('name="pdfPassword"'));
        expect(request.body, contains('01012000'));
        expect(request.body, isNot(contains('documentIds')));
        return jsonResponse(previewJson());
      });
      addTearDown(api.dispose);
      final preview = await api.upload(file, '01012000');
      expect(preview.record.canImport, isTrue);
      expect(preview.totals['totalFeesAndTaxes'], 32);
    },
  );

  test('Gmail reconnect 401 does not sign out the Ruamport account', () async {
    var logouts = 0;
    final api = apiFor(
      (_) async => jsonResponse({
        'error': {'code': 'MAIL_RECONNECT_REQUIRED'},
      }, 401),
      unauthorized: () async {
        logouts++;
      },
    );
    addTearDown(api.dispose);
    await expectLater(
      api.sync('all', 'password'),
      throwsA(isA<ImportFailure>()),
    );
    expect(logouts, 0);
  });

  test(
    'automatic sync continues empty batches and old previews are metadata only',
    () async {
      final cursors = <Object?>[];
      final api = apiFor((request) async {
        if (request.url.path.endsWith('/connection')) {
          return jsonResponse(connected);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        cursors.add(body['cursor']);
        expect(body['pdfPassword'], 'password');
        return jsonResponse(
          cursors.length == 1
              ? batch(more: true, next: 'opaque-next')
              : batch(
                  found: 12,
                  results: [
                    mailFile('READY', 'new', preview: previewJson()),
                    mailFile(
                      'ALREADY_READ',
                      'old',
                      preview: previewJson(id: 'old'),
                    ),
                  ],
                ),
        );
      });
      final c = ImportController(api, mail: true);
      addTearDown(c.dispose);
      await c.loadConnection();
      await c.sync('password');
      expect(cursors, [null, 'opaque-next']);
      expect(c.batches.length, 2);
      expect(c.progress['foundPdfCount'], 12); // ไม่บวกยอดสะสมซ้ำ
      expect(c.batches.last.files.last.preview, isNull);
      expect(c.importableIds.toSet(), {'new', 'old'});
      expect(c.busy, isFalse);
      expect(c.scanning, isFalse);
    },
  );

  test('stopping keeps the current batch but sends no next request', () async {
    final pending = Completer<http.Response>();
    final requested = Completer<void>();
    var calls = 0;
    final c = ImportController(
      apiFor((request) async {
        if (request.url.path.endsWith('/connection')) {
          return jsonResponse(connected);
        }
        calls++;
        requested.complete();
        return pending.future;
      }),
      mail: true,
    );
    addTearDown(c.dispose);
    await c.loadConnection();
    final syncing = c.sync('password');
    await requested.future;
    c.stop();
    pending.complete(jsonResponse(batch(more: true, next: 'next')));
    await syncing;
    expect(calls, 1);
    expect(c.stopped, isTrue);
    expect(c.batches.length, 1);
  });

  test(
    'retry replaces the selected batch, retains unlocked PDFs and keeps latest progress',
    () async {
      var calls = 0;
      final c = ImportController(
        apiFor((request) async {
          if (request.url.path.endsWith('/connection')) {
            return jsonResponse(connected);
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          calls++;
          if (calls == 1) {
            return jsonResponse(
              batch(
                more: true,
                next: 'next',
                retry: 'retry-first',
                results: [
                  mailFile('READY', 'a', preview: previewJson()),
                  mailFile('PASSWORD_INVALID', 'b'),
                ],
              ),
            );
          }
          if (calls == 2) return jsonResponse(batch(found: 20));
          expect(body['cursor'], 'retry-first');
          expect(body['pdfPassword'], 'other-password');
          return jsonResponse(
            batch(
              found: 2,
              results: [
                mailFile('PASSWORD_INVALID', 'a'),
                mailFile('READY', 'b', preview: previewJson(id: 'b')),
              ],
            ),
          );
        }),
        mail: true,
      );
      addTearDown(c.dispose);
      await c.loadConnection();
      await c.sync('password');
      await c.sync('other-password', retryIndex: 0);
      expect(c.batches.length, 2);
      expect(c.batches.first.files.map((f) => f.status), ['READY', 'READY']);
      expect(c.progress['foundPdfCount'], 20);
      expect(calls, 3);
    },
  );

  test(
    'new sync clears previous previews and fetches old documents only on explicit view',
    () async {
      var syncs = 0, documents = 0;
      final c = ImportController(
        apiFor((request) async {
          if (request.url.path.endsWith('/connection')) {
            return jsonResponse(connected);
          }
          if (request.url.path.contains('/documents/')) {
            documents++;
            return jsonResponse(previewJson(id: 'old'));
          }
          syncs++;
          return jsonResponse(
            batch(
              results: [
                syncs == 1
                    ? mailFile('READY', 'new', preview: previewJson())
                    : mailFile('ALREADY_READ', 'old'),
              ],
            ),
          );
        }),
        mail: true,
      );
      addTearDown(c.dispose);
      await c.loadConnection();
      await c.sync('password');
      await c.sync('password');
      expect(documents, 0);
      expect(c.batches.single.files.single.old, isTrue);
      expect(c.preview, isNull);
      await c.view(c.batches.single.files.single);
      expect(documents, 1);
      expect(c.preview?.record.id, 'old');
    },
  );

  test(
    'save sends only unique IDs in groups of 50 and handles per-document outcomes',
    () async {
      final groups = <List<dynamic>>[];
      final c = ImportController(
        apiFor((request) async {
          expect(request.url.path, '/api/v1/trades/import');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.keys, ['documentIds']);
          final ids = body['documentIds'] as List<dynamic>;
          groups.add(ids);
          return jsonResponse({
            'results': ids
                .map(
                  (id) => {
                    'documentId': id,
                    'outcome': id == 'doc-50'
                        ? 'ORDER_ID_CONFLICT'
                        : 'IMPORTED',
                  },
                )
                .toList(),
          });
        }),
        mail: true,
      );
      addTearDown(c.dispose);
      c.batches.add(
        MailBatch.fromJson(
          batch(
            results: List.generate(
              51,
              (i) => mailFile('ALREADY_READ', 'doc-$i'),
            ),
          ),
        ),
      );
      await c.save();
      expect(groups.map((g) => g.length), [50, 1]);
      expect(c.importResults.length, 51);
      expect(c.importableIds, ['doc-50']);
      expect(c.busy, isFalse);
    },
  );

  for (final width in [320.0, 390.0]) {
    testWidgets('real PDF preview and explicit save fit $width pixels', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var saves = 0;
      final api = apiFor((request) async {
        if (request.url.path.endsWith('/import')) {
          saves++;
          return jsonResponse({
            'results': [
              {
                'documentId': 'doc-1',
                'outcome': 'IMPORTED',
                'transactionCount': 1,
              },
            ],
          });
        }
        return jsonResponse(previewJson());
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: createAppTheme(),
          home: Scaffold(
            body: InvestmentImportSheet(
              mail: false,
              api: api,
              pickPdf: () async => file,
            ),
          ),
        ),
      );
      await tester.tap(find.text('เลือกไฟล์ PDF'));
      await tester.pumpAndSettle();
      final read = find.widgetWithText(FilledButton, 'อ่าน Preview');
      await tester.ensureVisible(read);
      await tester.tap(read);
      await tester.pumpAndSettle();
      expect(find.text('NVDA'), findsOneWidget);
      expect(find.text('internal diagnostic must stay hidden'), findsNothing);
      expect(find.text('99,999.00 THB'), findsNothing);
      expect(saves, 0);
      final save = find.widgetWithText(
        FilledButton,
        'บันทึกเอกสารนี้เข้าพอร์ต',
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(saves, 1);
      expect(find.text('บันทึกไว้แล้ว'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'sync button needs a PDF password and clears it after submitting',
    (tester) async {
      var calls = 0;
      final api = apiFor((request) async {
        if (request.url.path.endsWith('/connection')) {
          return jsonResponse(connected);
        }
        calls++;
        return jsonResponse({...batch(), 'noNewData': true});
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: createAppTheme(),
          home: Scaffold(body: InvestmentImportSheet(mail: true, api: api)),
        ),
      );
      await tester.pumpAndSettle();
      final sync = find.widgetWithText(FilledButton, 'ซิงค์ข้อมูล');
      expect(tester.widget<FilledButton>(sync).onPressed, isNull);
      await tester.enterText(find.byType(TextField), 'password');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(sync).onPressed, isNotNull);
      await tester.ensureVisible(sync);
      await tester.tap(sync);
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('ไม่พบ Confirmation ใหม่'), findsOneWidget);
    },
  );

  testWidgets(
    'missing offshore display stays unknown and public warnings do not block saving',
    (tester) async {
      final data = previewJson()..['display'] = null;
      final preview = PdfPreview(data);
      await tester.pumpWidget(
        MaterialApp(
          theme: createAppTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PdfPreviewView(preview: preview, record: preview.record),
            ),
          ),
        ),
      );
      expect(find.text('77,777.00 THB'), findsNothing);
      expect(find.text('99,999.00 THB'), findsNothing);
      expect(preview.blocksImport, isFalse);
      expect(preview.record.canImport, isTrue);
      expect(pdfMoney(null, 'THB'), '—');
    },
  );
}
