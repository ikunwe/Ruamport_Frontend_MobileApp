import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_portfoliomanagement_mobile/main.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('Homepage navigation at $width pixels', (tester) async {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const RuamportApp());
      await tester.pumpAndSettle();
      expect(find.text('รองรับหลายแพลตฟอร์มลงทุน'), findsOneWidget);
      expect(find.text('Get started'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Get started').first);
      await tester.pumpAndSettle();
      expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (width == 390) {
        await tester.ensureVisible(find.text('ดูตัวอย่าง Dashboard'));
        await tester.tap(find.text('ดูตัวอย่าง Dashboard'));
        await tester.pumpAndSettle();
        expect(find.text('สวัสดี, ผู้ใช้งานตัวอย่าง'), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.text('สวัสดี, ผู้ใช้งานตัวอย่าง')))
            .pop();
        await tester.pumpAndSettle();
      }
      Navigator.of(tester.element(find.text('เข้าสู่ระบบ'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Get started'), findsNWidgets(2));
    });
  }
}
