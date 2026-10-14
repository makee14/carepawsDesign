import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/appointments_screen.dart';
import 'package:carepaws/screens/chats_screen.dart';
import 'package:carepaws/screens/home_screen.dart';
import 'package:carepaws/screens/profile_screen.dart';
import 'package:carepaws/screens/shops_screen.dart';
import 'package:carepaws/state/app_store.dart';

/// Sweep: the five tabs must not overflow at AX5 (3.2x) or in landscape.
Future<void> pumpTab(
  WidgetTester tester,
  Widget tab, {
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(now: DateTime(2026, 10, 13, 15, 6));
  addTearDown(store.dispose);
  await tester.pumpWidget(
    AppScope(
      store: store,
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: tab,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  final tabs = <String, Widget>{
    'home': const HomeScreen(),
    'chats': const ChatsScreen(),
    'appointments': const AppointmentsScreen(),
    'shops': const ShopsScreen(),
    'profile': const ProfileScreen(),
  };

  group('AX5 (textScale 3.2)', () {
    for (final entry in tabs.entries) {
      testWidgets('${entry.key} has no overflow at AX5', (tester) async {
        await pumpTab(tester, entry.value, textScale: 3.2);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('landscape (844x390)', () {
    for (final entry in tabs.entries) {
      testWidgets('${entry.key} has no overflow in landscape', (tester) async {
        await tester.binding.setSurfaceSize(const Size(844, 390));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await pumpTab(tester, entry.value);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
