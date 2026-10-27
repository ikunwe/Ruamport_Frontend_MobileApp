import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/panel.dart';
import '../import/import_models.dart';
import '../portfolio/portfolio_store.dart';
import '../portfolio/portfolio_data.dart';
import '../portfolio/live_finance_ui.dart';
import '../portfolio/live_chart.dart';

const analyticsBenchmarks = {
  'SP500': 'S&P 500',
  'NASDAQ_COMPOSITE': 'NASDAQ',
  'SET': 'SET Index',
  'SET50': 'SET50 Index',
};

class LiveAnalyticsPage extends StatefulWidget {
  const LiveAnalyticsPage({
    super.key,
    required this.store,
    required this.active,
  });
  final PortfolioStore store;
  final bool active;
  @override
  State<LiveAnalyticsPage> createState() => _LiveAnalyticsPageState();
}

class _LiveAnalyticsPageState extends State<LiveAnalyticsPage> {
  String category = 'ALL',
      range = '1Y',
      benchmark = 'SP500',
      unit = 'MONTH',
      source = 'ยังถือ';
  Map<String, dynamic>? performance, wins;
  String? performanceError, winsError;
  bool started = false, loading = false, loadingWins = false;
  int performanceRequest = 0, winsRequest = 0;
  int lastRevision = -1;
  @override
  void initState() {
    super.initState();
    widget.store.addListener(startIfActive);
    startIfActive();
  }

  @override
  void didUpdateWidget(covariant LiveAnalyticsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    startIfActive();
  }

