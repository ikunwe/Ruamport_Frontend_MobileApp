import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:project_portfoliomanagement_mobile/core/theme/app_theme.dart';
import 'package:project_portfoliomanagement_mobile/features/import/import_api.dart';
import 'package:project_portfoliomanagement_mobile/features/portfolio/portfolio_data.dart';
import 'package:project_portfoliomanagement_mobile/features/portfolio/portfolio_store.dart';
import 'package:project_portfoliomanagement_mobile/features/portfolio/live_portfolio_page.dart';
import 'package:project_portfoliomanagement_mobile/features/portfolio/live_stock_page.dart';
import 'package:project_portfoliomanagement_mobile/features/dashboard/live_overview_page.dart';
import 'package:project_portfoliomanagement_mobile/features/analytics/live_analytics_page.dart';
import 'package:project_portfoliomanagement_mobile/features/simulator/live_simulator_page.dart';
import 'fixtures/holdings_fixture.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Kanit');
    for (final font in [
      'Kanit-Regular.ttf',
      'Kanit-SemiBold.ttf',
      'Kanit-Bold.ttf',
    ]) {
      fonts.addFont(rootBundle.load('assets/fonts/$font'));
    }
    await fonts.load();
  });
  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets(
      'real data pages, currency, history and server sale at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var saleCalls = 0;
        final store = PortfolioStore(
          ImportApi(
            tokenProvider: () async => 'test-token',
            client: MockClient((request) async {
              final q = request.url.queryParameters;
              Object result;
              if (request.url.path.endsWith('/portfolio-history')) {
                result = {
                  'range': q['range'],
                  'currency': 'THB',
                  'status': 'COMPLETE',
                  'points': [
                    {'date': '2026-10-01', 'marketValue': 9000},
                    {'date': '2026-10-28', 'marketValue': 10150},
                  ],
                };
              } else if (request.url.path.endsWith('/market-indices')) {
                result = {
                  'items': [
                    for (final id in [
                      'SP500',
                      'NASDAQ_COMPOSITE',
                      'DOW_JONES',
                      'SET',
                      'SET50',
                    ])
                      {
                        'id': id,
                        'status': 'AVAILABLE',
                        'value': 102,
                        'previousClose': 100,
                        'changePercent': 2,
                      },
                  ],
                };
              } else if (request.url.path.endsWith('/performance')) {
                result = {
                  'calculationVersion': 2,
                  'category': q['category'],
                  'range': q['range'],
                  'comparisonCurrency': 'THB',
                  'comparable': true,
                  'portfolio': {'cumulativeReturnPercent': 12},
                  'benchmark': {
                    'id': q['benchmarkId'],
                    'cumulativeReturnPercent': 9,
                  },
                  'points': [
                    {
                      'date': '2026-10-01',
                      'portfolioReturnPercent': 0,
                      'benchmarkReturnPercent': 0,
                    },
                    {
                      'date': '2026-10-28',
                      'portfolioReturnPercent': 12,
                      'benchmarkReturnPercent': 9,
                    },
                  ],
                };
              } else if (request.url.path.endsWith('/win-rate')) {
                result = {
                  'calculationVersion': 2,
                  'category': q['category'],
                  'range': q['range'],
                  'unit': q['unit'],
                  'markets': [
                    {
                      'id': 'SP500',
                      'winRatePercent': 75,
                      'periods': [
                        {
                          'startDate': '2026-10-01',
                          'endDate': '2026-10-28',
                          'outcome': 'WIN',
                          'portfolioReturnPercent': 12,
                          'benchmarkReturnPercent': 9,
                        },
                      ],
                    },
                  ],
                };
              } else if (request.url.path.endsWith('/documents')) {
                result = {
                  'items': [
                    {
                      'id': 'doc',
                      'status': 'IMPORTED',
                      'document': {
                        'type': 'DIME_OFFSHORE_CONFIRMATION_NOTE',
                        'accountNumber': 'account-A',
                      },
                    },
                  ],
                  'hasMore': false,
                };
              } else if (request.url.path.endsWith('/transactions')) {
                result = {
                  'items': [
                    {
                      'id': 'trade',
                      'document_id': 'doc',
                      'transaction_type': 'BUY',
                      'asset_name': 'NVDA',
                      'currency': 'USD',
                      'units': 2,
                      'unit_price': 100,
                      'trade_date': '2026-10-01',
                      'details': {
                        'exchange': 'XNAS',
                        'totalAmount': {'foreign': 202, 'thb': 6464},
                      },
                    },
                  ],
                  'hasMore': false,
                };
              } else if (request.url.path.endsWith('/simulate-sale')) {
                final input = jsonDecode(request.body) as Map<String, dynamic>;
                saleCalls++;
                expect(input['currency'], 'USD');
                expect(
                  input['tradeDate'],
                  DateTime.now()
                      .toUtc()
                      .add(const Duration(hours: 7))
                      .toIso8601String()
                      .substring(0, 10),
                );
                result = {
                  ...input,
                  'simulationVersion': 1,
                  'persisted': false,
                  'status': 'CALCULATED',
                  'isComplete': true,
                  'method': 'COMPRESSED_FIFO',
                  'feesIncluded': false,
                  'taxesIncluded': false,
                  'fxIncluded': false,
                  'before': {
                    'quantity': 2,
                    'remainingCost': 200,
                    'averageCostPerUnit': 100,
                  },
                  'after': {
                    'quantity': 1,
                    'remainingCost': 90,
                    'averageCostPerUnit': 90,
                  },
                  'realizedPnl': 10,
                  'realizedPnlPercent': 9.0909,
                  'snapshot': {
                    'revision': 'sim-v1:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                  },
                };
              } else {
                throw StateError('Unexpected request: ${request.url.path}');
              }
              return http.Response(
                jsonEncode(result),
                200,
                headers: {'content-type': 'application/json'},
              );
            }),
          ),
        )..data = HoldingsData(holdingsFixture());
        addTearDown(store.dispose);
        int selected = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: createAppTheme(),
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                bottomNavigationBar: NavigationBar(
                  selectedIndex: selected,
                  onDestinationSelected: (value) =>
                      setState(() => selected = value),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home),
                      label: 'Overview',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.work),
                      label: 'Portfolio',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.insights),
                      label: 'Analytics',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calculate),
                      label: 'Simulator',
                    ),
                  ],
                ),
                body: IndexedStack(
                  index: selected,
                  children: [
                    LiveOverviewPage(
                      store: store,
                      name: 'Real account',
                      onImport: () {},
                      onAnalytics: () => setState(() => selected = 2),
                      onAsset: (asset) => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              LiveStockPage(store: store, asset: asset),
                        ),
                      ),
                    ),
                    LivePortfolioPage(
                      store: store,
                      onAsset: (asset) => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              LiveStockPage(store: store, asset: asset),
                        ),
                      ),
                    ),
                    LiveAnalyticsPage(store: store, active: selected == 2),
                    LiveSimulatorPage(store: store),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('10,150.00 THB'), findsOneWidget);
        expect(tester.takeException(), isNull);
        Future<void> tab(String label) async {
          await tester.tap(
            find.descendant(
              of: find.byType(NavigationBar),
              matching: find.text(label),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await tab('Portfolio');
        final thb = find.descendant(
          of: find.byType(LivePortfolioPage),
          matching: find.text('THB'),
        );
        await tester.ensureVisible(thb);
        await tester.tap(thb);
        await tester.pumpAndSettle();
        expect(store.thb, isTrue);
        final stock = find.descendant(
          of: find.byType(LivePortfolioPage),
          matching: find.text('NVDA'),
        );
        await tester.ensureVisible(stock);
        await tester.tap(stock);
        await tester.pumpAndSettle();
        expect(find.byType(LiveStockPage), findsOneWidget);
        expect(find.text('ต้นทุนต่อหุ้น 3,500.00 THB'), findsOneWidget);
        expect(
          find.text('202.00 USD'),
          findsOneWidget,
        ); // ประวัติไม่เปลี่ยนเป็น current FX
        Navigator.of(tester.element(find.byType(LiveStockPage))).pop();
        await tester.pumpAndSettle();
        await tab('Analytics');
        expect(find.text('+75.00%'), findsOneWidget);
        await tab('Simulator');
        final fields = find.descendant(
          of: find.byType(LiveSimulatorPage),
          matching: find.byType(TextField),
        );
        await tester.enterText(fields.at(1), '1');
        await tester.pumpAndSettle();
        final calculate = find.widgetWithText(FilledButton, 'คำนวณผลจำลอง');
        await tester.ensureVisible(calculate);
        await tester.tap(calculate);
        await tester.pumpAndSettle();
        expect(find.text('106.67 USD'), findsOneWidget);
        final sell = find.descendant(
          of: find.byType(LiveSimulatorPage),
          matching: find.text('ขาย'),
        );
        await tester.ensureVisible(sell);
        await tester.tap(sell);
        await tester.pumpAndSettle();
        await tester.ensureVisible(calculate);
        await tester.tap(calculate);
        await tester.pumpAndSettle();
        expect(saleCalls, 1);
        expect(
          find.text('90.00 USD'),
          findsNWidgets(2),
        ); // ใช้ cost ที่ Backend ส่ง ไม่ขายด้วย average cost ฝั่ง Flutter
        expect(store.data!.items.first.quantity, 2);
        expect(store.data!.items.first.cost('USD'), 200);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
