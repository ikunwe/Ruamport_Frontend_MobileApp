import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/panel.dart';

class NewsPage extends StatelessWidget {
  const NewsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('News'),
      backgroundColor: const Color(0xFF070807),
    ),
    body: SafeArea(
      child: FinanceList(
        children: [
          const PageHeading(
            'ข่าวที่เกี่ยวกับคุณ',
            'ข่าวหุ้นในพอร์ตและภาพรวมตลาด',
          ),
          Panel(
            accent: true,
            child: Column(
              children: [
                const Icon(Icons.newspaper_outlined, color: lime, size: 44),
                const SizedBox(height: 16),
                const Text(
                  'เปิดใช้งานเร็ว ๆ นี้',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 9),
                const Text(
                  'ติดตามข่าวที่เกี่ยวกับสินทรัพย์ในพอร์ต\nในที่เดียวกับที่คุณดูการลงทุน',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.8,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 16),
                const DemoTag(),
              ],
            ),
          ),
          const Text(
            'ตัวอย่างการจัดวางฟีดข่าว',
            style: TextStyle(fontSize: 13, color: Colors.white54),
          ),
          ...[
            'ข่าวที่เกี่ยวกับหุ้นในพอร์ต',
            'ภาพรวมตลาดและดัชนี',
            'อัปเดตกองทุนที่คุณติดตาม',
          ].asMap().entries.map(
            (entry) => Panel(
              child: Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: [
                        lime,
                        blue,
                        violet,
                      ][entry.key].withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.article_outlined,
                      color: [lime, blue, violet][entry.key],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.value, style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 7),
                        const Text(
                          'พื้นที่ข่าวตัวอย่าง · ยังไม่มีข่าวจริง',
                          style: TextStyle(fontSize: 10, color: Colors.white30),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
