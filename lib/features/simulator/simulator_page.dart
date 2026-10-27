import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/demo/demo_portfolio.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/panel.dart';

class SimulatorPage extends StatefulWidget {
  const SimulatorPage({super.key});
  @override
  State<SimulatorPage> createState() => _SimulatorPageState();
}

class _SimulatorPageState extends State<SimulatorPage> {
  DemoAsset asset = demoAssets.first;
  String tool = 'ซื้อ / ขาย', side = 'ซื้อเพิ่ม';
  late final TextEditingController price = TextEditingController(
    text: '${asset.price}',
  );
  final quantity = TextEditingController();
  late final TextEditingController planPrice = TextEditingController(
    text: '${asset.price}',
  );
  final desired = TextEditingController();
  late final TextEditingController targetPrice = TextEditingController(
    text: '${asset.price}',
  );
  @override
  void initState() {
    super.initState();
    for (final controller in [
      price,
      quantity,
      planPrice,
      desired,
      targetPrice,
    ]) {
      controller.addListener(update);
    }
  }

  void update() => setState(() {});
  @override
  void dispose() {
    for (final controller in [
      price,
      quantity,
      planPrice,
      desired,
      targetPrice,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? positive(TextEditingController controller) {
    final value = double.tryParse(controller.text);
    return value != null && value.isFinite && value > 0 && value <= 1e9
        ? value
        : null;
  }

  Widget field(String label, TextEditingController controller) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, suffixText: asset.currency),
  );
  void choose(DemoAsset value) {
    setState(() {
      asset = value;
      price.text = '${value.price}';
      planPrice.text = '${value.price}';
      targetPrice.text = '${value.price}';
      quantity.clear();
      desired.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = positive(price),
        q = positive(quantity),
        goalPrice = positive(targetPrice),
        buyPrice = positive(planPrice),
        averageGoal = positive(desired);
    final sell = side == 'ขาย';
    final valid = p != null && q != null && (!sell || q <= asset.quantity);
    // Fictional local lots for demonstrating the UI only. Backend will own production FIFO calculations.
    final firstLot = asset.quantity * .4, firstCost = asset.average * .8;
    final remainingUnitCost =
        (asset.cost - firstLot * firstCost) / (asset.quantity - firstLot);
    final soldCost = valid
        ? (asset.group == AssetGroup.fund
              ? asset.average * q
              : math.min(q, firstLot) * firstCost +
                    math.max(0, q - firstLot) * remainingUnitCost)
        : 0.0;
    final nextQty = valid
        ? (sell ? asset.quantity - q : asset.quantity + q)
        : asset.quantity;
    final nextCost = valid
        ? (sell ? math.max(0.0, asset.cost - soldCost) : asset.cost + p * q)
        : asset.cost;
    final nextAverage = nextQty > 0 ? nextCost / nextQty : null;
    final sellPnl = valid ? p * q - soldCost : 0.0;
    final canPlan =
        buyPrice != null &&
        averageGoal != null &&
        (averageGoal == asset.average ||
            averageGoal > math.min(buyPrice, asset.average) &&
                averageGoal < math.max(buyPrice, asset.average));
    final neededQty = canPlan
        ? (averageGoal == asset.average
              ? 0.0
              : (asset.cost - averageGoal * asset.quantity) /
                    (averageGoal - buyPrice))
        : null;
    final validPlan =
        neededQty != null &&
        neededQty.isFinite &&
        neededQty >= 0 &&
        neededQty <= 1e9;
    return FinanceList(
      key: const PageStorageKey('simulator-list'),
      children: [
        const PageHeading('Simulator', 'วางแผนก่อนลงทุน · ไม่มีผลกับพอร์ตจริง'),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<DemoAsset>(
                initialValue: asset,
                isExpanded: true,
                items: demoAssets
                    .map(
                      (a) => DropdownMenuItem(
                        value: a,
                        child: Text(a.symbol, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (a) => choose(a!),
                decoration: const InputDecoration(
                  labelText: 'เลือกสินทรัพย์ในพอร์ตตัวอย่าง',
                ),
              ),
              const SizedBox(height: 18),
              twoColumns(
                SmallStat(
                  'จำนวนที่ถือ',
                  '${units(asset.quantity)} ${asset.unit}',
                ),
                SmallStat('ต้นทุนรวม', money(asset.cost, asset.currency)),
              ),
              const SizedBox(height: 16),
              twoColumns(
                SmallStat('ต้นทุนเฉลี่ย', money(asset.average, asset.currency)),
                SmallStat(
                  'ราคาตลาดตัวอย่าง',
                  money(asset.price, asset.currency),
                ),
              ),
            ],
          ),
        ),
        ChoiceStrip(
          labels: const ['ซื้อ / ขาย', 'ต้นทุนเป้าหมาย', 'ราคาเป้าหมาย'],
          value: tool,
          onChanged: (v) => setState(() => tool = v),
        ),
        if (tool == 'ซื้อ / ขาย') ...[
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'จำลองการซื้อ / ขาย',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                ChoiceStrip(
                  labels: const ['ซื้อเพิ่ม', 'ขาย'],
                  value: side,
                  onChanged: (v) => setState(() => side = v),
                ),
                const SizedBox(height: 18),
                field(sell ? 'ราคาขายต่อหน่วย' : 'ราคาซื้อต่อหน่วย', price),
                const SizedBox(height: 14),
                TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'จำนวน${asset.unit}',
                    suffixText: asset.unit,
                  ),
                ),
                if (sell && q != null && q > asset.quantity)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'จำนวนขายมากกว่าจำนวนที่ถืออยู่',
                      style: TextStyle(color: loss, fontSize: 11),
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      price.clear();
                      quantity.clear();
                    },
                    child: const Text(
                      'ล้างการจำลอง',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (valid)
            Panel(
              accent: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sell ? 'ผลจำลองการขาย' : 'เปรียบเทียบก่อน – หลังซื้อ',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  twoColumns(
                    SmallStat(
                      'ก่อนจำลอง · ต้นทุนเฉลี่ย',
                      money(asset.average, asset.currency),
                    ),
                    SmallStat(
                      'หลังจำลอง · ต้นทุนเฉลี่ย',
                      nextAverage == null
                          ? '—'
                          : money(nextAverage, asset.currency),
                      color: lime,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1),
                  ),
                  twoColumns(
                    SmallStat('จำนวนใหม่', '${units(nextQty)} ${asset.unit}'),
                    SmallStat('ต้นทุนรวมใหม่', money(nextCost, asset.currency)),
                  ),
                  const SizedBox(height: 20),
                  if (sell)
                    PnlText(
                      sellPnl,
                      currency: asset.currency,
                      percentage: soldCost > 0
                          ? sellPnl / soldCost * 100
                          : null,
                    )
                  else
                    Text(
                      'ต้นทุนเฉลี่ย ${nextAverage! < asset.average ? 'ลดลง' : 'เพิ่มขึ้น'} ${number((nextAverage / asset.average - 1).abs() * 100)}%',
                      style: const TextStyle(color: lime, fontSize: 13),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    '${sell ? 'เงินขายก่อนค่าธรรมเนียม' : 'เงินที่ใช้ซื้อเพิ่ม'} ${money(p * q, asset.currency)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                  if (sell)
                    const Padding(
                      padding: EdgeInsets.only(top: 9),
                      child: Text(
                        'ตัวอย่างล็อตสมมติ · ยังไม่ใช้ผลคำนวณจาก Backend',
                        style: TextStyle(fontSize: 9, color: Colors.white30),
                      ),
                    ),
                ],
              ),
            )
          else
            const Panel(
              child: Text(
                'กรอกราคาและจำนวนมากกว่า 0 เพื่อดูผลก่อนและหลังจำลอง',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
            ),
        ],
        if (tool == 'ต้นทุนเป้าหมาย')
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'อยากได้ต้นทุนเฉลี่ยเท่าไหร่?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                const Text(
                  'หาจำนวนที่จะซื้อเพิ่ม และเงินที่ต้องใช้',
                  style: TextStyle(fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(height: 20),
                field('ราคาที่จะซื้อเพิ่ม', planPrice),
                const SizedBox(height: 15),
                field('ต้นทุนเฉลี่ยที่ต้องการ', desired),
                const SizedBox(height: 20),
                if (validPlan) ...[
                  twoColumns(
                    SmallStat(
                      'ต้องซื้อเพิ่มประมาณ',
                      '${units(neededQty)} ${asset.unit}',
                      color: lime,
                    ),
                    SmallStat(
                      'เงินที่ใช้ประมาณ',
                      money(neededQty * buyPrice!, asset.currency),
                      color: lime,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'ต้นทุนเฉลี่ยหลังซื้อ ${money(averageGoal!, asset.currency)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                ] else
                  Text(
                    averageGoal == null
                        ? 'กรอกต้นทุนเฉลี่ยเป้าหมายเพื่อดูผล'
                        : 'เป้าหมายต้องอยู่ระหว่างต้นทุนเดิม ${number(asset.average)} กับราคาซื้อเพิ่ม ลองเปลี่ยนราคาหรือเป้าหมาย',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      height: 1.7,
                    ),
                  ),
              ],
            ),
          ),
        if (tool == 'ราคาเป้าหมาย')
          Panel(
            accent: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ถ้าสินทรัพย์ถึงราคานี้',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 7),
                Text(
                  'คิดจากจำนวนเดิม ${units(asset.quantity)} ${asset.unit}',
                  style: const TextStyle(fontSize: 11, color: Colors.white38),
                ),
                const SizedBox(height: 20),
                field('ราคาเป้าหมายต่อหน่วย', targetPrice),
                if (goalPrice != null) ...[
                  const SizedBox(height: 24),
                  SmallStat(
                    'มูลค่าสินทรัพย์ที่ราคาเป้าหมาย',
                    money(goalPrice * asset.quantity, asset.currency),
                  ),
                  const SizedBox(height: 18),
                  PnlText(
                    goalPrice * asset.quantity - asset.cost,
                    currency: asset.currency,
                    percentage: (goalPrice / asset.average - 1) * 100,
                    size: 18,
                  ),
                ],
              ],
            ),
          ),
        const Text(
          'UI ตัวอย่างเท่านั้น · ไม่รวมค่าธรรมเนียม ภาษี หรือผลค่าเงิน\nไม่มีการส่งคำสั่งซื้อขายและไม่แก้พอร์ตจริง',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, height: 1.7, color: Colors.white30),
        ),
      ],
    );
  }
}
