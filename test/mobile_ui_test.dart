import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_portfoliomanagement_mobile/core/theme/app_theme.dart';
import 'package:project_portfoliomanagement_mobile/features/dashboard/dashboard_page.dart';
import 'package:project_portfoliomanagement_mobile/features/portfolio/portfolio_page.dart';
import 'package:project_portfoliomanagement_mobile/features/portfolio/stock_detail_page.dart';
import 'package:project_portfoliomanagement_mobile/features/simulator/simulator_page.dart';
import 'package:project_portfoliomanagement_mobile/features/support/contact_sheet.dart';
import 'package:project_portfoliomanagement_mobile/features/import/import_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final preview = GlobalKey();
  setUpAll(() async {
    final loader = FontLoader('Kanit');
    for (final file in [
      'Kanit-Regular.ttf',
      'Kanit-SemiBold.ttf',
      'Kanit-Bold.ttf',
    ]) {
      loader.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  Future<void> open(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: preview,
        child: MaterialApp(
          theme: createAppTheme(),
          debugShowCheckedModeBanner: false,
          home: const DashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_MOBILE_UI')) return;
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(preview),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/ui-previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final width in [320.0, 390.0, 600.0]) {
    testWidgets('All dashboard sections and stock navigation at $width', (
      tester,
    ) async {
      await open(tester, width);
      expect(find.text('สวัสดี, ผู้ใช้งานตัวอย่าง'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 390) await capture(tester, 'overview');
      await tab(tester, 'Portfolio');
      if (width == 390) await capture(tester, 'portfolio');
      final portfolioScroll = find
          .descendant(
            of: find.byType(PortfolioPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('holding-AAPL')),
        200,
        scrollable: portfolioScroll,
      );
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('holding-AAPL')),
          matching: find.text('AAPL'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StockDetailPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 390) await capture(tester, 'stock');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tab(tester, 'Analytics');
      if (width == 390) await capture(tester, 'analytics');
      await tab(tester, 'Simulator');
      if (width == 390) await capture(tester, 'simulator');
      await tab(tester, 'เพิ่มเติม');
      await tester.tap(find.text('Contact us'));
      await tester.pumpAndSettle();
      expect(find.byType(ContactSheet), findsOneWidget);
      expect(find.text('หัวข้อเรื่อง'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 390) await capture(tester, 'contact');
      await tester.tap(find.byTooltip('ปิด Contact us'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('News'));
      await tester.pumpAndSettle();
      expect(find.text('เปิดใช้งานเร็ว ๆ นี้'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets(
    'Simulator inputs produce hypothetical results and never affect holdings',
    (tester) async {
      await open(tester, 390);
      await tab(tester, 'Simulator');
      final fields = find.descendant(
        of: find.byType(SimulatorPage),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), '100');
      await tester.enterText(fields.at(1), '2');
      await tester.pumpAndSettle();
      final scroll = find
          .descendant(
            of: find.byType(SimulatorPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('เปรียบเทียบก่อน – หลังซื้อ'),
        180,
        scrollable: scroll,
      );
      expect(find.text('ต้นทุนรวมใหม่'), findsOneWidget);
      expect(find.text('114.29 USD'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'simulator-result');
      await tab(tester, 'Portfolio');
      expect(find.text('Portfolio'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Sync preview requires a password and never reads real mail or files',
    (tester) async {
      await open(tester, 390);
      await tester.tap(find.byTooltip('เพิ่มข้อมูลพอร์ต'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sync ข้อมูลจากอีเมล'));
      await tester.pumpAndSettle();
      expect(find.byType(ImportSheet), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'ดูตัวอย่างผลซิงค์');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.enterText(find.byType(TextField).last, 'demo-password');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('ตัวอย่างเอกสารที่พบ 3 ไฟล์'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'sync-preview');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
