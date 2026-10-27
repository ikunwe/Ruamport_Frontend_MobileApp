import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_portfoliomanagement_mobile/shared/widgets/user_avatar.dart';
import 'package:project_portfoliomanagement_mobile/shared/widgets/avatar_image.dart';

void main() {
  for (final url in [null, '', '   ', 'not-a-url', 'javascript:alert(1)']) {
    testWidgets('invalid avatar uses the fallback for $url', (tester) async {
      await tester.pumpWidget(MaterialApp(home: UserAvatar(url: url)));
      expect(find.byType(AvatarImage), findsNothing);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });
  }
  testWidgets(
    'trims the backend URL and changes image identity when profile changes',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserAvatar(url: ' https://example.com/avatar-one.png '),
        ),
      );
      expect(
        tester.widget<AvatarImage>(find.byType(AvatarImage)).url,
        'https://example.com/avatar-one.png',
      );
      expect(
        find.byKey(const ValueKey('https://example.com/avatar-one.png')),
        findsOneWidget,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: UserAvatar(url: 'https://example.com/avatar-two.png'),
        ),
      );
      expect(
        tester.widget<AvatarImage>(find.byType(AvatarImage)).url,
        'https://example.com/avatar-two.png',
      );
      expect(
        find.byKey(const ValueKey('https://example.com/avatar-one.png')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('https://example.com/avatar-two.png')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
