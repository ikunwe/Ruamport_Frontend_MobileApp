import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/panel.dart';
import 'import_models.dart';

String pdfNumber(Object? value, [int decimals = 2]) {
  if (value is! num || !value.isFinite) return '—';
  final parts = value.toStringAsFixed(decimals).split('.');
  parts[0] = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return parts.join('.');
}

String pdfMoney(Object? value, String currency, [int decimals = 2]) =>
    value is num ? '${pdfNumber(value, decimals)} $currency' : '—';
String transactionLabel(Object? value) =>
    const {
      'BUY': 'ซื้อ',
      'SELL': 'ขาย',
      'SEL': 'ขาย',
      'REWARD': 'หุ้นรางวัล',
      'REW': 'หุ้นรางวัล',
      'SUBSCRIPTION': 'ซื้อกองทุน',
      'REDEMPTION': 'ขายคืน',
      'SWITCH_IN': 'สับเปลี่ยนเข้า',
      'SWITCH_OUT': 'สับเปลี่ยนออก',
      'SUB': 'ซื้อกองทุน',
      'RED': 'ขายคืน',
      'SWI': 'สับเปลี่ยนเข้า',
      'SWO': 'สับเปลี่ยนออก',
      'EXERCISE_CALL': 'ใช้สิทธิ Call',
      'EXERCISE_PUT': 'ใช้สิทธิ Put',
      'EXC': 'ใช้สิทธิ Call',
      'EXP': 'ใช้สิทธิ Put',
    }[value] ??
    textValue(value) ??
    '—';

