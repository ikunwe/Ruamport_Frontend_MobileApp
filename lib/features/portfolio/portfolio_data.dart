import 'dart:convert';
import '../import/import_models.dart';

const assetTypes = {
  'OFFSHORE_STOCK': 'หุ้นนอก',
  'THAI_STOCK': 'หุ้นไทย',
  'MUTUAL_FUND': 'กองทุน',
};
double? finiteNumber(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;
double? sumMoney(Iterable<double?> values) {
  int cents = 0;
  for (final value in values) {
    if (value == null || !value.isFinite) return null;
    cents += (value * 100).round();
  }
  return cents.abs() <= 9007199254740991 ? cents / 100 : null;
}

double? difference(double? a, double? b) =>
    a == null || b == null ? null : sumMoney([a, -b]);
double? ratioPercent(double? profit, double? basis) =>
    profit != null && basis != null && basis > 0 ? profit / basis * 100 : null;
Map<String, dynamic> currencyRow(Object? list, String currency) =>
    objectList(list).where((row) => row['currency'] == currency).firstOrNull ??
    {};

// ใช้ decimal multiplication แบบเดียวกับเว็บสำหรับการแสดง USD → THB
double? convertMoney(double? value, double? rate) {
  if (value == null ||
      rate == null ||
      rate <= 0 ||
      !value.isFinite ||
      !rate.isFinite) {
    return null;
  }
  (BigInt, int) decimal(double n) {
    final parts = n.toString().toLowerCase().split('e');
    final coefficient = parts[0];
    final scale =
        (coefficient.contains('.') ? coefficient.split('.')[1].length : 0) -
        (parts.length > 1 ? int.parse(parts[1]) : 0);
    return (BigInt.parse(coefficient.replaceAll('.', '')), scale);
  }

  final (a, sa) = decimal(value);
  final (b, sb) = decimal(rate);
  var product = a * b;
  final shift = sa + sb - 2;
  if (shift > 0) {
    final divisor = BigInt.from(10).pow(shift);
    final absolute = product.abs();
    final rounded =
        absolute ~/ divisor +
        (absolute.remainder(divisor) * BigInt.two >= divisor
            ? BigInt.one
            : BigInt.zero);
    product = product.isNegative ? -rounded : rounded;
  } else {
    product *= BigInt.from(10).pow(-shift);
  }
  return product.abs() <= BigInt.from(9007199254740991)
      ? product.toDouble() / 100
      : null;
}

class Holding {
  const Holding(this.data);
  final Map<String, dynamic> data;
  String get type => textValue(data['assetType']) ?? '';
  String get symbol => textValue(data['symbol']) ?? '—';
  String get currency => textValue(data['currency']) ?? '';
  String get unit => type == 'MUTUAL_FUND' ? 'หน่วย' : 'หุ้น';
  bool get offshore => type == 'OFFSHORE_STOCK';
  bool get held => data['status'] == 'HELD' && (quantity ?? 0) > 0;
  bool get hasDisposals =>
      (finiteNumber(data['soldUnits']) ?? 0) > 0 ||
      (finiteNumber(data['disposedUnits']) ?? 0) > 0 ||
      objectList(
        data['realizedPnl'],
      ).any((row) => (finiteNumber(row['soldCost']) ?? 0) > 0);
  String get disposalLabel => data['status'] == 'CLOSED'
      ? 'ขายหมดแล้ว'
      : held
      ? 'ขายบางส่วน'
      : 'ข้อมูลถือครองไม่ครบ';
  double? get quantity => finiteNumber(data['quantity']);
  String get key => jsonEncode([
    type,
    data['accountNumber'],
    symbol,
    data['exchange'],
    currency,
  ]);
  String get market =>
      const {'XNAS': 'NASDAQ', 'XNYS': 'NYSE'}[data['exchange']] ??
      textValue(data['exchange']) ??
      '';
  Map<String, dynamic> get valuation => objectMap(data['marketValuation']);
  Map<String, dynamic> get quote => objectMap(valuation['quote']);
  Map<String, dynamic> get latest => objectMap(data['latestChange']);
  String? get logoUrl {
    final logo = objectMap(data['logo']);
    return textValue(data['logoUrl']) ??
        (['AVAILABLE', 'UNVERIFIED'].contains(logo['status'])
            ? textValue(logo['url'])
            : null);
  }

  Map<String, dynamic> costRow(String c) => currencyRow(data['costBasis'], c);
  Map<String, dynamic> amounts(String c) => currencyRow(data['amounts'], c);
  double? get fundSwitchIn => type == 'MUTUAL_FUND'
      ? finiteNumber(amounts('THB')['totalSwitchIn'])
      : null;
  double? get fundSwitchOut => type == 'MUTUAL_FUND'
      ? finiteNumber(amounts('THB')['totalSwitchOut'])
      : null;
  double? cost(String c) => costRow(c)['status'] == 'CALCULATED'
      ? finiteNumber(costRow(c)['remainingCost'])
      : null;
  double? average(String c) => costRow(c)['status'] == 'CALCULATED'
      ? finiteNumber(costRow(c)['averageCostPerUnit'])
      : null;
  double? marketValue(String c) =>
      finiteNumber(objectMap(valuation[c.toLowerCase()])['marketValue']);
  double? pnl(String c) =>
      finiteNumber(objectMap(valuation[c.toLowerCase()])['unrealizedPnl']);
  double? pnlPercent(String c) => finiteNumber(
    objectMap(valuation[c.toLowerCase()])['unrealizedPnlPercent'],
  );
  double? buy(String c) => type == 'MUTUAL_FUND'
      ? amounts(c)['isComplete'] == true
            ? finiteNumber(amounts(c)['totalBuy'])
            : null
      : amounts(c)['grossIsComplete'] == true
      ? finiteNumber(amounts(c)['totalBuyGross'])
      : null;
  double? sell(String c) => amounts(c)['isComplete'] == true
      ? finiteNumber(amounts(c)['totalSell'])
      : null;
  double? fees(String c) => amounts(c)['feeIsComplete'] == true
      ? finiteNumber(amounts(c)['totalFeeIncludeVat'])
      : null;
  double? realized(String c) {
    final row = currencyRow(data['realizedPnl'], c);
    return row['status'] == 'CALCULATED'
        ? finiteNumber(row['realizedPnl'])
        : null;
  }

  double? fxProfit(double? rate) =>
      !offshore ? 0 : difference(convertMoney(cost('USD'), rate), cost('THB'));
  double? get price => quote['status'] == 'AVAILABLE'
      ? finiteNumber(quote['price'] ?? quote['navPerUnit'])
      : null;
  double? get dailyPercent => latest.isNotEmpty
      ? ['CALCULATED', 'FX_UNAVAILABLE'].contains(latest['status'])
            ? finiteNumber(objectMap(latest['native'])['changePercent'])
            : null
      : finiteNumber(quote['changePercent']);
  double? get dailyChange => finiteNumber(quote['change']);
}

class HoldingsData {
  HoldingsData(this.data)
    : items = objectList(data['items']).map(Holding.new).toList();
  final Map<String, dynamic> data;
  final List<Holding> items;
  List<Holding> get held => items.where((item) => item.held).toList();
  double? get rate {
    final fx = objectMap(data['fx']);
    final rate = finiteNumber(fx['rate']);
    return fx['status'] == 'AVAILABLE' &&
            fx['baseCurrency'] == 'USD' &&
            fx['quoteCurrency'] == 'THB' &&
            rate != null &&
            rate > 0
        ? rate
        : null;
  }

  Map<String, dynamic> categoryValuation(String type) => objectMap(
    data[const {
      'OFFSHORE_STOCK': 'offshoreValuation',
      'THAI_STOCK': 'thaiStockValuation',
      'MUTUAL_FUND': 'mutualFundValuation',
    }[type]],
  );
  double? categoryValue(String type, String currency, String field) {
    if (type == 'MUTUAL_FUND' && data['scope'] == 'STOCK_BUY_SELL_ONLY') {
      return null;
    }
    final rows = held.where((item) => item.type == type);
    if (rows.isEmpty) return field.endsWith('Percent') ? null : 0;
    if (rows.any((item) => item.currency != (item.offshore ? 'USD' : 'THB'))) {
      return null;
    }
    if (type == 'OFFSHORE_STOCK' && currency == 'THB' && rate == null) {
      return null;
    }
    return finiteNumber(
      objectMap(categoryValuation(type)[currency.toLowerCase()])[field],
    );
  }

  double? get value => sumMoney(
    assetTypes.keys.map((type) => categoryValue(type, 'THB', 'marketValue')),
  );
  double? get assetProfit => sumMoney(
    assetTypes.keys.map((type) => categoryValue(type, 'THB', 'unrealizedPnl')),
  );
  double? get historicalCost {
    final total = currencyRow(data['remainingCostTotals'], 'THB');
    return total['isComplete'] == true
        ? finiteNumber(total['remainingCost'])
        : null;
  }

  double? get realized {
    final total = currencyRow(data['realizedPnlTotals'], 'THB');
    return total['isComplete'] == true
        ? finiteNumber(total['realizedPnl'])
        : null;
  }

  double? get soldCost {
    final total = currencyRow(data['realizedPnlTotals'], 'THB');
    return total['isComplete'] == true ? finiteNumber(total['soldCost']) : null;
  }

  double? get fxProfit => sumMoney(held.map((item) => item.fxProfit(rate)));
  double? get unrealized => sumMoney([assetProfit, fxProfit]);
  double? get totalProfit => sumMoney([unrealized, realized]);
  double? get totalProfitPercent =>
      ratioPercent(totalProfit, sumMoney([historicalCost, soldCost]));
  double? get averageFx {
    final offshore = held.where((item) => item.offshore);
    final usd = sumMoney(offshore.map((item) => item.cost('USD')));
    final thb = sumMoney(offshore.map((item) => item.cost('THB')));
    return usd != null && usd > 0 && thb != null ? thb / usd : null;
  }

  double? categoryTotal(String type, String currency, String field) {
    if (type == 'MUTUAL_FUND' && data['scope'] == 'STOCK_BUY_SELL_ONLY') {
      return null;
    }
    if (data['includeClosed'] != true ||
        objectList(
          data['excludedTransactions'],
        ).any((row) => row['assetType'] == type)) {
      return null;
    }
    return sumMoney(
      items
          .where((item) => item.type == type)
          .map(
            (item) => switch (field) {
              'cost' => item.cost(currency),
              'buy' => item.buy(currency),
              'sell' => item.sell(currency),
              _ => item.fees(currency),
            },
          ),
    );
  }
}
