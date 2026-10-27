import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_portfoliomanagement_mobile/features/import/import_api.dart';
import 'package:project_portfoliomanagement_mobile/features/portfolio/portfolio_data.dart';
import 'package:project_portfoliomanagement_mobile/features/portfolio/portfolio_store.dart';
import 'fixtures/holdings_fixture.dart';

http.Response response(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);
PortfolioStore storeFor(Future<http.Response> Function(http.Request) handler) =>
    PortfolioStore(
      ImportApi(
        tokenProvider: () async => 'token',
        client: MockClient(handler),
        apiUrl: 'http://localhost:3000/api/v1',
      ),
    )..active(false);

void main() {
  test(
    'uses document cost, current market value, price profit and FX once each',
    () {
      final data = HoldingsData(holdingsFixture());
      expect(data.historicalCost, 7900);
      expect(data.value, 10150);
      expect(data.assetProfit, 1650);
      expect(data.fxProfit, 600);
      expect(data.unrealized, 2250);
      expect(data.realized, 300);
      expect(data.totalProfit, 2550);
      expect(data.totalProfitPercent, closeTo(2550 / 9900 * 100, 1e-8));
      expect(data.averageFx, 32);
      expect(data.categoryTotal('OFFSHORE_STOCK', 'THB', 'buy'), 7360);
      expect(data.categoryTotal('OFFSHORE_STOCK', 'THB', 'fees'), 10);
    },
  );
  test(
    'missing values stay unknown and missing THB realized is not converted from USD',
    () {
      final json = holdingsFixture();
      json['realizedPnlTotals'] = [
        {'currency': 'USD', 'realizedPnl': 123, 'isComplete': true},
      ];
      (json['fx'] as Map)['status'] = 'UNAVAILABLE';
      final data = HoldingsData(json);
      expect(data.rate, isNull);
      expect(data.realized, isNull);
      expect(data.value, isNull);
      expect(data.fxProfit, isNull);
      expect(data.totalProfit, isNull);
      expect(data.items.first.cost('THB'), 6400);
      expect(sumMoney([1, null]), isNull);
      expect(convertMoney(1.005, 1), 1.01);
      expect(convertMoney(-1.005, 1), -1.01);
    },
  );
  test(
    'incomplete cost and fees cannot become zero, even with known quantity',
    () {
      final json = holdingFixture();
      (json['costBasis'] as List).first['status'] = 'INCOMPLETE';
      (json['amounts'] as List).first['feeIsComplete'] = false;
      final holding = Holding(json);
      expect(holding.quantity, 2);
      expect(holding.cost('USD'), isNull);
      expect(holding.fees('USD'), isNull);
    },
  );
  test(
    'history joins full identity, keeps native amounts, and excludes duplicate rows',
    () async {
      final store = storeFor((request) async {
        if (request.url.path.endsWith('/documents')) {
          return response({
            'items': [
              {
                'id': 'doc-a',
                'status': 'IMPORTED',
                'document': {
                  'type': 'DIME_OFFSHORE_CONFIRMATION_NOTE',
                  'accountNumber': 'account-A',
                },
              },
              {
                'id': 'doc-b',
                'status': 'IMPORTED',
                'document': {
                  'type': 'DIME_OFFSHORE_CONFIRMATION_NOTE',
                  'accountNumber': 'account-B',
                },
              },
            ],
            'hasMore': false,
          });
        }
        Map<String, dynamic> row(
          String id,
          String doc, {
          bool duplicate = false,
        }) => {
          'id': id,
          'document_id': doc,
          'asset_name': 'NVDA',
          'currency': 'USD',
          'trade_date': '2026-10-01',
          'is_duplicate': duplicate,
          'details': {
            'exchange': 'XNAS',
            'totalAmount': {'foreign': 100, 'thb': 3200},
          },
        };
        return response({
          'items': [
            row('trade-a', 'doc-a'),
            row('trade-b', 'doc-b'),
            row('duplicate', 'doc-a', duplicate: true),
          ],
          'hasMore': false,
        });
      });
      addTearDown(store.dispose);
      final rows = await store.transactions(Holding(holdingFixture()));
      expect(rows.map((row) => row['id']), ['trade-a']);
      expect((rows.single['details'] as Map)['totalAmount'], {
        'foreign': 100,
        'thb': 3200,
      });
    },
  );
  test('requests share an in-flight future and memory cache', () async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final store = storeFor((_) async {
      calls++;
      return pending.future;
    });
    addTearDown(store.dispose);
    final a = store.request('/trades/portfolio-history?range=ALL');
    final b = store.request('/trades/portfolio-history?range=ALL');
    expect(identical(a, b), isTrue);
    pending.complete(response({'points': [], 'range': 'ALL'}));
    await Future.wait([a, b]);
    await store.request('/trades/portfolio-history?range=ALL');
    expect(calls, 1);
  });
  test(
    'quote refresh preserves chart cache, changed investment data invalidates it',
    () async {
      var histories = 0;
      final data = holdingsFixture();
      final store = storeFor((request) async {
        if (request.url.path.endsWith('/holdings')) return response(data);
        histories++;
        return response({'range': 'ALL', 'points': []});
      });
      addTearDown(store.dispose);
      await store.refresh();
      await store.request('/trades/portfolio-history?range=ALL');
      await store.refresh();
      await store.request('/trades/portfolio-history?range=ALL');
      expect(histories, 1);
      (data['items'] as List).first['quantity'] = 3;
      await store.refresh();
      await store.request('/trades/portfolio-history?range=ALL');
      expect(histories, 2);
    },
  );
}
