import 'package:flutter/material.dart';
import '../../core/demo/demo_portfolio.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/finance_charts.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/panel.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});
  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String category = 'ทั้งพอร์ต',
      range = '1Y',
      market = 'S&P 500',
      interval = 'รายเดือน',
      detail = 'ถืออยู่';
  int selectedPeriod = 5;
  static const markets = ['S&P 500', 'NASDAQ', 'SET', 'SET50'];
  @override
  Widget build(BuildContext context) {
    final group = AssetGroup.values
        .where((g) => groupNames[g] == category)
        .firstOrNull;
    final assets = demoAssets
        .where((a) => group == null || a.group == group)
        .toList();
    final showFx = group == null || group == AssetGroup.offshore;
    final price = sumOf(assets, (a) => a.thbPricePnl),
        realized = sumOf(assets, (a) => a.realized),
        fx = sumOf(assets, (a) => a.fxPnl);
    final marketScale = [.64, .82, .42, .48][markets.indexOf(market)];
    final periodReturn = demoSeries(range).last;
    final contributions = assets
        .where((a) => detail != 'ค่าเงิน' || a.group == AssetGroup.offshore)
        .toList();
    double contribution(DemoAsset asset) => detail == 'ขายแล้ว'
        ? asset.realized
        : detail == 'ค่าเงิน'
        ? asset.fxPnl
        : asset.thbPricePnl;
    contributions.sort((a, b) => contribution(b).compareTo(contribution(a)));
    return FinanceList(
      key: const PageStorageKey('analytics-list'),
      children: [
        const PageHeading('Analytics', 'เข้าใจการเติบโตและที่มาของผลตอบแทน'),
        ChoiceStrip(
          labels: ['ทั้งพอร์ต', ...groupNames.values],
          value: category,
          onChanged: (v) => setState(() {
            category = v;
            market = v == 'หุ้นไทย' ? 'SET' : 'S&P 500';
            if (v != 'ทั้งพอร์ต' && v != 'หุ้นนอก' && detail == 'ค่าเงิน') {
              detail = 'ถืออยู่';
            }
          }),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your port vs Market',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'เปรียบเทียบการเติบโต · ตัวอย่างผลตอบแทน (%)',
                style: TextStyle(fontSize: 10, color: Colors.white38),
              ),
              const SizedBox(height: 18),
              twoColumns(
                SmallStat(
                  'พอร์ตของคุณ · $category',
                  percent(periodReturn),
                  color: lime,
                ),
                SmallStat(
                  market,
                  percent(periodReturn * marketScale + .15),
                  color: blue,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'เทียบกับ',
                    style: TextStyle(fontSize: 11, color: Colors.white38),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String>(
                      value: market,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: surface,
                      style: const TextStyle(fontFamily: 'Kanit', fontSize: 12),
                      items: markets
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => market = v!),
                    ),
                  ),
                ],
              ),
              FinanceChart(
                period: range,
                comparison: true,
                marketScale: marketScale,
              ),
              const SizedBox(height: 16),
              ChoiceStrip(
                labels: const ['1M', '3M', '1Y', 'ALL'],
                value: range,
                onChanged: (v) => setState(() => range = v),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'อัตราชนะตลาด',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'Win rate · ข้อมูลตัวอย่างตามช่วงที่เลือก',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
              const SizedBox(height: 15),
              ChoiceStrip(
                labels: const ['รายสัปดาห์', 'รายเดือน', 'รายปี'],
                value: interval,
                onChanged: (v) => setState(() => interval = v),
              ),
              const SizedBox(height: 18),
              twoColumns(
                SmallStat('ชนะ $market', '4 / 6 ช่วง', color: lime),
                const SmallStat('Win rate', '66.67%', color: lime),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(6, (i) {
                  final win = i != 1 && i != 4;
                  return InkWell(
                    onTap: () => setState(() => selectedPeriod = i),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 74,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (win ? lime : loss).withValues(alpha: .04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selectedPeriod == i
                              ? Colors.white54
                              : Colors.white10,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            interval == 'รายเดือน'
                                ? [
                                    'เม.ย.',
                                    'พ.ค.',
                                    'มิ.ย.',
                                    'ก.ค.',
                                    'ส.ค.',
                                    'ก.ย.',
                                  ][i]
                                : 'ช่วง ${i + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Icon(
                            win ? Icons.trending_up : Icons.trending_down,
                            size: 19,
                            color: win ? lime : loss,
                          ),
                          Text(
                            win ? 'ชนะ' : 'แพ้',
                            style: TextStyle(
                              fontSize: 10,
                              color: win ? lime : loss,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .035),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: twoColumns(
                  SmallStat(
                    'พอร์ต · ช่วง ${selectedPeriod + 1}',
                    percent(
                      selectedPeriod == 1 || selectedPeriod == 4 ? .8 : 2.4,
                    ),
                    color: lime,
                  ),
                  SmallStat(market, '+1.20%', color: blue),
                ),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ที่มาของกำไร / ขาดทุน',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              PnlText(price + fx + realized, size: 22),
              const SizedBox(height: 18),
              ...[
                ('ราคาสินทรัพย์ที่ยังถือ', price, lime),
                if (showFx) ('ค่าเงินหุ้นนอก', fx, blue),
                ('กำไร/ขาดทุนที่ขายแล้ว', realized, violet),
              ].map(
                (part) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              part.$1,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white60,
                              ),
                            ),
                          ),
                          Text(
                            signedMoney(part.$2),
                            style: TextStyle(
                              fontSize: 11,
                              color: part.$2 >= 0 ? part.$3 : loss,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value:
                              (part.$2.abs() /
                                      (price.abs() + fx.abs() + realized.abs()))
                                  .clamp(0, 1),
                          color: part.$3,
                          backgroundColor: Colors.white10,
                          minHeight: 4,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'สินทรัพย์ที่ส่งผลต่อพอร์ต',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              ChoiceStrip(
                labels: ['ถืออยู่', 'ขายแล้ว', if (showFx) 'ค่าเงิน'],
                value: detail,
                onChanged: (v) => setState(() => detail = v),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: contributions.length > 4
                    ? 260
                    : contributions.length * 65.0,
                child: ListView.builder(
                  primary: false,
                  itemCount: contributions.length,
                  itemBuilder: (context, index) {
                    final asset = contributions[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        children: [
                          AssetAvatar(asset, size: 30),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              asset.symbol,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            signedMoney(contribution(asset)),
                            style: TextStyle(
                              fontSize: 11,
                              color: contribution(asset) >= 0 ? lime : loss,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Text(
                detail == 'ขายแล้ว'
                    ? 'รวมขายบางส่วนและขายหมด · ก่อนค่าธรรมเนียมและภาษี'
                    : 'ตัวเลขสมมติสำหรับออกแบบ UI เท่านั้น',
                style: const TextStyle(color: Colors.white30, fontSize: 9),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
