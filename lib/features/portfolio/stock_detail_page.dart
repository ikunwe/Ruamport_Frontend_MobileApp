import 'package:flutter/material.dart';
import '../../core/demo/demo_portfolio.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/panel.dart';
import '../../shared/widgets/finance_ui.dart';

class StockDetailPage extends StatefulWidget {
  const StockDetailPage({
    super.key,
    required this.asset,
    required this.thb,
    required this.onCurrency,
  });
  final DemoAsset asset;
  final bool thb;
  final ValueChanged<bool> onCurrency;
  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage> {
  late DemoAsset asset = widget.asset;
  late bool thb = widget.thb;
  String filter = 'ทั้งหมด';
  @override
  Widget build(BuildContext context) {
    final useThb = thb && asset.group == AssetGroup.offshore;
    final currency = useThb ? 'THB' : asset.currency;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock', style: TextStyle(fontSize: 17)),
        backgroundColor: const Color(0xFF070807),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: FinanceList(
              children: [
                DropdownButtonFormField<DemoAsset>(
                  initialValue: asset,
                  isExpanded: true,
                  items: demoAssets
                      .map(
                        (a) => DropdownMenuItem(
                          value: a,
                          child: Text(
                            a.symbol,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (a) => setState(() => asset = a!),
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
                          AssetAvatar(asset, size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  asset.symbol,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${groupNames[asset.group]} · ${asset.market}',
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
                      const Text(
                        '● กำลังถือครอง',
                        style: TextStyle(color: lime, fontSize: 10),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        'ต้นทุนต่อ${asset.unit} ${money(asset.average * (useThb ? demoHistoricalFx : 1), currency)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                      if (asset.group == AssetGroup.offshore) ...[
                        const SizedBox(height: 14),
                        ChoiceStrip(
                          labels: const ['USD', 'THB'],
                          value: thb ? 'THB' : 'USD',
                          onChanged: (value) {
                            setState(() => thb = value == 'THB');
                            widget.onCurrency(thb);
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                twoColumns(
                  MetricTile(
                    'จำนวนที่ถือ',
                    '${units(asset.quantity)} ${asset.unit}',
                  ),
                  MetricTile(
                    'ต้นทุนรวม',
                    money(useThb ? asset.historicalCost : asset.cost, currency),
                  ),
                ),
                twoColumns(
                  MetricTile(
                    'ซื้อสะสม (4 รายการ)',
                    money(
                      asset.cost * 1.18 * (useThb ? demoHistoricalFx : 1),
                      currency,
                    ),
                  ),
                  MetricTile(
                    'ขายสะสม (1 รายการ)',
                    money(
                      asset.cost * .14 * (useThb ? demoHistoricalFx : 1),
                      currency,
                    ),
                  ),
                ),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                        onChanged: (v) => setState(() => filter = v),
                      ),
                      const SizedBox(height: 14),
                      ...List.generate(5, (index) {
                        final sell = index == 1;
                        if ((filter == 'ซื้อ' && sell) ||
                            (filter == 'ขาย' && !sell)) {
                          return const SizedBox.shrink();
                        }
                        final price = asset.average * (1 + index * .03);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    sell ? Icons.north_east : Icons.south_west,
                                    color: sell ? loss : lime,
                                    size: 17,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      sell ? 'ขาย' : 'ซื้อ',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: sell ? loss : lime,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${12 + index}/09/2026',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${units(asset.quantity / 4)} ${asset.unit} × ${money(price, asset.currency)}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    money(
                                      price * asset.quantity / 4,
                                      asset.currency,
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                            ],
                          ),
                        );
                      }),
                      const Text(
                        'รายการสมมติสำหรับแสดง UI · คงสกุลเงินของรายการเดิม',
                        style: TextStyle(fontSize: 9, color: Colors.white30),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
