import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/design/icons.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/design/tokens.dart';
import 'package:carepaws/screens/home_screen.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';

DateTime fixedNow() => DateTime(2026, 10, 13, 9, 40);

/// Boots the real RootShell (home tab) at iPhone dimensions.
Future<void> pumpHome(
  WidgetTester tester, {
  AppStore? store,
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    AppScope(
      store: store ?? AppStore(now: fixedNow()),
      child: CupertinoApp(
        theme: themeFor(AppPalette.light),
        home: const RootShell(),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: reduceMotion,
            ),
            child: child!,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Drags the main vertical list until [finder] exists on screen.
Future<bool> revealHome(
  WidgetTester tester,
  Finder finder, {
  int max = 60,
}) async {
  bool countOf(Finder f) => f.evaluate().isNotEmpty;
  if (countOf(finder)) return true;
  final scrollable = find.descendant(
    of: find.byType(CustomScrollView),
    matching: find.byType(Scrollable),
  );
  for (var i = 0; i < max; i++) {
    await tester.drag(scrollable.first, const Offset(0, -180));
    await tester.pumpAndSettle();
    if (countOf(finder)) return true;
  }
  return false;
}

void main() {
  // AppStore lazily touches SharedPreferences; without mock values
  // getInstance() never resolves inside testWidgets (fake async clock stalls).
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  group('home polish — compact hero appointment card', () {
    testWidgets('hero renders pet name, chips and the cream label pill', (
      tester,
    ) async {
      await pumpHome(tester);
      // Two upcoming appointments in the seed → the carousel builds.
      expect(find.byType(PageView), findsOneWidget);
      expect(find.text('Biscuit · Vet Consultation'), findsWidgets);
      expect(find.text('in 3d'), findsWidgets);
      // The cream "Next appointment" pill sits on the card itself.
      expect(find.text('Next appointment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hero photo is full-bleed with the glass panel overlaid', (
      tester,
    ) async {
      await pumpHome(tester, reduceMotion: true);
      // The photo fills the card edge to edge...
      final fills = find.byWidgetPredicate(
        (w) =>
            w is Positioned &&
            w.top == 0 &&
            w.left == 0 &&
            w.right == 0 &&
            w.bottom == 0,
      );
      expect(fills, findsWidgets);
      // ...and the glass info panel floats over the photo's lower portion
      // (bottom-anchored in the same Stack), never laid out beneath it.
      final panelAnchor = find.byWidgetPredicate(
        (w) => w is Positioned && w.bottom == 14 && w.left == 0 && w.right == 0,
      );
      expect(panelAnchor, findsWidgets);
      // The panel itself is frosted glass, so the effect reads on the photo.
      expect(
        find.descendant(of: panelAnchor, matching: find.byType(GlassCard)),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('carousel shows one dot per appointment', (tester) async {
      await pumpHome(tester, reduceMotion: true);
      expect(find.byType(PageView), findsOneWidget);
      final dots = find.byWidgetPredicate(
        (w) =>
            w is AnimatedContainer &&
            (w.decoration as BoxDecoration?)?.borderRadius ==
                BorderRadius.circular(T.rPill),
      );
      expect(dots, findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('hero panel fits at AX5 text scale (3.2)', (tester) async {
      // Pump the Home screen alone (no tab bar): the pre-existing
      // FloatingTabBar slot overflow at 3.2 is outside this task's scope —
      // this asserts the hero + pet cards never overflow.
      await tester.binding.setSurfaceSize(const Size(390, 844));
      await tester.pumpWidget(
        AppScope(
          store: AppStore(now: fixedNow()),
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: const HomeScreen(),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: const TextScaler.linear(3.2),
                  disableAnimations: true,
                ),
                child: child!,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      // At 3.2 the sliver children below the fold are built lazily — scroll
      // the hero into view like a user would, then assert nothing overflowed.
      expect(await revealHome(tester, find.text('Next appointment')), isTrue);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // The hero is on screen and intact, not clipped away.
      expect(find.text('Next appointment'), findsWidgets);
    });

    testWidgets('a single appointment renders with no paging chrome', (
      tester,
    ) async {
      final s = AppStore(now: fixedNow())..cancelAppointment('a2');
      await pumpHome(tester, store: s);
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Next appointment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('zero appointments keeps the empty hero', (tester) async {
      final s = AppStore(now: fixedNow())
        ..cancelAppointment('a1')
        ..cancelAppointment('a2');
      await pumpHome(tester, store: s);
      expect(find.text('Nothing booked yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('home polish — GlassPill', () {
    testWidgets('renders its label with a glass blur', (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: const Center(child: GlassPill(label: 'Dog')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dog'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(GlassPill),
          matching: find.byType(BackdropFilter),
        ),
        findsOneWidget,
      );
    });
  });

  group('home polish — PressScale hover', () {
    testWidgets('hover layer is a MouseRegion and taps still fire', (
      tester,
    ) async {
      var tapped = 0;
      await tester.pumpWidget(
        CupertinoApp(
          theme: themeFor(AppPalette.light),
          home: Center(
            child: PressScale(
              onTap: () => tapped++,
              child: const Text('press me'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Additive hover affordance: present in the tree, no new semantics node.
      expect(
        find.descendant(
          of: find.byType(PressScale),
          matching: find.byType(MouseRegion),
        ),
        findsOneWidget,
      );
      // Touch behavior unchanged: a tap fires exactly once.
      await tester.tap(find.text('press me'));
      await tester.pumpAndSettle();
      expect(tapped, 1);
    });
  });
}