  void startIfActive() {
    if (widget.active &&
        widget.store.data != null &&
        (!started || lastRevision != widget.store.revision)) {
      started = true;
      lastRevision = widget.store.revision;
      load();
      loadWins();
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(startIfActive);
    super.dispose();
  }

  Future<void> load({bool force = false}) async {
    final id = ++performanceRequest;
    final c = category, r = range, b = benchmark;
    setState(() {
      performance = null;
      performanceError = null;
      loading = true;
    });
    try {
      final value = await widget.store.request(
        '/trades/analytics/performance?category=$c&range=$r&benchmarkId=$b',
        force: force,
      );
      if (value['calculationVersion'] != 2 ||
          value['category'] != c ||
          value['range'] != r ||
          objectMap(value['benchmark'])['id'] != b ||
          value['comparisonCurrency'] != 'THB' ||
          value['points'] is! List) {
        throw const FormatException('ANALYTICS_RESPONSE_INVALID');
      }
      if (mounted && id == performanceRequest) {
        setState(() => performance = value);
      }
    } catch (_) {
      if (mounted && id == performanceRequest) {
        setState(
          () => performanceError = 'โหลดกราฟเปรียบเทียบไม่สำเร็จ กรุณาลองใหม่',
        );
      }
    } finally {
      if (mounted && id == performanceRequest) setState(() => loading = false);
    }
  }

  Future<void> loadWins({bool force = false}) async {
    final id = ++winsRequest;
    final c = category, r = range, u = unit;
    setState(() {
      wins = null;
      winsError = null;
      loadingWins = true;
    });
    try {
      final value = await widget.store.request(
        '/trades/analytics/win-rate?category=$c&range=$r&unit=$u',
        force: force,
      );
      if (value['calculationVersion'] != 2 ||
          value['category'] != c ||
          value['range'] != r ||
          value['unit'] != u ||
          value['markets'] is! List) {
        throw const FormatException('ANALYTICS_RESPONSE_INVALID');
      }
      if (mounted && id == winsRequest) setState(() => wins = value);
    } catch (_) {
      if (mounted && id == winsRequest) {
        setState(() => winsError = 'โหลดอัตราชนะตลาดไม่สำเร็จ กรุณาลองใหม่');
      }
    } finally {
      if (mounted && id == winsRequest) setState(() => loadingWins = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final data = widget.store.data;
      final assets = (data?.items ?? <Holding>[])
          .where((item) => category == 'ALL' || item.type == category)
          .toList();
      final fxVisible = category == 'ALL' || category == 'OFFSHORE_STOCK';
      final currentSource = !fxVisible && source == 'ค่าเงิน'
          ? 'ยังถือ'
          : source;
      double? value(Holding item) => currentSource == 'ขายแล้ว'
          ? item.realized('THB')
          : currentSource == 'ค่าเงิน'
          ? item.offshore && item.held
                ? item.fxProfit(data?.rate)
                : null
          : item.held
          ? item.pnl('THB')
          : null;
      final contributors =
          assets
              .where(
                (item) => currentSource == 'ขายแล้ว'
                    ? item.hasDisposals
                    : item.held &&
                          (currentSource != 'ค่าเงิน' || item.offshore),
              )
              .toList()
            ..sort(
              (a, b) =>
                  (value(b)?.abs() ?? -1).compareTo(value(a)?.abs() ?? -1),
            );
      final market = objectList(
        wins?['markets'],
      ).where((item) => item['id'] == benchmark).firstOrNull;
      final unrealized = category == 'ALL'
          ? data?.assetProfit
          : data?.categoryValue(category, 'THB', 'unrealizedPnl');
      final realized = category == 'ALL'
          ? data?.realized
          : sumMoney(assets.map((item) => item.realized('THB')));
      return FinanceList(
        key: const PageStorageKey('live-analytics'),
        children: [
          const PageHeading('Analytics', 'เข้าใจการเติบโตและที่มาของผลตอบแทน'),
          ChoiceStrip(
            labels: ['ทั้งพอร์ต', ...assetTypes.values],
            value: category == 'ALL' ? 'ทั้งพอร์ต' : assetTypes[category]!,
            onChanged: (label) {
              setState(
                () => category = label == 'ทั้งพอร์ต'
                    ? 'ALL'
                    : assetTypes.entries
                          .firstWhere((row) => row.value == label)
                          .key,
              );
              load();
              loadWins();
            },
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your port vs Market',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'รีเฟรชกราฟ',
                      onPressed: loading ? null : () => load(force: true),
                      icon: const Icon(Icons.refresh, size: 20),
                    ),
                  ],
                ),
                const Text(
                  'เปรียบเทียบการเติบโต · ผลตอบแทน (%)',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(height: 18),
                twoColumns(
                  SmallStat(
                    'พอร์ตของคุณ',
                    percentage(
                      finiteNumber(
                        objectMap(
                          performance?['portfolio'],
                        )['cumulativeReturnPercent'],
                      ),
                    ),
                    color: lime,
                  ),
                  SmallStat(
                    analyticsBenchmarks[benchmark]!,
                    percentage(
                      finiteNumber(
                        objectMap(
                          performance?['benchmark'],
                        )['cumulativeReturnPercent'],
                      ),
                    ),
                    color: blue,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButton<String>(
                  value: benchmark,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: analyticsBenchmarks.entries
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.key,
                          child: Text(
                            item.value,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() => benchmark = value!);
                    load();
                  },
                ),
                if (performance == null)
                  DataNotice(
                    performanceError ?? 'กำลังโหลดข้อมูลเปรียบเทียบ',
                    loading: loading,
                    retry: loading ? null : () => load(force: true),
                  )
                else ...[
                  LiveChart(
                    points: objectList(performance!['points']),
                    field: 'portfolioReturnPercent',
                    comparisonField: 'benchmarkReturnPercent',
                    unit: '%',
                  ),
                  if (performance!['comparable'] != true)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'ข้อมูลเปรียบเทียบยังไม่ครบ แสดงเฉพาะเส้นที่มีข้อมูล และยังไม่สรุปชนะตลาด',
                        style: TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                ChoiceStrip(
                  labels: const ['1M', '3M', '1Y', 'ALL'],
                  value: range,
                  onChanged: (value) {
                    setState(() => range = value);
                    load();
                    loadWins();
                  },
                ),
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'อัตราชนะตลาด',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                ChoiceStrip(
                  labels: const ['รายสัปดาห์', 'รายเดือน', 'รายปี'],
                  value: const {
                    'WEEK': 'รายสัปดาห์',
                    'MONTH': 'รายเดือน',
                    'YEAR': 'รายปี',
                  }[unit]!,
                  onChanged: (value) {
                    setState(
                      () => unit = value == 'รายสัปดาห์'
                          ? 'WEEK'
                          : value == 'รายเดือน'
                          ? 'MONTH'
                          : 'YEAR',
                    );
                    loadWins();
                  },
                ),
                const SizedBox(height: 16),
                if (wins == null)
                  DataNotice(
                    winsError ?? 'กำลังโหลดอัตราชนะตลาด',
                    loading: loadingWins,
                    retry: loadingWins ? null : () => loadWins(force: true),
                  )
                else ...[
                  for (final item in objectList(wins!['markets']))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              analyticsBenchmarks[item['id']] ??
                                  textValue(item['name']) ??
                                  '—',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            percentage(finiteNumber(item['winRatePercent'])),
                            style: const TextStyle(color: lime, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  const Divider(),
                  Text(
                    'ย้อนหลังเทียบ ${analyticsBenchmarks[benchmark]} · เก่า → ใหม่',
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  if (objectList(market?['periods']).isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'ยังไม่มีช่วงเวลาที่พร้อมเปรียบเทียบ',
                        style: TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    )
                  else
                    SizedBox(
                      height: 210,
                      child: ListView(
                        padding: const EdgeInsets.only(top: 10),
                        children: objectList(market?['periods']).map((period) {
                          final outcome =
                              textValue(period['outcome']) ?? 'INCOMPLETE';
                          final statusColor = outcome == 'WIN'
                              ? lime
                              : outcome == 'LOSS'
                              ? loss
                              : Colors.white54;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: .04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusColor.withValues(alpha: .2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${period['startDate']} – ${period['endDate']}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white54,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${percentage(finiteNumber(period['portfolioReturnPercent']))} / ${percentage(finiteNumber(period['benchmarkReturnPercent']))}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  const {
                                        'WIN': 'ชนะ',
                                        'LOSS': 'แพ้',
                                        'TIE': 'เสมอ',
                                        'PENDING': 'รอจบช่วง',
                                        'INCOMPLETE': 'ข้อมูลไม่ครบ',
                                      }[outcome] ??
                                      'ข้อมูลไม่ครบ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ที่มาของกำไร',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                SmallStat(
                  'ราคาสินทรัพย์ที่ยังถือ',
                  signedAmount(unrealized),
                  color: profitColor(unrealized),
                ),
                const SizedBox(height: 14),
                if (fxVisible) ...[
                  SmallStat(
                    'ค่าเงินหุ้นนอก',
                    signedAmount(data?.fxProfit),
                    color: profitColor(data?.fxProfit),
                  ),
                  const SizedBox(height: 14),
                ],
                SmallStat(
                  'กำไร/ขาดทุนที่ขายแล้ว',
                  signedAmount(realized),
                  color: profitColor(realized),
                ),
                const SizedBox(height: 6),
                const Text(
                  'รวมขายบางส่วนด้วย · ก่อนค่าธรรมเนียมและภาษี',
                  style: TextStyle(fontSize: 9, color: Colors.white38),
                ),
              ],
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'สินทรัพย์ที่ส่งผลต่อพอร์ต',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                ChoiceStrip(
                  labels: ['ยังถือ', 'ขายแล้ว', if (fxVisible) 'ค่าเงิน'],
                  value: currentSource,
                  onChanged: (value) => setState(() => source = value),
                ),
                const SizedBox(height: 14),
                if (contributors.isEmpty)
                  const Text(
                    'ยังไม่มีสินทรัพย์ในหมวดนี้',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  )
                else
                  SizedBox(
                    height: 230,
                    child: ListView(
                      children: contributors
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  HoldingLogo(item, size: 30),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.symbol,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        if (currentSource == 'ขายแล้ว') ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            item.disposalLabel,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    signedAmount(value(item)),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: profitColor(value(item)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
