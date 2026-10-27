import 'package:flutter/material.dart';
import '../../core/auth/app_user.dart';
import '../../core/auth/auth_scope.dart';
import '../import/import_api.dart';
import '../import/investment_import_sheet.dart';
import '../portfolio/portfolio_store.dart';
import '../portfolio/portfolio_data.dart';
import '../portfolio/live_portfolio_page.dart';
import '../portfolio/live_stock_page.dart';
import '../portfolio/live_finance_ui.dart';
import '../import/pdf_preview_view.dart';
import '../analytics/live_analytics_page.dart';
import '../simulator/live_simulator_page.dart';
import 'live_overview_page.dart';
import '../profile/account_sheet.dart';
import '../../shared/widgets/user_avatar.dart';

import '../../core/demo/demo_portfolio.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/finance_ui.dart';
import '../../shared/widgets/panel.dart';
import '../home/widgets/home_logo.dart';
import '../profile/profile_sheet.dart';
import '../portfolio/portfolio_page.dart';
import '../portfolio/stock_detail_page.dart';
import '../analytics/analytics_page.dart';
import '../simulator/simulator_page.dart';
import '../news/news_page.dart';
import '../support/contact_sheet.dart';
import '../import/import_sheet.dart';
import 'overview_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, this.account});
  final AppUser? account;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  int selected = 0;
  bool thb = false, importPreviewed = false;
  String userName = 'ผู้ใช้งานตัวอย่าง';
  String? mailCallbackCode;
  PortfolioStore? portfolio;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    userName = widget.account?.displayName ?? userName;
    if (widget.account != null &&
        Uri.base.path == '/mail/return' &&
        Uri.base.queryParameters.containsKey('mailConnection')) {
      if (Uri.base.queryParameters['mailConnection'] == 'error') {
        mailCallbackCode = Uri.base.queryParameters['code'];
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) importData(true);
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = AuthScope.of(context);
    if (widget.account != null && auth != null && portfolio == null) {
      portfolio = PortfolioStore(ImportApi.forAuth(auth))
        ..addListener(portfolioChanged);
      Future<void>(() => portfolio?.refresh());
    }
  }

  void portfolioChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      portfolio?.active(state == AppLifecycleState.resumed);
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    portfolio?.removeListener(portfolioChanged);
    portfolio?.dispose();
    super.dispose();
  }

  void openLiveAsset(Holding holding) {
    portfolio!.selectedKey = holding.key;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LiveStockPage(store: portfolio!, asset: holding),
      ),
    );
  }

  void openStock() {
    if (portfolio == null) {
      openAsset(demoAssets.first);
      return;
    }
    final store = portfolio!;
    final items = store.data?.items ?? <Holding>[];
    if (items.isEmpty) {
      openSheet(const DataNotice('ยังไม่มีสินทรัพย์สำหรับแสดงรายละเอียด'));
      return;
    }
    openLiveAsset(
      items.where((item) => item.key == store.selectedKey).firstOrNull ??
          items.first,
    );
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.account != oldWidget.account && widget.account != null) {
      userName = widget.account!.displayName;
    }
  }

  void openSheet(Widget child) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: surface,
    barrierColor: Colors.black.withValues(alpha: .7),
    showDragHandle: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .90,
      maxWidth: 680,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    builder: (_) => child,
  );
  void profile() => widget.account != null
      ? openSheet(AccountSheet(account: widget.account!))
      : openSheet(
          ProfileSheet(
            onNameChanged: (name) => setState(() => userName = name),
            onLogout: () => Navigator.of(context).pop(),
          ),
        );
  void importData(bool mail) {
    final auth = AuthScope.of(context);
    if (widget.account != null && auth != null) {
      final callbackCode = mailCallbackCode;
      mailCallbackCode = null;
      openSheet(
        InvestmentImportSheet(
          mail: mail,
          api: ImportApi.forAuth(auth),
          callbackCode: callbackCode,
          onSaved: () {
            if (mounted) portfolio?.refresh(afterImport: true);
          },
        ),
      );
      return;
    }
    openSheet(
      ImportSheet(
        mail: mail,
        onPreview: () => setState(() => importPreviewed = true),
      ),
    );
  }

  void chooseImport() => openSheet(
    SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'เพิ่มข้อมูลพอร์ต',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              widget.account == null
                  ? 'เลือกวิธีนำเข้าเพื่อดูตัวอย่างขั้นตอน'
                  : 'เลือกวิธีนำเข้าเอกสารเพื่อตรวจ Preview ก่อนบันทึก',
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                importData(false);
              },
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('อัปโหลด PDF'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                importData(true);
              },
              icon: const Icon(Icons.sync),
              label: const Text('Sync ข้อมูลจากอีเมล'),
            ),
          ],
        ),
      ),
    ),
  );
  void openAsset(DemoAsset asset) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StockDetailPage(
        asset: asset,
        thb: thb,
        onCurrency: (value) => setState(() => thb = value),
      ),
    ),
  );

  Widget more() => FinanceList(
    key: const PageStorageKey('more-list'),
    children: [
      const PageHeading('เพิ่มเติม', 'ทุกอย่างเกี่ยวกับพอร์ตและบัญชีของคุณ'),
      Panel(
        child: InkWell(
          onTap: profile,
          child: Row(
            children: [
              UserAvatar(url: widget.account?.avatarUrl, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      widget.account?.email ?? 'demo@ruamport.app',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
      Panel(
        padding: 4,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                Icons.candlestick_chart_outlined,
                color: blue,
              ),
              title: const Text('Stock', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'รายละเอียดและประวัติซื้อขาย',
                style: TextStyle(fontSize: 10, color: Colors.white38),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: openStock,
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.newspaper_outlined, color: violet),
              title: const Text('News', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'เปิดใช้งานเร็ว ๆ นี้',
                style: TextStyle(fontSize: 10, color: Colors.white38),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const NewsPage())),
            ),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.headset_mic_outlined, color: lime),
              title: const Text('Contact us', style: TextStyle(fontSize: 14)),
              subtitle: const Text(
                'แจ้งปัญหาและเสนอแนะ',
                style: TextStyle(fontSize: 10, color: Colors.white38),
              ),
              trailing: const Icon(Icons.chevron_right, size: 18),
              onTap: () => openSheet(const ContactSheet()),
            ),
          ],
        ),
      ),
      Panel(
        padding: 4,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file_outlined),
              title: const Text('อัปโหลด PDF', style: TextStyle(fontSize: 14)),
              onTap: () => importData(false),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync ข้อมูล', style: TextStyle(fontSize: 14)),
              onTap: () => importData(true),
            ),
          ],
        ),
      ),
      Panel(
        child: Text(
          portfolio == null
              ? 'Ruamport Mobile · UI Preview\nข้อมูลพอร์ต ราคา และการนำเข้ายังเป็นตัวอย่าง'
              : 'ข้อมูลบัญชีและพอร์ตจากระบบ Ruamport · News และ Contact us ยังไม่เปิดใช้งาน',
          style: const TextStyle(
            fontSize: 11,
            height: 1.8,
            color: Colors.white38,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: NavigationBar(
      height: 70,
      backgroundColor: const Color(0xFF101210),
      indicatorColor: lime.withValues(alpha: .12),
      selectedIndex: selected,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Kanit',
          fontSize: 10,
          color: states.contains(WidgetState.selected) ? lime : Colors.white38,
        ),
      ),
      onDestinationSelected: (value) => setState(() => selected = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.space_dashboard_outlined, size: 21),
          selectedIcon: Icon(Icons.space_dashboard, color: lime, size: 21),
          label: 'Overview',
        ),
        NavigationDestination(
          icon: Icon(Icons.work_outline, size: 21),
          selectedIcon: Icon(Icons.work, color: lime, size: 21),
          label: 'Portfolio',
        ),
        NavigationDestination(
          icon: Icon(Icons.insights_outlined, size: 21),
          selectedIcon: Icon(Icons.insights, color: lime, size: 21),
          label: 'Analytics',
        ),
        NavigationDestination(
          icon: Icon(Icons.calculate_outlined, size: 21),
          selectedIcon: Icon(Icons.calculate, color: lime, size: 21),
          label: 'Simulator',
        ),
        NavigationDestination(
          icon: Icon(Icons.grid_view_outlined, size: 21),
          selectedIcon: Icon(Icons.grid_view, color: lime, size: 21),
          label: 'เพิ่มเติม',
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 5),
                child: Row(
                  children: [
                    const HomeLogo(),
                    const Spacer(),
                    IconButton(
                      tooltip: 'เพิ่มข้อมูลพอร์ต',
                      onPressed: chooseImport,
                      icon: const Icon(
                        Icons.add_box_outlined,
                        color: Colors.white60,
                        size: 23,
                      ),
                    ),
                    IconButton(
                      tooltip: 'ข้อมูลโปรไฟล์',
                      onPressed: profile,
                      icon: UserAvatar(url: widget.account?.avatarUrl),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .03),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.currency_exchange,
                                  size: 12,
                                  color: lime,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  portfolio == null
                                      ? '1 USD = 33.70 THB'
                                      : '1 USD = ${pdfNumber(portfolio?.data?.rate)} THB',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white60,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (portfolio == null) const DemoTag(),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: IndexedStack(
                  index: selected,
                  children: portfolio != null
                      ? [
                          LiveOverviewPage(
                            store: portfolio!,
                            name: userName,
                            onImport: chooseImport,
                            onAnalytics: () => setState(() => selected = 2),
                            onAsset: openLiveAsset,
                          ),
                          LivePortfolioPage(
                            store: portfolio!,
                            onAsset: openLiveAsset,
                          ),
                          LiveAnalyticsPage(
                            store: portfolio!,
                            active: selected == 2,
                          ),
                          LiveSimulatorPage(store: portfolio!),
                          more(),
                        ]
                      : [
                          OverviewPage(
                            onImport: chooseImport,
                            onAnalytics: () => setState(() => selected = 2),
                            onAsset: openAsset,
                            userName: userName,
                            importPreviewed: importPreviewed,
                          ),
                          PortfolioPage(
                            thb: thb,
                            onCurrency: (value) => setState(() => thb = value),
                            onAsset: openAsset,
                          ),
                          const AnalyticsPage(),
                          const SimulatorPage(),
                          more(),
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
