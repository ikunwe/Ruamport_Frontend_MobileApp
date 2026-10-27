import 'package:flutter/material.dart';
import '../../core/demo/demo_portfolio.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/panel.dart';

class PortfolioPage extends StatefulWidget {
  const PortfolioPage({
    super.key,
    required this.thb,
    required this.onCurrency,
    required this.onAsset,
  });
  final bool thb;
  final ValueChanged<bool> onCurrency;
  final ValueChanged<DemoAsset> onAsset;
  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  AssetGroup group = AssetGroup.offshore;
  String sort = 'A–Z';
  String query = '';
  @override
  Widget build(BuildContext context) {
    final all = demoAssets.where((asset) => asset.group == group).toList();
    final assets = all
        .where(
          (asset) => asset.symbol.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    assets.sort(
      sort == 'A–Z'
          ? (a, b) => a.symbol.compareTo(b.symbol)
          : (a, b) => b.cost.compareTo(a.cost),
    );
    final useThb = group != AssetGroup.offshore || widget.thb;
    final currency = useThb ? 'THB' : 'USD';
    final value = sumOf(all, (a) => useThb ? a.thbValue : a.value);
    final cost = sumOf(all, (a) => useThb ? a.historicalCost : a.cost);
    final pnl = sumOf(all, (a) => useThb ? a.thbPricePnl : a.pnl);
    return FinanceList(
      key: const PageStorageKey('portfolio-list'),
      children: [
        const PageHeading('Portfolio', 'สินทรัพย์ทั้งหมดของคุณ'),
        ChoiceStrip(
          labels: groupNames.values.toList(),
          value: groupNames[group]!,
          onChanged: (v) => setState(
            () => group = groupNames.entries
                .firstWhere((entry) => entry.value == v)
                .key,
          ),
        ),
        if (group == AssetGroup.offshore)
          Align(
            alignment: Alignment.centerRight,
            child: ChoiceStrip(
              labels: const ['USD', 'THB'],
              value: widget.thb ? 'THB' : 'USD',
              onChanged: (v) => widget.onCurrency(v == 'THB'),
            ),
          ),
        Panel(
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${groupNames[group]} · มูลค่าสินทรัพย์',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  money(value, currency),
                  style: TextStyle(
                    fontSize: 30,
                    color: pnl >= 0 ? lime : loss,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PnlText(
                pnl,
                currency: currency,
                percentage: sumOf(all, (a) => a.cost) == 0
                    ? 0
                    : sumOf(all, (a) => a.pnl) /
                          sumOf(all, (a) => a.cost) *
                          100,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 15),
                child: Divider(height: 1),
              ),
              twoColumns(
                SmallStat('ต้นทุนรวมตามเอกสาร', money(cost, currency)),
                SmallStat('ซื้อสะสม', money(cost * 1.18, currency)),
              ),
              const SizedBox(height: 15),
              twoColumns(
                SmallStat('ขายสะสม', money(cost * .14, currency)),
                SmallStat(
                  'ค่าธรรมเนียมสะสม',
                  money(
                    sumOf(all, (a) => a.fees) *
                        (group == AssetGroup.offshore && useThb
                            ? demoHistoricalFx
                            : 1),
                    currency,
                  ),
                ),
              ),
            ],
          ),
        ),
        TextField(
          onChanged: (value) => setState(() => query = value),
          decoration: const InputDecoration(
            hintText: 'ค้นหาสินทรัพย์',
            prefixIcon: Icon(Icons.search, size: 20),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'รายการถือครอง (${assets.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            DropdownButton<String>(
              value: sort,
              underline: const SizedBox(),
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'Kanit',
                color: Colors.white,
              ),
              iconEnabledColor: Colors.white70,
              dropdownColor: surface,
              items: const [
                DropdownMenuItem(value: 'A–Z', child: Text('ชื่อ A–Z')),
                DropdownMenuItem(
                  value: 'ต้นทุน',
                  child: Text('ต้นทุนมาก → น้อย'),
                ),
              ],
              onChanged: (value) => setState(() => sort = value!),
            ),
          ],
        ),
        if (assets.isEmpty)
          const Panel(
            child: Text(
              'ไม่พบสินทรัพย์ที่ค้นหา',
              style: TextStyle(color: Colors.white38),
            ),
          ),
        ...assets.map((asset) {
          final current = useThb ? asset.thbValue : asset.value;
          final currentCost = useThb ? asset.historicalCost : asset.cost;
          final assetPnl = useThb ? asset.thbPricePnl : asset.pnl;
          return InkWell(
            key: ValueKey('holding-${asset.symbol}'),
            onTap: () => widget.onAsset(asset),
            borderRadius: BorderRadius.circular(8),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AssetAvatar(asset),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              asset.symbol,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${asset.market}  ·  ${number(asset.thbValue / sumOf(all, (a) => a.thbValue) * 100, 1)}%',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.white30,
                        size: 19,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  twoColumns(
                    SmallStat(
                      'มูลค่าสินทรัพย์',
                      money(current, currency),
                      color: assetPnl >= 0 ? lime : loss,
                    ),
                    SmallStat('ต้นทุนรวม', money(currentCost, currency)),
                  ),
                  const SizedBox(height: 14),
                  PnlText(
                    assetPnl,
                    currency: currency,
                    percentage: asset.pnlPercent,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Divider(height: 1),
                  ),
                  twoColumns(
                    SmallStat(
                      'ถือ ${units(asset.quantity)} ${asset.unit}',
                      'เฉลี่ย ${money(useThb && group == AssetGroup.offshore ? asset.average * demoHistoricalFx : asset.average, currency)}',
                    ),
                    SmallStat(
                      asset.group == AssetGroup.fund ? 'NAV' : 'ราคาต่อหุ้น',
                      money(
                        useThb && group == AssetGroup.offshore
                            ? asset.price * demoFx
                            : asset.price,
                        currency,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${percent(asset.dailyPercent)} จากวันก่อนหน้า · แหล่งอ้างอิงตัวอย่าง',
                    style: TextStyle(
                      fontSize: 9,
                      color: asset.dailyPercent >= 0 ? lime : loss,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
