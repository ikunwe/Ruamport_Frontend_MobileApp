import 'package:flutter/material.dart';
import '../../core/network/backend_cancellation.dart';
import '../import/import_api.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/panel.dart';
import '../import/import_models.dart';
import '../import/pdf_preview_view.dart';
import 'portfolio_data.dart';
import 'portfolio_store.dart';
import 'live_finance_ui.dart';

class LiveStockPage extends StatefulWidget {
  const LiveStockPage({super.key, required this.store, required this.asset});
  final PortfolioStore store;
  final Holding asset;
  @override
  State<LiveStockPage> createState() => _LiveStockPageState();
}

class _LiveStockPageState extends State<LiveStockPage> {
  late String selected = widget.asset.key;
  String filter = 'ทั้งหมด';
  List<Map<String, dynamic>>? rows;
  String? error;
  int request = 0;
  BackendCancellation? historyCancellation;
  @override
  void dispose() {
    historyCancellation?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  Holding get asset =>
      widget.store.data?.items
          .where((item) => item.key == selected)
          .firstOrNull ??
      widget.asset;
  Future<void> load() async {
    historyCancellation?.cancel();
    final cancel = historyCancellation = BackendCancellation();
    final id = ++request;
    setState(() {
      rows = null;
      error = null;
    });
    try {
      final value = await widget.store.transactions(asset, cancel: cancel);
      if (mounted && id == request) setState(() => rows = value);
    } catch (failure) {
      if (mounted && id == request) {
        setState(
          () => error = failure is ImportFailure
              ? failure.message
              : 'โหลดประวัติซื้อขายไม่สำเร็จ กรุณาลองใหม่',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final a = asset;
      final currency = a.offshore && !store.thb ? 'USD' : 'THB';
      // Snapshot ต้นทุนที่แปลง THB ใช้ displayThb เหมือนหน้า Stock ของเว็บ
      // ซื้อ/ขายสะสมและรายการซื้อขายยังใช้ยอดตามเอกสารเดิม
      final costRow = a.offshore && currency == 'THB'
          ? store.data?.rate != null
                ? objectMap(objectMap(a.data['displayThb'])['costBasis'])
                : <String, dynamic>{}
          : a.costRow(currency);
      final remainingCost = costRow['status'] == 'CALCULATED'
          ? finiteNumber(costRow['remainingCost'])
          : null;
      final averageCost = costRow['status'] == 'CALCULATED'
          ? finiteNumber(costRow['averageCostPerUnit'])
          : null;
      final bought = rows
          ?.where(
            (row) => ['BUY', 'SUBSCRIPTION'].contains(row['transaction_type']),
          )
          .length;
      final sold = rows
          ?.where(
            (row) => ['SELL', 'REDEMPTION'].contains(row['transaction_type']),
          )
          .length;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Stock', style: TextStyle(fontSize: 17)),
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: FinanceList(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    isExpanded: true,
                    items: (store.data?.items ?? [a])
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
                    onChanged: (value) {
                      setState(() {
                        selected = value!;
                        store.selectedKey = selected;
                      });
                      load();
                    },
                    decoration: const InputDecoration(
                      labelText: 'เลือกสินทรัพย์',
                    ),
                  ),
                  Panel(
                    accent: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            HoldingLogo(a, size: 44),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.symbol,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${assetTypes[a.type]} · ${a.market}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          a.held
                              ? '● กำลังถือครอง'
                              : a.data['status'] == 'CLOSED'
                              ? '● ปิดรายการแล้ว'
                              : '● จำนวนถือครองต้องตรวจสอบ',
                          style: TextStyle(
                            color: a.held ? lime : Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          'ต้นทุนต่อ${a.unit} ${amount(averageCost, currency)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                        if (a.offshore) ...[
                          const SizedBox(height: 14),
                          ChoiceStrip(
                            labels: const ['USD', 'THB'],
                            value: currency,
                            onChanged: (value) =>
                                store.currency(value == 'THB'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  twoColumns(
                    MetricTile(
                      'จำนวนที่ถือ',
                      '${pdfNumber(a.quantity, 7)} ${a.unit}',
                    ),
                    MetricTile('ต้นทุนรวม', amount(remainingCost, currency)),
                  ),
                  twoColumns(
                    MetricTile(
                      'ซื้อสะสม${bought == null ? '' : ' ($bought รายการ)'}',
                      amount(a.buy(currency), currency),
                    ),
                    MetricTile(
                      'ขายสะสม${sold == null ? '' : ' ($sold รายการ)'}',
                      amount(a.sell(currency), currency),
                    ),
                  ),
                  if (a.type == 'MUTUAL_FUND')
                    twoColumns(
                      MetricTile(
                        'มูลค่าสับเปลี่ยนเข้าสะสม',
                        amount(a.fundSwitchIn),
                      ),
                      MetricTile(
                        'มูลค่าสับเปลี่ยนออกสะสม',
                        amount(a.fundSwitchOut),
                      ),
                    ),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'ประวัติซื้อขาย',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ChoiceStrip(
                          labels: const ['ทั้งหมด', 'ซื้อ', 'ขาย'],
                          value: filter,
                          onChanged: (value) => setState(() => filter = value),
                        ),
                        const SizedBox(height: 14),
                        if (error != null)
                          DataNotice(error!, retry: load)
                        else if (rows == null)
                          const DataNotice(
                            'กำลังโหลดประวัติซื้อขาย',
                            loading: true,
                          )
                        else ...[
                          if (rows!.isEmpty)
                            const Text(
                              'ยังไม่มีประวัติซื้อขายของสินทรัพย์นี้',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          for (final row in rows!.where(
                            (row) =>
                                filter == 'ทั้งหมด' ||
                                (filter == 'ซื้อ'
                                        ? ['BUY', 'SUBSCRIPTION', 'SWITCH_IN']
                                        : ['SELL', 'REDEMPTION', 'SWITCH_OUT'])
                                    .contains(row['transaction_type']),
                          ))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          transactionLabel(
                                            row['transaction_type'],
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _transactionColor(
                                              row['transaction_type'],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        textValue(row['trade_date']) ?? '—',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white38,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${pdfNumber(row['units'], 7)} ${a.unit} × ${pdfMoney(row['unit_price'], textValue(row['currency']) ?? a.currency, 4)}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    pdfMoney(
                                      _transactionAmount(row),
                                      textValue(row['currency']) ?? a.currency,
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  Object? _transactionAmount(Map<String, dynamic> row) {
    final value = objectMap(row['details'])['totalAmount'];
    return value is num ? value : objectMap(value)['foreign'];
  }

  Color _transactionColor(Object? type) {
    if (['BUY', 'SUBSCRIPTION', 'SWITCH_IN'].contains(type)) return lime;
    if (['SELL', 'REDEMPTION', 'SWITCH_OUT'].contains(type)) return loss;
    return Colors.white70;
  }
}
