import 'package:flutter_test/flutter_test.dart';
import 'package:project_portfoliomanagement_mobile/features/portfolio/portfolio_data.dart';

void main() {
  test('zero realized profit alone does not mean a sale occurred', () {
    const item = Holding({
      'status': 'HELD',
      'quantity': 2,
      'soldUnits': 0,
      'realizedPnl': [
        {'currency': 'THB', 'soldCost': 0, 'realizedPnl': 0},
      ],
    });
    expect(item.hasDisposals, isFalse);
  });
  test('a break-even partial sale remains visible', () {
    const item = Holding({
      'status': 'HELD',
      'quantity': 2,
      'soldUnits': 1,
      'realizedPnl': [
        {
          'currency': 'THB',
          'status': 'CALCULATED',
          'soldCost': 100,
          'realizedPnl': 0,
        },
      ],
    });
    expect(item.hasDisposals, isTrue);
    expect(item.realized('THB'), 0);
    expect(item.disposalLabel, 'ขายบางส่วน');
  });
  test('closed and disposed fund units have disposal evidence', () {
    const closed = Holding({
      'status': 'CLOSED',
      'quantity': 0,
      'disposedUnits': 5,
    });
    expect(closed.hasDisposals, isTrue);
    expect(closed.disposalLabel, 'ขายหมดแล้ว');
    expect(
      const Holding({
        'realizedPnl': [
          {'soldCost': 100},
        ],
      }).hasDisposals,
      isTrue,
    );
  });
}
