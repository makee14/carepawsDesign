import 'package:carepaws/data/models.dart';
import 'package:carepaws/data/seed.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/chats_screen.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget tests for the Chats tab redesign (B3): collapsed how-it-works,
/// team carousel, member sheet.
Future<AppStore> pumpChats(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.binding.setSurfaceSize(const Size(390, 844));
  final s = AppStore(now: DateTime(2026, 10, 13, 10, 0));
  await tester.pumpWidget(
    AppScope(
      store: s,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: const ChatsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return s;
}

void main() {
  group('chats tab redesign (B3)', () {
    testWidgets('clinic chat header, team carousel, how-it-works collapsed', (
      tester,
    ) async {
      await pumpChats(tester);

      expect(find.text('Clinic chat'), findsOneWidget);
      // All three team members have a carousel card.
      for (final m in Seed.staff) {
        expect(
          find.bySemanticsLabel('${m.name}, ${m.role.label}'),
          findsWidgets,
        );
      }
      // G2: the explainer starts collapsed.
      expect(
        find.textContaining('Message the clinic team directly'),
        findsNothing,
      );
    });

    testWidgets('info icon expands and collapses how-it-works', (tester) async {
      await pumpChats(tester);

      await tester.tap(find.bySemanticsLabel('How clinic chat works'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Message the clinic team directly'),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('Hide how clinic chat works'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Message the clinic team directly'),
        findsNothing,
      );
    });

    testWidgets('tapping a team card opens the member sheet', (tester) async {
      await pumpChats(tester);

      await tester.tap(
        find.bySemanticsLabel('Dr. Rafael Alvarez, Veterinarian'),
      );
      await tester.pumpAndSettle();

      // Sheet shows bio, role chip, and the Chat button.
      expect(find.textContaining('internal medicine'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
    });

    testWidgets('member Chat button opens the clinic thread', (tester) async {
      await pumpChats(tester);

      await tester.tap(
        find.bySemanticsLabel('Dr. Rafael Alvarez, Veterinarian'),
      );
      await tester.pumpAndSettle();
      // The sheet opens at the 60% detent; scroll the Chat button into
      // view the way a user would, then tap it.
      await tester.ensureVisible(find.text('Chat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chat'));
      await tester.pumpAndSettle();

      // Landed in the clinic thread's composer.
      expect(find.text('Message the clinic team'), findsOneWidget);
    });
  });
}
