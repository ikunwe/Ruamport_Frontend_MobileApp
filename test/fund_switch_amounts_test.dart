import 'package:flutter_test/flutter_test.dart';
import 'package:project_portfoliomanagement_mobile/features/portfolio/portfolio_data.dart';

void main() {
  test(
    'fund switching uses the original THB amounts without converting USD',
    () {
      const fund = Holding({
        'assetType': 'MUTUAL_FUND',
        'amounts': [
          {'currency': 'USD', 'totalSwitchIn': 999, 'totalSwitchOut': 888},
          {
            'currency': 'THB',
            'totalSwitchIn': 300.25,
            'totalSwitchOut': 100.50,
          },
        ],
      });
      expect(fund.fundSwitchIn, 300.25);
      expect(fund.fundSwitchOut, 100.50);
    },
  );
  test('missing amount stays unknown while actual zero is preserved', () {
    const fund = Holding({
      'assetType': 'MUTUAL_FUND',
      'amounts': [
        {'currency': 'THB', 'totalSwitchIn': null, 'totalSwitchOut': 0},
      ],
    });
    expect(fund.fundSwitchIn, isNull);
    expect(fund.fundSwitchOut, 0);
    expect(const Holding({'assetType': 'MUTUAL_FUND'}).fundSwitchIn, isNull);
    expect(
      const Holding({'assetType': 'OFFSHORE_STOCK'}).fundSwitchOut,
      isNull,
    );
  });
}
