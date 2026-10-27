import 'dart:async';
import 'package:flutter/material.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/finance_charts.dart' show AllocationRing;
import '../../shared/widgets/panel.dart';
import '../import/import_models.dart';
import '../import/import_api.dart';
import '../import/pdf_preview_view.dart';
import '../portfolio/portfolio_store.dart';
import '../portfolio/portfolio_data.dart';
import '../portfolio/live_chart.dart';
import '../portfolio/live_finance_ui.dart';
import '../portfolio/market_comparison.dart';

class LiveOverviewPage extends StatefulWidget {
  const LiveOverviewPage({
    super.key,
    required this.store,
    required this.name,
    required this.onAsset,
    required this.onImport,
    required this.onAnalytics,
  });
  final PortfolioStore store;
  final String name;
  final ValueChanged<Holding> onAsset;
  final VoidCallback onImport, onAnalytics;
  @override
  State<LiveOverviewPage> createState() => _LiveOverviewPageState();
}

class _LiveOverviewPageState extends State<LiveOverviewPage>
    with WidgetsBindingObserver {
  String period = '1M', allocation = 'ALL';
  Map<String, dynamic>? history;
  Map<String, dynamic>? comparisons;
  String? historyError, comparisonError;
  bool loading = false, started = false;
  int request = 0;
  int lastRevision = -1;
  Timer? comparisonTimer;
  DateTime? comparisonDue;
  bool loadingComparison = false;
  bool appActive = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.store.addListener(ready);
    ready();
  }

  @override
  void dispose() {
    widget.store.removeListener(ready);
    WidgetsBinding.instance.removeObserver(this);
    comparisonTimer?.cancel();
    super.dispose();
  }

  void ready() {
    if ((!started || lastRevision != widget.store.revision) &&
        widget.store.data != null &&
        widget.store.data!.items.isNotEmpty) {
      started = true;
      lastRevision = widget.store.revision;
      load();
      compare();
    }
  }

  Future<void> load({bool force = false}) async {
    final id = ++request;
    setState(() {
      loading = true;
      history = null;
      historyError = null;
    });
    try {
      final value = await widget.store.request(
        '/trades/portfolio-history?range=$period',
        force: force,
      );
      if (value['range'] != period ||
          value['currency'] != 'THB' ||
          value['points'] is! List) {
        throw const ImportFailure('INVALID_RESPONSE');
      }
      if (mounted && id == request) setState(() => history = value);
    } catch (_) {
      if (mounted && id == request) {
        setState(() => historyError = 'โหลดกราฟย้อนหลังไม่สำเร็จ กรุณาลองใหม่');
      }
    } finally {
      if (mounted && id == request) setState(() => loading = false);
    }
  }

  Future<void> compare({bool force = false}) async {
    if (loadingComparison) return;
    comparisonTimer?.cancel();
    setState(() {
      loadingComparison = true;
      comparisonError = null;
    });
    DateTime due = DateTime.now().add(const Duration(minutes: 15));
    try {
      final value = await widget.store.request(
        '/trades/market-indices',
        force: force,
      );
      if (value['items'] is! List) {
        throw const ImportFailure('INVALID_RESPONSE');
      }
      for (final item in objectList(value['items'])) {
        final retry = DateTime.tryParse(textValue(item['retryAt']) ?? '');
        if (retry != null && retry.isAfter(due)) due = retry;
      }
      if (mounted) setState(() => comparisons = value);
    } catch (_) {
      if (mounted) {
        setState(() => comparisonError = 'โหลดดัชนีตลาดไม่สำเร็จ กรุณาลองใหม่');
      }
    } finally {
      if (mounted) {
        setState(() => loadingComparison = false);
        comparisonDue = due;
        scheduleComparison();
      }
    }
  }

  void scheduleComparison() {
    comparisonTimer?.cancel();
    if (!mounted || !appActive || comparisonDue == null) return;
    final wait = comparisonDue!.difference(DateTime.now());
    comparisonTimer = Timer(
      wait.isNegative ? Duration.zero : wait,
      () => compare(force: true),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    appActive = state == AppLifecycleState.resumed;
    comparisonTimer?.cancel();
    if (appActive) scheduleComparison();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final store = widget.store, data = store.data;
      final held = data?.held ?? [];
      final comparisonRows = marketComparisonRows(data, comparisons);
      final allocationEntries = allocation == 'ALL'
          ? assetTypes.entries
                .map(
                  (entry) => (
                    entry.value,
                    data?.categoryValue(entry.key, 'THB', 'marketValue'),
                  ),
                )
                .toList()
          : held
                .where((item) => item.type == allocation)
                .map(
                  (item) => (
                    item.symbol,
                    item.marketValue(item.offshore ? 'USD' : 'THB'),
                  ),
                )
                .toList();
      final allocationTotal = sumMoney(
        allocationEntries.map((entry) => entry.$2),
      );
      final unique = <String, Holding>{};
      for (final item in held.where(
        (item) => item.dailyPercent != null && item.dailyPercent != 0,
      )) {
        unique.putIfAbsent(
          '${item.type}|${item.symbol}|${item.data['exchange']}',
          () => item,
        );
      }
      final movers = unique.values.toList()
        ..sort((a, b) => b.dailyPercent!.compareTo(a.dailyPercent!));
      final positives = movers.where((item) => item.dailyPercent! > 0).take(2);
      final negatives = movers
          .where((item) => item.dailyPercent! < 0)
          .toList()
          .reversed
          .take(2)
          .toList()
          .reversed;
      final day = objectMap(objectMap(data?.data['latestChange'])['portfolio']);
      final stats = [
        ('ต้นทุนรวมตามเอกสาร', data?.historicalCost, false, ''),
        (
          'กำไร/ขาดทุนทั้งหมด',
          data?.totalProfit,
          true,
          'รวมสินทรัพย์ ค่าเงิน และขายแล้ว',
        ),
        ('Unrealized P&L', data?.unrealized, true, 'ส่วนที่ยังถือ รวมค่าเงิน'),
        ('Realized P&L', data?.realized, true, 'กำไร/ขาดทุนที่ขายแล้ว'),
        ('กำไรจากสินทรัพย์', data?.assetProfit, true, ''),
        (
          'กำไร/ขาดทุนค่าเงิน',
          data?.fxProfit,
          true,
          'เรทต้นทุนเฉลี่ย ${pdfNumber(data?.averageFx)} THB',
        ),
      ];
      return FinanceList(
        key: const PageStorageKey('live-overview'),
        children: [
          PageHeading(
            'สวัสดี, ${widget.name}',
            'OVERVIEW · ภาพรวมการลงทุนของคุณ',
          ),
          if (store.error != null)
            DataNotice(
              store.error!,
              retry: store.refresh,
              loading: store.loading,
            ),
          if (data == null)
            DataNotice('กำลังโหลดข้อมูลพอร์ต', loading: store.loading)
          else if (data.items.isEmpty)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ยังไม่มีรายการลงทุนที่บันทึกไว้',
                    style: TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: widget.onImport,
                    child: const Text('อัปโหลด PDF หรือ Sync ข้อมูล'),
                  ),
                ],
              ),
            )
          else ...[
            Panel(
              accent: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'มูลค่ารวมทั้งพอร์ต',
                    style: TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      amount(data.value),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: profitColor(
                          difference(data.value, data.historicalCost),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '≈ ${amount(data.value != null && data.rate != null ? data.value! / data.rate! : null, 'USD')}',
                    style: const TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                  const SizedBox(height: 12),
                  LivePnl(
                    day['isComplete'] == true
                        ? finiteNumber(day['change'])
                        : null,
                    percent: day['isComplete'] == true
                        ? finiteNumber(day['changePercent'])
                        : null,
                    size: 11,
                  ),
                  if (history != null)
                    LiveChart(
                      points: objectList(history!['points']),
                      field: 'marketValue',
                    )
                  else
                    DataNotice(
                      historyError ?? 'กำลังโหลดกราฟย้อนหลัง',
                      loading: loading,
                      retry: loading ? null : () => load(force: true),
                    ),
                  const SizedBox(height: 16),
                  ChoiceStrip(
                    labels: const ['1D', '1W', '1M', '3M', '1Y', 'ALL'],
                    value: period,
                    onChanged: (value) {
                      setState(() => period = value);
                      load();
                    },
                  ),
                  if (history?['status'] == 'INCOMPLETE')
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'ประวัติบางช่วงยังไม่ครบ แสดงช่องว่างตามข้อมูลที่ได้รับ',
                        style: TextStyle(fontSize: 10, color: Colors.white38),
                      ),
                    ),
                ],
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 14,
              mainAxisExtent:
                  (MediaQuery.sizeOf(context).width < 360 ? 144 : 128) *
                  (MediaQuery.textScalerOf(context).scale(18) / 18).clamp(
                    1.0,
                    double.infinity,
                  ),
              children: stats
                  .map(
                    (stat) => Panel(
                      padding: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.$1,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 10),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              stat.$3 ? signedAmount(stat.$2) : amount(stat.$2),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: stat.$3 ? profitColor(stat.$2) : null,
                              ),
                            ),
                          ),
                          if (stat.$4.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              stat.$4,
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white30,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'สัดส่วนสินทรัพย์',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  ChoiceStrip(
                    labels: ['ทั้งพอร์ต', ...assetTypes.values],
                    value: allocation == 'ALL'
                        ? 'ทั้งพอร์ต'
                        : assetTypes[allocation]!,
                    onChanged: (value) => setState(
                      () => allocation = value == 'ทั้งพอร์ต'
                          ? 'ALL'
                          : assetTypes.entries
                                .firstWhere((entry) => entry.value == value)
                                .key,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (allocationTotal == null || allocationTotal <= 0)
                    const DataNotice('ยังไม่มีมูลค่าครบสำหรับแสดงสัดส่วน')
                  else
                    AllocationRing(
                      labels: allocationEntries
                          .map((entry) => entry.$1)
                          .toList(),
                      values: allocationEntries
                          .map((entry) => entry.$2!)
                          .toList(),
                    ),
                ],
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '% เปลี่ยนแปลงจากวันก่อนหน้ามากสุด',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  if (movers.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: Text(
                        'ยังไม่มีข้อมูลเปลี่ยนแปลงรายวันที่พร้อมแสดง',
                        style: TextStyle(fontSize: 11, color: Colors.white38),
                      ),
                    ),
                  for (final item in [...positives, ...negatives])
                    InkWell(
                      onTap: () => widget.onAsset(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            HoldingLogo(item, size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.symbol,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    amount(item.price, item.currency),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              percentage(item.dailyPercent),
                              style: TextStyle(
                                fontSize: 13,
                                color: profitColor(item.dailyPercent),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'เปิด Analytics',
                        onPressed: widget.onAnalytics,
                        icon: const Icon(Icons.arrow_forward, size: 20),
                      ),
                    ],
                  ),
                  const Text(
                    'การเปลี่ยนแปลงจากวันก่อนหน้า',
                    style: TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                  if (comparisons == null)
                    DataNotice(
                      comparisonError ?? 'กำลังโหลดข้อมูลเปรียบเทียบ',
                      loading: loadingComparison,
                      retry: loadingComparison
                          ? null
                          : () => compare(force: true),
                    ),
                  for (final row in comparisonRows)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  row.$1,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                percentage(row.$2),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: profitColor(row.$2),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: comparisonWidth(
                              row.$2,
                              comparisonRows.map((item) => item.$2),
                            ),
                            minHeight: 5,
                            color: profitColor(row.$2) ?? Colors.white30,
                            backgroundColor: Colors.white10,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}
