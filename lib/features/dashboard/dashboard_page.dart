import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/brand.dart';
import '../../shared/widgets/panel.dart';
import '../../shared/show_notice.dart';
import '../profile/profile_sheet.dart';
import 'widgets/metric_card.dart';
import 'widgets/allocation_legend.dart';
import 'widgets/holding_row.dart';
import 'charts/portfolio_chart.dart';
import 'charts/allocation_chart.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selected = 0;
  String period = '1M';
  bool thb = false;
  final tabs = ['Overview', 'Portfolio', 'Analytics', 'Transactions'];
  void profile() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: surface,
    showDragHandle: true,
    builder: (_) => ProfileSheet(onLogout: () => Navigator.pop(context)),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: NavigationBar(
      backgroundColor: surface,
      indicatorColor: lime.withValues(alpha: .15),
      selectedIndex: selected,
      onDestinationSelected: (value) => setState(() => selected = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(Icons.space_dashboard, color: lime),
          label: 'Overview',
        ),
        NavigationDestination(
          icon: Icon(Icons.work_outline),
          label: 'Portfolio',
        ),
        NavigationDestination(icon: Icon(Icons.insights), label: 'Analytics'),
        NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'History'),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Brand(),
                  IconButton(
                    onPressed: profile,
                    tooltip: 'ข้อมูลโปรไฟล์',
                    icon: const CircleAvatar(
                      backgroundColor: Color(0xFF20351C),
                      child: Icon(Icons.person_outline, color: lime),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'ภาพรวมพอร์ต',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                selected == 0 ? 'สวัสดี, ผู้ใช้งานตัวอย่าง' : tabs[selected],
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              if (selected != 0)
                Panel(
                  child: Text('${tabs[selected]} • ตัวอย่างการจัดวางข้อมูล'),
                ),
              const SizedBox(height: 8),
              Panel(
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: lime, size: 20),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'นี่เป็นข้อมูลพอร์ตตัวอย่าง\nเริ่มนำเข้าข้อมูลของคุณผ่าน PDF หรือ Sync',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          notice(context, 'ยังไม่ได้เชื่อมต่อ API อัปโหลด PDF'),
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: const Text('อัปโหลด PDF'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => const Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'เชื่อมต่ออีเมล',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'รองรับแนวทาง Gmail และ Outlook\nระบบเชื่อมต่ออีเมลยังไม่พร้อมใช้งาน',
                              ),
                              SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.sync, size: 18),
                      label: const Text('Sync ข้อมูล'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'มูลค่าสินทรัพย์',
                          style: TextStyle(color: Colors.white54),
                        ),
                        Flexible(
                          child: FittedBox(
                            child: SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: false, label: Text('USD')),
                                ButtonSegment(value: true, label: Text('THB')),
                              ],
                              selected: {thb},
                              onSelectionChanged: (v) =>
                                  setState(() => thb = v.first),
                              showSelectedIcon: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      thb ? '฿85,921.69' : '\$2,632.20',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    const Text(
                      '↗ +8.24%  ในเดือนนี้',
                      style: TextStyle(color: lime, fontSize: 12),
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 140,
                      width: double.infinity,
                      child: CustomPaint(painter: PortfolioChart(period)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: ['1D', '1W', '1M', '3M', '1Y', 'ALL']
                          .map(
                            (p) => InkWell(
                              onTap: () => setState(() => period = p),
                              borderRadius: BorderRadius.circular(8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: period == p
                                      ? lime.withValues(alpha: .15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  p,
                                  style: TextStyle(
                                    color: period == p ? lime : Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1 USD = 32.63 THB • อัตราตัวอย่าง',
                      style: TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                children: [
                  Expanded(
                    child: Metric(
                      label: 'มูลค่าพอร์ตเริ่มลงทุน',
                      amount: '\$1,452.20',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Metric(
                      label: 'กำไร / ขาดทุนวันนี้',
                      amount: '+\$24.80',
                      positive: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: Metric(
                      label: 'Unrealized P&L',
                      amount: '+\$182.40',
                      positive: true,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Metric(
                      label: 'Realized P&L',
                      amount: '+\$63.21',
                      positive: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'สัดส่วนสินทรัพย์',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CustomPaint(painter: AllocationChart()),
                        ),
                        const SizedBox(width: 24),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Legend(
                                'หุ้นต่างประเทศ',
                                '50%',
                                Color(0xFF61FFD0),
                              ),
                              SizedBox(height: 14),
                              Legend('กองทุนรวม', '30%', lime),
                              SizedBox(height: 14),
                              Legend('เงินสด', '20%', Color(0xFFFFDC3A)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เงินสดที่ยังไม่ได้ลงทุน',
                      style: TextStyle(color: Colors.white54),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '\$327.41',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Save  \$250    •    FCD  \$63.21    •    USD  \$14.20',
                      style: TextStyle(fontSize: 11, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'สินทรัพย์ในพอร์ต',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 18),
                    Holding('AAPL', 'Apple Inc.', '\$842.30', '+12.40%'),
                    Divider(color: Colors.white10),
                    Holding('MSFT', 'Microsoft', '\$654.20', '+8.20%'),
                    Divider(color: Colors.white10),
                    Holding('VOO', 'Vanguard S&P 500', '\$808.29', '+6.18%'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ข้อมูลทั้งหมดเป็นตัวอย่างสำหรับออกแบบ UI',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    ),
  );
}
