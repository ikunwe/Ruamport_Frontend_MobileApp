import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/panel.dart';
import '../import/import_models.dart';
import '../import/pdf_preview_view.dart';
import 'portfolio_data.dart';
import 'portfolio_store.dart';
import 'live_finance_ui.dart';

class LivePortfolioPage extends StatefulWidget {
  const LivePortfolioPage({
    super.key,
    required this.store,
    required this.onAsset,
  });
  final PortfolioStore store;
  final ValueChanged<Holding> onAsset;
  @override
  State<LivePortfolioPage> createState() => _LivePortfolioPageState();
}

class _LivePortfolioPageState extends State<LivePortfolioPage> {
  String type = 'OFFSHORE_STOCK', sort = 'A–Z', query = '';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final store = widget.store;
      final data = store.data;
      final currency = type == 'OFFSHORE_STOCK' && !store.thb ? 'USD' : 'THB';
      final assets = (data?.held ?? <Holding>[])
          .where(
            (item) =>
                item.type == type &&
                item.symbol.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
      assets.sort(
        sort == 'A–Z'
            ? (a, b) => a.symbol.compareTo(b.symbol)
            : (a, b) =>
                  (b.cost(currency) ?? -1).compareTo(a.cost(currency) ?? -1),
      );
      final value = data?.categoryValue(type, currency, 'marketValue');
      final pnl = data?.categoryValue(type, currency, 'unrealizedPnl');
      return FinanceList(
        key: const PageStorageKey('live-portfolio'),
        children: [
          PageHeading(
            'Portfolio',
            'สินทรัพย์ทั้งหมดของคุณ',
            action: IconButton(
              tooltip: 'รีเฟรชข้อมูล',
              onPressed: store.loading ? null : store.refresh,
              icon: const Icon(Icons.refresh, size: 20),
            ),
          ),
          ChoiceStrip(
            labels: assetTypes.values.toList(),
            value: assetTypes[type]!,
            onChanged: (value) => setState(
              () => type = assetTypes.entries
                  .firstWhere((row) => row.value == value)
                  .key,
            ),
          ),
          if (type == 'OFFSHORE_STOCK')
            Align(
              alignment: Alignment.centerRight,
              child: ChoiceStrip(
                labels: const ['USD', 'THB'],
                value: currency,
                onChanged: (value) => store.currency(value == 'THB'),
              ),
            ),
          if (store.error != null)
            DataNotice(
              store.error!,
              retry: store.refresh,
              loading: store.loading,
            ),
          if (data == null)
            DataNotice('กำลังโหลดข้อมูลพอร์ต', loading: store.loading)
          else ...[
            Panel(
              accent: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${assetTypes[type]} · มูลค่าสินทรัพย์',
                    style: const TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                  const SizedBox(height: 7),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      amount(value, currency),
                      style: TextStyle(
                        fontSize: 30,
                        color: profitColor(pnl),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  LivePnl(
                    pnl,
                    currency: currency,
                    percent: data.categoryValue(
                      type,
                      currency,
                      'unrealizedPnlPercent',
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Divider(height: 1),
                  ),
                  twoColumns(
                    SmallStat(
                      'ต้นทุนรวมตามเอกสาร',
                      amount(
                        data.categoryTotal(type, currency, 'cost'),
                        currency,
                      ),
                    ),
                    SmallStat(
                      'ซื้อสะสม',
                      amount(
                        data.categoryTotal(type, currency, 'buy'),
                        currency,
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  twoColumns(
                    SmallStat(
                      'ขายสะสม',
                      amount(
                        data.categoryTotal(type, currency, 'sell'),
                        currency,
                      ),
                    ),
                    SmallStat(
                      'ค่าธรรมเนียมสะสม',
                      amount(
                        data.categoryTotal(type, currency, 'fees'),
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
                  dropdownColor: surface,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'Kanit',
                    color: Colors.white,
                  ),
                  iconEnabledColor: Colors.white70,
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
              const DataNotice(
                'ยังไม่มีสินทรัพย์ในหมวดนี้ หรือไม่พบสินทรัพย์ที่ค้นหา',
              ),
            for (final item in assets)
              InkWell(
                key: ValueKey('live-holding-${item.key}'),
                onTap: () => widget.onAsset(item),
                borderRadius: BorderRadius.circular(8),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          HoldingLogo(item),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.symbol,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.market} · ${allocationPercent(item.marketValue(currency), value)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 19,
                            color: Colors.white30,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      twoColumns(
                        SmallStat(
                          'มูลค่าสินทรัพย์',
                          amount(item.marketValue(currency), currency),
                          color: profitColor(item.pnl(currency)),
                        ),
                        SmallStat(
                          'ต้นทุนรวม',
                          amount(item.cost(currency), currency),
                        ),
                      ),
                      const SizedBox(height: 14),
                      LivePnl(
                        item.pnl(currency),
                        currency: currency,
                        percent: item.pnlPercent(currency),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Divider(height: 1),
                      ),
                      twoColumns(
                        SmallStat(
                          'ถือ ${pdfNumber(item.quantity, 7)} ${item.unit}',
                          'เฉลี่ย ${amount(item.average(currency), currency)}',
                        ),
                        SmallStat(
                          item.type == 'MUTUAL_FUND' ? 'NAV' : 'ราคาต่อหุ้น',
                          amount(
                            item.offshore && currency == 'THB'
                                ? convertMoney(item.price, data.rate)
                                : item.price,
                            currency,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (item.type == 'MUTUAL_FUND') ...[
                        twoColumns(
                          SmallStat(
                            'มูลค่าสับเปลี่ยนเข้าสะสม',
                            amount(item.fundSwitchIn),
                          ),
                          SmallStat(
                            'มูลค่าสับเปลี่ยนออกสะสม',
                            amount(item.fundSwitchOut),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        '${percentage(item.dailyPercent)} จากวันก่อนหน้า',
                        style: TextStyle(
                          fontSize: 10,
                          color: profitColor(item.dailyPercent),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'แหล่งอ้างอิง: ${textValue(item.quote['source']) ?? '—'}'
                        '${objectMap(item.quote['marketSchedule'])['state'] == 'OPEN'
                            ? ' · ตลาดเปิดอยู่'
                            : objectMap(item.quote['marketSchedule'])['state'] == 'CLOSED'
                            ? ' · ตลาดปิดอยู่'
                            : ''}',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white38,
                        ),
                      ),
                      Text(
                        textValue(
                              item.quote['navDate'] ?? item.quote['priceAt'],
                            ) ??
                            'ยังไม่มีราคาอ้างอิง',
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.white30,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      );
    },
  );
}
