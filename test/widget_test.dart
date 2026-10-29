import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_portfoliomanagement_mobile/main.dart';

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Kanit');
    for (final file in [
      'Kanit-Regular.ttf',
      'Kanit-SemiBold.ttf',
      'Kanit-Bold.ttf',
    ]) {
      fonts.addFont(rootBundle.load('assets/fonts/$file'));
    }
    await fonts.load();
  });
  for (final width in [320.0, 390.0]) {
    testWidgets('Homepage navigation at $width pixels', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final preview = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(key: preview, child: const RuamportApp()),
      );
      await tester.pumpAndSettle();
      if (const bool.fromEnvironment('CAPTURE_MOBILE_UI') && width == 390) {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(preview),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('build/ui-previews/home.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.text('แพลตฟอร์มลงทุนที่รองรับ'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Get started'));
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 390) {
        await tester.ensureVisible(find.text('ดูตัวอย่าง Dashboard'));
        await tester.tap(find.text('ดูตัวอย่าง Dashboard'));
        await tester.pumpAndSettle();
        expect(find.text('สวัสดี, ผู้ใช้งานตัวอย่าง'), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(
          tester.element(find.text('สวัสดี, ผู้ใช้งานตัวอย่าง')),
        ).pop();
        await tester.pumpAndSettle();
      }
      Navigator.of(tester.element(find.text('เข้าสู่ระบบ'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsOneWidget);
    });
  }
}
