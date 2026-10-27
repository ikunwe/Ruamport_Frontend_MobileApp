// Fictional local fixtures for mobile UI. No API, sessions or financial writes.
enum AssetGroup { offshore, thai, fund }

const demoFx = 33.70;
const demoHistoricalFx = 32.64;
const groupNames = {
  AssetGroup.offshore: 'หุ้นนอก',
  AssetGroup.thai: 'หุ้นไทย',
  AssetGroup.fund: 'กองทุน',
};

class DemoAsset {
  const DemoAsset(
    this.symbol,
    this.name,
    this.group,
    this.market,
    this.quantity,
    this.average,
    this.price,
    this.dailyPercent,
    this.realized,
    this.fees,
  );
  final String symbol, name, market;
  final AssetGroup group;
  final double quantity, average, price, dailyPercent, realized, fees;
  String get currency => group == AssetGroup.offshore ? 'USD' : 'THB';
  String get unit => group == AssetGroup.fund ? 'หน่วย' : 'หุ้น';
  double get cost => quantity * average;
  double get value => quantity * price;
  double get pnl => value - cost;
  double get pnlPercent => pnl / cost * 100;
  double get previousPrice => price / (1 + dailyPercent / 100);
  double get dailyMoney => (price - previousPrice) * quantity;
  double get thbValue => value * (group == AssetGroup.offshore ? demoFx : 1);
  double get historicalCost =>
      cost * (group == AssetGroup.offshore ? demoHistoricalFx : 1);
  double get thbPricePnl => pnl * (group == AssetGroup.offshore ? demoFx : 1);
  double get fxPnl =>
      group == AssetGroup.offshore ? cost * (demoFx - demoHistoricalFx) : 0;
}

const demoAssets = <DemoAsset>[
  DemoAsset(
    'NVDA',
    'NVIDIA',
    AssetGroup.offshore,
    'NASDAQ',
    5,
    120,
    140,
    2.45,
    820,
    1.20,
  ),
  DemoAsset(
    'AAPL',
    'Apple',
    AssetGroup.offshore,
    'NASDAQ',
    3,
    210,
    200,
    -1.10,
    -140,
    .85,
  ),
  DemoAsset(
    'MSFT',
    'Microsoft',
    AssetGroup.offshore,
    'NASDAQ',
    1.25,
    420,
    450,
    1.35,
    570,
    .95,
  ),
  DemoAsset(
    'ADVANC',
    'แอดวานซ์ อินโฟร์ฯ',
    AssetGroup.thai,
    'SET',
    100,
    280,
    310,
    .90,
    730,
    35,
  ),
  DemoAsset(
    'ASK',
    'เอเซียเสริมกิจลีสซิ่ง',
    AssetGroup.thai,
    'SET',
    300,
    13,
    12,
    -1.65,
    -80,
    12,
  ),
  DemoAsset(
    'KKP US500-UH-E',
    'KKP US500',
    AssetGroup.fund,
    'บลจ.เกียรตินาคินภัทร',
    250,
    13.2,
    14.1,
    .65,
    100,
    0,
  ),
  DemoAsset(
    'KFAFIX-A',
    'Krungsri Active Fixed Income',
    AssetGroup.fund,
    'บลจ.กรุงศรี',
    400,
    11.5,
    11.6,
    -.12,
    50,
    0,
  ),
];

double sumOf(Iterable<DemoAsset> assets, double Function(DemoAsset) get) =>
    assets.fold(0, (sum, asset) => sum + get(asset));
String number(double value, [int digits = 2]) {
  if (!value.isFinite) return '—';
  final parts = value.abs().toStringAsFixed(digits).split('.');
  final integer = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return '${value < 0 ? '-' : ''}$integer${digits == 0 ? '' : '.${parts[1]}'}';
}

String money(double value, [String currency = 'THB']) =>
    '${number(value)} $currency';
String signedMoney(double value, [String currency = 'THB']) =>
    '${value > 0 ? '+' : ''}${money(value, currency)}';
String percent(double value) => '${value > 0 ? '+' : ''}${number(value)}%';
String units(double value) {
  if (value == value.roundToDouble()) return number(value, 0);
  return number(
    value,
    6,
  ).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
