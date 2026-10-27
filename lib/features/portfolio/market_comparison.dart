import '../import/import_models.dart';
import 'portfolio_data.dart';

const overviewMarkets = {
  'SP500': 'S&P 500',
  'NASDAQ_COMPOSITE': 'NASDAQ',
  'DOW_JONES': 'Dow Jones',
  'SET': 'SET Index',
  'SET50': 'SET50 Index',
};

List<(String, double?)> marketComparisonRows(
  HoldingsData? holdings,
  Map<String, dynamic>? response,
) {
  final portfolio = objectMap(
    objectMap(holdings?.data['latestChange'])['portfolio'],
  );
  final daily =
      portfolio['isComplete'] == true &&
          portfolio['status'] == 'CALCULATED' &&
          portfolio['currency'] == 'THB' &&
          finiteNumber(portfolio['change']) != null
      ? finiteNumber(portfolio['changePercent'])
      : null;
  final rows = objectList(response?['items']);
  return [
    ('Your port', daily),
    for (final market in overviewMarkets.entries)
      (market.value, indexDailyPercent(rows, market.key)),
  ];
}

double? indexDailyPercent(List<Map<String, dynamic>> rows, String id) {
  final matches = rows.where((row) => row['id'] == id).toList();
  if (matches.length != 1) return null;
  final row = matches.single;
  final value = finiteNumber(row['value']),
      previous = finiteNumber(row['previousClose']);
  return row['status'] == 'AVAILABLE' &&
          value != null &&
          value > 0 &&
          previous != null &&
          previous > 0
      ? finiteNumber(row['changePercent'])
      : null;
}

double comparisonWidth(double? value, Iterable<double?> allValues) {
  var peak = 0.0;
  for (final candidate in allValues.whereType<double>()) {
    if (candidate.isFinite && candidate.abs() > peak) peak = candidate.abs();
  }
  return value == null || peak == 0
      ? 0
      : (value.abs() / peak * .8).clamp(0, .8);
}
