import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/panel.dart';
import '../import/import_api.dart';
import '../import/import_models.dart';
import '../import/pdf_preview_view.dart';
import '../portfolio/portfolio_data.dart';
import '../portfolio/portfolio_store.dart';
import '../portfolio/live_finance_ui.dart';

class LiveSimulatorPage extends StatefulWidget {
  const LiveSimulatorPage({super.key, required this.store});
  final PortfolioStore store;
  @override
  State<LiveSimulatorPage> createState() => _LiveSimulatorPageState();
}

class _LiveSimulatorPageState extends State<LiveSimulatorPage> {
  String? selected, revision;
  String tool = 'ซื้อ / ขาย', side = 'ซื้อเพิ่ม';
  final price = TextEditingController(),
      quantity = TextEditingController(),
      buyPrice = TextEditingController(),
      targetAverage = TextEditingController(),
      targetPrice = TextEditingController();
  Map<String, dynamic>? result;
  String? error;
  bool busy = false;
  int previous = -1;
  List<Holding> get assets => widget.store.data?.held ?? [];
  Holding? get asset =>
      assets.where((item) => item.key == selected).firstOrNull;
  @override
  void initState() {
    super.initState();
    widget.store.addListener(changed);
    changed();
  }

  @override
  void dispose() {
    widget.store.removeListener(changed);
    for (final controller in [
      price,
      quantity,
      buyPrice,
      targetAverage,
      targetPrice,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void changed() {
    if (previous != widget.store.revision) {
      previous = widget.store.revision;
      result = null;
      revision = null;
    }
    if (asset == null && assets.isNotEmpty) choose(assets.first.key);
    if (mounted) setState(() {});
  }

  void choose(String key) {
    selected = key;
    result = null;
    revision = null;
    error = null;
    final value = asset?.price?.toString() ?? '';
    price.text = value;
    buyPrice.text = value;
    targetPrice.text = value;
    quantity.clear();
    targetAverage.clear();
  }

  double? positive(String text) {
    if (!RegExp(r'^(?:\d+(?:\.\d{0,12})?|\.\d{1,12})$').hasMatch(text.trim())) {
      return null;
    }
    final value = double.tryParse(text.trim());
    return value != null && value.isFinite && value > 0 && value <= 1e9
        ? value
        : null;
  }

  Future<void> simulate() async {
    if (busy || asset == null) return;
    final a = asset!, p = positive(price.text), q = positive(quantity.text);
    final cost = a.cost(a.currency), oldQuantity = a.quantity;
    if (p == null ||
        q == null ||
        p * q > 1e12 ||
        oldQuantity == null ||
        cost == null ||
        side == 'ขาย' && q > oldQuantity) {
      setState(
        () => error =
            side == 'ขาย' && q != null && oldQuantity != null && q > oldQuantity
            ? 'จำนวนขายต้องไม่มากกว่าจำนวนที่ถืออยู่'
            : 'กรอกราคาและจำนวนมากกว่า 0 ไม่เกิน 1,000,000,000 และตรวจว่าต้นทุนพร้อม',
      );
      return;
    }
    final before = {
      'quantity': oldQuantity,
      'remainingCost': cost,
      'averageCostPerUnit': a.average(a.currency),
    };
    if (side != 'ขาย') {
      final newQty = oldQuantity + q, newCost = cost + p * q;
      setState(() {
        error = null;
        result = {
          'before': before,
          'after': {
            'quantity': newQty,
            'remainingCost': newCost,
            'averageCostPerUnit': newCost / newQty,
          },
        };
      });
      return;
    }
    final snapshot = widget.store.revision;
    final today = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 7))
        .toIso8601String()
        .substring(0, 10);
    final input = <String, dynamic>{
      'assetType': a.type,
      'accountNumber': a.data['accountNumber'],
      'symbol': a.symbol,
      'exchange': a.data['exchange'],
      'currency': a.currency,
      'action': 'SELL',
      'quantity': q,
      'price': p,
      'tradeDate': today,
      if (revision != null) 'expectedSnapshotRevision': revision,
    };
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final response = await widget.store.api.jsonRequest(
        '/trades/simulate-sale',
        method: 'POST',
        body: input,
        timeout: const Duration(seconds: 90),
      );
      if (!mounted) return;
      if (snapshot != widget.store.revision || selected != a.key) {
        throw const ImportFailure('SIMULATION_SNAPSHOT_CHANGED');
      }
      if (response['simulationVersion'] != 1 ||
          response['persisted'] != false ||
          response['action'] != 'SELL' ||
          response['method'] !=
              const {
                'OFFSHORE_STOCK': 'COMPRESSED_FIFO',
                'THAI_STOCK': 'FIFO',
                'MUTUAL_FUND': 'MOVING_WEIGHTED_AVERAGE',
              }[a.type] ||
          response['feesIncluded'] != false ||
          response['taxesIncluded'] != false ||
          response['fxIncluded'] != false ||
          response['isComplete'] != (response['status'] == 'CALCULATED') ||
          !['CALCULATED', 'INCOMPLETE'].contains(response['status']) ||
          [
            'assetType',
            'accountNumber',
            'symbol',
            'exchange',
            'currency',
            'quantity',
            'price',
            'tradeDate',
          ].any((key) => response[key] != input[key]) ||
          !RegExp(r'^sim-v1:[a-f0-9]{32}$').hasMatch(
            textValue(objectMap(response['snapshot'])['revision']) ?? '',
          )) {
        throw const ImportFailure('INVALID_RESPONSE');
      }
      final beforeQty = finiteNumber(objectMap(response['before'])['quantity']);
      final beforeCost = finiteNumber(
        objectMap(response['before'])['remainingCost'],
      );
      if (beforeQty == null ||
          (beforeQty - oldQuantity).abs() > 1e-8 ||
          response['isComplete'] == true &&
              (beforeCost == null || (beforeCost - cost).abs() > .005)) {
        throw const ImportFailure('SIMULATION_SNAPSHOT_CHANGED');
      }
      setState(() {
        result = response;
        revision = objectMap(response['snapshot'])['revision'] as String;
      });
    } catch (failure) {
      if (mounted) {
        setState(
          () => error = failure is ImportFailure
              ? failure.message
              : 'คำนวณผลขายไม่สำเร็จ กรุณาลองใหม่',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget input(
    String label,
    TextEditingController controller,
    String currency,
  ) => TextField(
    controller: controller,
    enabled: !busy,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {
      result = null;
      error = null;
    }),
    decoration: InputDecoration(labelText: label, suffixText: currency),
  );
  @override
  Widget build(BuildContext context) {
    final store = widget.store, a = asset;
    final currency = a?.currency ?? '';
    final cost = a?.cost(currency),
        average = a?.average(currency),
        held = a?.quantity;
    final planPrice = positive(buyPrice.text),
        goal = positive(targetAverage.text),
        target = positive(targetPrice.text);
    final needed =
        cost != null && held != null && planPrice != null && goal != null
        ? average == goal
              ? 0.0
              : goal == planPrice
              ? null
              : (goal * held - cost) / (planPrice - goal)
        : null;
    final validPlan =
        needed != null && needed.isFinite && needed >= 0 && needed <= 1e9;
    final targetProfit = target != null && held != null && cost != null
        ? target * held - cost
        : null;
    final before = objectMap(result?['before']),
        after = objectMap(result?['after']);
    final afterAverage = finiteNumber(after['averageCostPerUnit']);
    final averageChange = afterAverage != null && average != null
        ? afterAverage - average
        : null;
    return FinanceList(
      key: const PageStorageKey('live-simulator'),
      children: [
        PageHeading(
          'Simulator',
          'วางแผนก่อนลงทุน · ไม่มีผลกับพอร์ตจริง',
          action: IconButton(
            tooltip: 'รีเฟรชข้อมูล',
            onPressed: store.loading || busy ? null : store.refresh,
            icon: const Icon(Icons.refresh, size: 20),
          ),
        ),
        if (store.error != null)
          DataNotice(store.error!, retry: store.refresh)
        else if (a == null)
          DataNotice(
            store.loading
                ? 'กำลังโหลดสินทรัพย์'
                : 'ยังไม่มีสินทรัพย์ที่ถืออยู่สำหรับจำลอง',
            loading: store.loading,
          )
        else ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  items: assets
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.key,
                          child: Text(
                            item.symbol,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (value) => setState(() => choose(value!)),
                  decoration: const InputDecoration(
                    labelText: 'เลือกสินทรัพย์ในพอร์ต',
                  ),
                ),
                const SizedBox(height: 18),
                twoColumns(
                  SmallStat('จำนวนที่ถือ', '${pdfNumber(held, 7)} ${a.unit}'),
                  SmallStat('ต้นทุนรวม', amount(cost, currency)),
                ),
                const SizedBox(height: 16),
                twoColumns(
                  SmallStat('ต้นทุนเฉลี่ย', amount(average, currency)),
                  SmallStat('ราคาตลาด', amount(a.price, currency)),
                ),
              ],
            ),
          ),
          ChoiceStrip(
            labels: const ['ซื้อ / ขาย', 'ต้นทุนเป้าหมาย', 'ราคาเป้าหมาย'],
            value: tool,
            onChanged: (value) {
              if (!busy) setState(() => tool = value);
            },
          ),
          if (tool == 'ซื้อ / ขาย') ...[
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'จำลองการซื้อ / ขาย',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  ChoiceStrip(
                    labels: const ['ซื้อเพิ่ม', 'ขาย'],
                    value: side,
                    onChanged: (value) {
                      if (!busy) {
                        setState(() {
                          side = value;
                          result = null;
                          error = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  input(
                    side == 'ขาย' ? 'ราคาขายต่อหน่วย' : 'ราคาซื้อต่อหน่วย',
                    price,
                    currency,
                  ),
                  const SizedBox(height: 14),
                  input('จำนวน${a.unit}', quantity, a.unit),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy ? null : simulate,
                    child: Text(busy ? 'กำลังคำนวณ…' : 'คำนวณผลจำลอง'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() {
                            quantity.clear();
                            result = null;
                            error = null;
                          }),
                    child: const Text('ล้างการจำลอง'),
                  ),
                ],
              ),
            ),
            if (error != null) DataNotice(error!),
            if (result != null)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'ผลการจำลอง',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    twoColumns(
                      _resultColumn('ก่อนจำลอง', before, currency, a.unit),
                      _resultColumn('หลังจำลอง', after, currency, a.unit),
                    ),
                    const SizedBox(height: 16),
                    if (side == 'ขาย') ...[
                      const Text(
                        'กำไร/ขาดทุนจากการขาย',
                        style: TextStyle(fontSize: 11, color: Colors.white54),
                      ),
                      LivePnl(
                        finiteNumber(result!['realizedPnl']),
                        currency: currency,
                        percent: finiteNumber(result!['realizedPnlPercent']),
                      ),
                      if (result!['isComplete'] != true)
                        const DataNotice(
                          'ข้อมูลต้นทุนบางส่วนยังไม่ครบ จึงยังคำนวณผลขายได้ไม่ครบ',
                        ),
                    ] else
                      Text(
                        'ต้นทุนเฉลี่ยเปลี่ยน ${percentage(ratioPercent(averageChange, average))}',
                        style: const TextStyle(fontSize: 12, color: lime),
                      ),
                  ],
                ),
              ),
          ] else if (tool == 'ต้นทุนเป้าหมาย')
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'อยากได้ต้นทุนเฉลี่ยเท่าไหร่',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  input('ราคาที่จะซื้อเพิ่มต่อหน่วย', buyPrice, currency),
                  const SizedBox(height: 14),
                  input('ต้นทุนเฉลี่ยเป้าหมาย', targetAverage, currency),
                  const SizedBox(height: 18),
                  if (!validPlan)
                    const DataNotice(
                      'กรอกราคาซื้อและต้นทุนเป้าหมาย โดยเป้าหมายต้องอยู่ระหว่างต้นทุนเดิมกับราคาที่ซื้อเพิ่ม จึงจะซื้อเพิ่มให้ถึงเป้าหมายได้',
                    )
                  else
                    twoColumns(
                      SmallStat(
                        'ต้องซื้อเพิ่ม',
                        '${pdfNumber(needed, 7)} ${a.unit}',
                      ),
                      SmallStat(
                        'ใช้เงินประมาณ',
                        amount(needed * planPrice!, currency),
                      ),
                    ),
                ],
              ),
            )
          else
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'ถ้าหุ้นถึงราคานี้',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  input('ราคาต่อหน่วยเป้าหมาย', targetPrice, currency),
                  const SizedBox(height: 18),
                  SmallStat(
                    'มูลค่าสินทรัพย์เมื่อถึงเป้าหมาย',
                    amount(
                      target != null && held != null ? target * held : null,
                      currency,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LivePnl(
                    targetProfit,
                    currency: currency,
                    percent: ratioPercent(targetProfit, cost),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _resultColumn(
    String title,
    Map<String, dynamic> values,
    String currency,
    String unit,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 12, color: Colors.white54)),
      const SizedBox(height: 12),
      SmallStat('จำนวนรวม', '${pdfNumber(values['quantity'], 7)} $unit'),
      const SizedBox(height: 12),
      SmallStat(
        'ต้นทุนรวม',
        amount(finiteNumber(values['remainingCost']), currency),
      ),
      const SizedBox(height: 12),
      SmallStat(
        'ต้นทุนเฉลี่ย',
        amount(finiteNumber(values['averageCostPerUnit']), currency),
      ),
    ],
  );
}
