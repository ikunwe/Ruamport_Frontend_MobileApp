import 'package:flutter_test/flutter_test.dart';
import 'package:project_portfoliomanagement_mobile/features/portfolio/market_comparison.dart';
import 'package:project_portfoliomanagement_mobile/features/portfolio/portfolio_data.dart';
import 'fixtures/holdings_fixture.dart';

void main() {
  test(
    'shows five daily markets and portfolio daily change, not investment return',
    () {
      final rows = marketComparisonRows(HoldingsData(holdingsFixture()), {
        'items': [
          for (final id in overviewMarkets.keys)
            {
              'id': id,
              'status': 'AVAILABLE',
              'value': 102,
              'previousClose': 100,
              'changePercent': 2,
            },
        ],
      });
      expect(rows.map((row) => row.$1), [
        'Your port',
        'S&P 500',
        'NASDAQ',
        'Dow Jones',
        'SET Index',
        'SET50 Index',
      ]);
      expect(rows.first.$2, 1);
      expect(rows.skip(1).map((row) => row.$2), everyElement(2));
    },
  );

  test('missing markets remain visible as unknown instead of zero', () {
    final rows = marketComparisonRows(null, {
      'items': [
        {'id': 'SP500', 'status': 'UNAVAILABLE', 'changePercent': 0},
        {
          'id': 'SET',
          'status': 'AVAILABLE',
          'value': 100,
          'previousClose': null,
          'changePercent': 2,
        },
      ],
    });
    expect(rows.length, 6);
    expect(rows.map((row) => row.$2), everyElement(isNull));
    expect(comparisonWidth(null, [null]), 0);
    expect(comparisonWidth(2, [2, -4]), .4);
    expect(comparisonWidth(-4, [2, -4]), .8);
  });

  test('unverified SET and AMC logo URLs remain usable', () {
    for (final url in [
      'https://media.set.or.th/common/logo/company/ASK.png',
      'https://img.logo.dev/am.kkpfg.com?token=pk_test',
    ]) {
      expect(
        Holding({
          'logoUrl': url,
          'logo': {'status': 'UNVERIFIED', 'verified': false},
        }).logoUrl,
        url,
      );
      expect(
        Holding({
          'logo': {'url': url, 'status': 'UNVERIFIED', 'verified': false},
        }).logoUrl,
        url,
      );
    }
    expect(
      const Holding({
        'logo': {'status': 'UNAVAILABLE'},
      }).logoUrl,
      isNull,
    );
  });
}