class PdfPreviewView extends StatelessWidget {
  const PdfPreviewView({
    super.key,
    required this.preview,
    required this.record,
  });
  final PdfPreview preview;
  final DocumentRecord record;
  Widget row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final totals = preview.totals;
    final entries = preview.fund
        ? [
            ('ซื้อสะสม', 'totalSubscription'),
            ('ขายคืนสะสม', 'totalRedemption'),
            ('สับเปลี่ยนเข้า', 'totalSwitchIn'),
            ('สับเปลี่ยนออก', 'totalSwitchOut'),
            ('ค่าธรรมเนียมรวม VAT', 'totalFeeIncludeVat'),
          ]
        : preview.offshore
        ? [
            ('มูลค่าซื้อ', 'totalBuy'),
            ('มูลค่าขาย', 'totalSell'),
            ('ค่าธรรมเนียมก่อน VAT', 'totalFeeExcludeVat'),
            ('ส่วนลด', 'discount'),
            (
              'ค่าธรรมเนียมหลังส่วนลด ก่อน VAT',
              'totalFeeAfterDiscountExcludeVat',
            ),
            ('VAT', 'totalVat'),
            ('ภาษีหัก ณ ที่จ่าย', 'withholdingTax'),
            (
              'ค่าธรรมเนียมรวม VAT หลังส่วนลด',
              'totalFeeIncludeVatAfterDiscount',
            ),
            ('ค่าธรรมเนียมและภาษีรวม', 'totalFeesAndTaxes'),
          ]
        : [
            ('มูลค่าซื้อ', 'totalBuy'),
            ('มูลค่าขาย', 'totalSell'),
            ('ค่าธรรมเนียมก่อน VAT', 'totalFeeExcludeVat'),
            ('VAT', 'totalVat'),
            ('ยอดสุทธิตามเอกสาร', 'netCustomerAmount'),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                preview.assetLabel,
                style: const TextStyle(color: lime, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                preview.filename,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${preview.orders.length} รายการ · เลขที่เอกสาร ${preview.documentNumber}',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 6),
              Text(
                record.imported
                    ? 'บันทึกเข้าพอร์ตแล้ว'
                    : 'Preview · ยังไม่ได้ยืนยันบันทึกเข้าพอร์ต',
                style: TextStyle(
                  color: record.imported ? lime : Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final warning in preview.warnings)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              child: Text(
                _warning(warning),
                style: const TextStyle(
                  color: Color(0xFFFFD675),
                  fontSize: 11,
                  height: 1.7,
                ),
              ),
            ),
          ),
        if (preview.blocksImport)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'เอกสารนี้ยังมีข้อผิดพลาดที่บล็อกการบันทึก',
              style: TextStyle(color: loss, fontSize: 12),
            ),
          ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'สรุปยอดตามเอกสาร',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final entry in entries)
                row(entry.$1, pdfMoney(totals[entry.$2], 'THB')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'รายการซื้อขาย',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        for (final order in preview.orders)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    textValue(order[preview.fund ? 'fundName' : 'symbol']) ??
                        '—',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    transactionLabel(
                      order['transactionType'] ?? order['transactionCode'],
                    ),
                    style: const TextStyle(fontSize: 11, color: lime),
                  ),
                  row('วันที่ซื้อขาย', textValue(order['tradeDate']) ?? '—'),
                  if (!preview.fund)
                    row(
                      'วันที่ชำระราคา',
                      textValue(order['settlementDate']) ?? '—',
                    ),
                  row(
                    'จำนวน${preview.fund ? 'หน่วย' : 'หุ้น'}',
                    pdfNumber(order['units'], 7),
                  ),
                  row(
                    preview.fund ? 'NAV ต่อหน่วย' : 'ราคาต่อหุ้น',
                    pdfMoney(
                      order[preview.offshore
                          ? 'unitPrice'
                          : preview.fund
                          ? 'navPerUnit'
                          : 'pricePerShare'],
                      textValue(order['currency']) ??
                          (preview.offshore ? 'USD' : 'THB'),
                      4,
                    ),
                  ),
                  if (preview.offshore) ...[
                    row(
                      'มูลค่ารายการ',
                      pdfMoney(
                        objectMap(order['grossAmount'])['foreign'],
                        textValue(order['currency']) ?? 'USD',
                      ),
                    ),
                    row(
                      'ค่าธรรมเนียมรวม VAT',
                      pdfMoney(
                        objectMap(order['feeIncludeVat'])['foreign'],
                        textValue(order['currency']) ?? 'USD',
                      ),
                    ),
                    row(
                      'ยอดสุทธิ',
                      pdfMoney(
                        objectMap(order['totalAmount'])['foreign'],
                        textValue(order['currency']) ?? 'USD',
                      ),
                    ),
                    row(
                      'ยอดสุทธิตามเอกสาร (THB)',
                      pdfMoney(objectMap(order['totalAmount'])['thb'], 'THB'),
                    ),
                  ] else ...[
                    row('ยอดรายการ', pdfMoney(order['totalAmount'], 'THB')),
                    if (preview.fund)
                      row(
                        'ค่าธรรมเนียมรวม VAT',
                        pdfMoney(order['feeIncludeVat'], 'THB'),
                      )
                    else ...[
                      row(
                        'ค่าธรรมเนียมก่อน VAT',
                        pdfMoney(order['feeExcludeVat'], 'THB'),
                      ),
                      row('VAT', pdfMoney(order['vat'], 'THB')),
                    ],
                  ],
                  row('เลขคำสั่ง', textValue(order['orderId']) ?? '—'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _warning(Map<String, dynamic> warning) {
    if (warning['calculatedValue'] is num && warning['pdfValue'] is num) {
      return 'ระบบรวมรายการได้ ${pdfMoney(warning['calculatedValue'], textValue(warning['currency']) ?? 'THB')} '
          'แต่ยอดสรุปใน PDF คือ ${pdfMoney(warning['pdfValue'], textValue(warning['currency']) ?? 'THB')}';
    }
    return textValue(warning['message']) ??
        'มีข้อมูลบางส่วนที่ต้องตรวจสอบ (${warning['code'] ?? 'คำเตือน'})';
  }
}
