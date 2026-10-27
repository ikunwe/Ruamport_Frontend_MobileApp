import 'package:flutter/material.dart';
import '../../core/demo/demo_portfolio.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/panel.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/finance_charts.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({
    super.key,
    required this.onImport,
    required this.onAnalytics,
    required this.onAsset,
    this.userName = 'ผู้ใช้งานตัวอย่าง',
    this.importPreviewed = false,
  });
  final VoidCallback onImport, onAnalytics;
  final ValueChanged<DemoAsset> onAsset;
  final String userName;
  final bool importPreviewed;
  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  String period = '1M', allocation = 'ทั้งพอร์ต';
  @override
  Widget build(BuildContext context) {
    final value = sumOf(demoAssets, (asset) => asset.thbValue);
    final cost = sumOf(demoAssets, (asset) => asset.historicalCost);
    final pricePnl = sumOf(demoAssets, (asset) => asset.thbPricePnl);
    final fx = sumOf(demoAssets, (asset) => asset.fxPnl);
    final realized = sumOf(demoAssets, (asset) => asset.realized);
    final totalPnl = pricePnl + fx + realized;
    final groups = ['ทั้งพอร์ต', ...groupNames.values];
    final group = AssetGroup.values
        .where((g) => groupNames[g] == allocation)
        .firstOrNull;
    final ringAssets = demoAssets
        .where((asset) => group == null || asset.group == group)
        .toList();
    final ringLabels = group == null
        ? groupNames.values.toList()
        : ringAssets.map((a) => a.symbol).toList();
    final ringValues = group == null
        ? AssetGroup.values
              .map(
                (g) => sumOf(
                  demoAssets.where((a) => a.group == g),
                  (a) => a.thbValue,
                ),
              )
              .toList()
        : ringAssets.map((a) => a.thbValue).toList();
    final movers = [...demoAssets]
      ..sort((a, b) => b.dailyPercent.compareTo(a.dailyPercent));
    final shown = [...movers.take(2), ...movers.skip(movers.length - 2)];
    return FinanceList(
      key: const PageStorageKey('overview-list'),
      children: [
        PageHeading(
          'สวัสดี, ${widget.userName}',
          'OVERVIEW · ภาพรวมการลงทุนของคุณ',
        ),
        if (!widget.importPreviewed)
          Panel(
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, color: lime, size: 21),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'นี่เป็นข้อมูลพอร์ตตัวอย่าง\nลองดูการนำเข้าข้อมูลผ่าน PDF หรือ Sync',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.7,
                      color: Colors.white60,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'นำเข้าข้อมูล',
                  onPressed: widget.onImport,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                ),
              ],
            ),
          ),
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
                alignment: Alignment.centerLeft,
                child: Text(
                  money(value),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: lime,
                    letterSpacing: -.7,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '≈ ${money(value / demoFx, 'USD')}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const SizedBox(height: 12),
              const PnlText(432.15, percentage: .41, size: 11),
              FinanceChart(period: period),
              const SizedBox(height: 16),
              ChoiceStrip(
                labels: const ['1D', '1W', '1M', '3M', '1Y', 'ALL'],
                value: period,
                onChanged: (v) => setState(() => period = v),
              ),
              const SizedBox(height: 12),
              const Text(
                'หุ้นนอก / หุ้นไทย / NAV · เวลาอ้างอิงเป็นข้อมูลตัวอย่าง',
                style: TextStyle(color: Colors.white30, fontSize: 9),
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
          // ใช้ความสูงเดียวกันทุกกรอบ เผื่อข้อความขึ้นบรรทัดใหม่บนจอแคบ
          mainAxisExtent:
              (MediaQuery.sizeOf(context).width < 360 ? 144 : 128) *
              (MediaQuery.textScalerOf(context).scale(18) / 18).clamp(
                1.0,
                double.infinity,
              ),
          children: [
            MetricTile('ต้นทุนรวมตามเอกสาร', money(cost)),
            MetricTile(
              'กำไร/ขาดทุนทั้งหมด',
              signedMoney(totalPnl),
              hint: 'รวมสินทรัพย์ ค่าเงิน และขายแล้ว',
              color: lime,
            ),
            MetricTile(
              'Unrealized P&L',
              signedMoney(pricePnl + fx),
              hint: 'ส่วนที่ยังถือ รวมค่าเงิน',
              color: lime,
            ),
            MetricTile(
              'Realized P&L',
              signedMoney(realized),
              hint: 'กำไร/ขาดทุนที่ขายแล้ว',
              color: lime,
            ),
            MetricTile('กำไรจากสินทรัพย์', signedMoney(pricePnl), color: lime),
            MetricTile(
              'กำไร/ขาดทุนค่าเงิน',
              signedMoney(fx),
              hint: 'เรทต้นทุนเฉลี่ย 32.64 THB',
              color: lime,
            ),
          ],
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'สัดส่วนสินทรัพย์',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              ChoiceStrip(
                labels: groups,
                value: allocation,
                onChanged: (v) => setState(() => allocation = v),
              ),
              const SizedBox(height: 20),
              AllocationRing(labels: ringLabels, values: ringValues),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '% เปลี่ยนแปลงจากวันก่อนหน้ามากสุด',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              ...shown.map(
                (asset) => InkWell(
                  onTap: () => widget.onAsset(asset),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        AssetAvatar(asset, size: 32),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                asset.symbol,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                money(asset.price, asset.currency),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white38,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          percent(asset.dailyPercent),
                          style: TextStyle(
                            color: asset.dailyPercent >= 0 ? lime : loss,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              ...[('Your port', 9.37), ('S&P 500', 7.14), ('NASDAQ', 5.82)].map(
                (row) => Padding(
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
                            percent(row.$2),
                            style: const TextStyle(color: lime, fontSize: 11),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: row.$2 / 12,
                          minHeight: 5,
                          backgroundColor: Colors.white10,
                          color: lime,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const Text(
          'ตัวอย่าง UI เท่านั้น · ไม่ใช่ผลตอบแทนของบัญชีจริง',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.white30),
        ),
      ],
    );
  }
}
