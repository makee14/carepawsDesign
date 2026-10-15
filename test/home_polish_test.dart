import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepaws/app.dart';
import 'package:carepaws/data/seed.dart';
import 'package:carepaws/design/icons.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/screens/appointments/appointment_detail_screen.dart';
import 'package:carepaws/screens/home_screen.dart';
import 'package:carepaws/state/app_store.dart';
import 'package:carepaws/widgets/common.dart';
import 'package:carepaws/widgets/hero_card.dart';

DateTime fixedNow() => DateTime(2026, 10, 13, 9, 40);

/// Boots the real RootShell (home tab) at iPhone dimensions.
///
/// NOTE: uses `tester.view.physicalSize`, not `setSurfaceSize` — the latter
/// only resizes the render view and leaves `MediaQuery.sizeOf` at the 800x600
/// test default, so responsive code (`wide` breakpoints) would test the wrong
/// layout. physicalSize keeps MediaQuery and rendering consistent.
Future<void> pumpHome(
  WidgetTester tester, {
  AppStore? store,
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
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

  group('home redesign — greeting, promo carousel, appointment card', () {
    testWidgets('greeting row: greeting left, icons right, no subtitle', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(find.textContaining('Good morning'), findsOneWidget);
      // The "Biscuit's visit…" subtitle is gone.
      expect(find.textContaining('Biscuit’s visit'), findsNothing);
      expect(find.textContaining('Here is today'), findsNothing);
      // Notification + search icons share the greeting row.
      expect(
        find.byWidgetPredicate((w) => w is IconTap && w.path == Ic.bell),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is IconTap && w.path == Ic.search),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('promo carousel renders the seeded promos', (tester) async {
      await pumpHome(tester, reduceMotion: true);
      expect(find.text('Fresh cut season'), findsOneWidget);
      expect(find.text('Book grooming'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('next appointment is a HeroCard with a countdown chip', (
      tester,
    ) async {
      await pumpHome(tester, reduceMotion: true);
      expect(find.text('Next appointment'), findsOneWidget);
      expect(find.byType(HeroCard), findsOneWidget);
      expect(find.text('Vet Consultation — Biscuit'), findsOneWidget);
      expect(find.text('in 3d'), findsOneWidget);
      expect(find.text('Dr. Rafael Alvarez'), findsOneWidget);
      expect(find.text('View all'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the appointment card opens the detail', (
      tester,
    ) async {
      await pumpHome(tester, reduceMotion: true);
      await tester.tap(find.byType(HeroCard));
      await tester.pumpAndSettle();
      expect(find.byType(AppointmentDetailScreen), findsOneWidget);
    });

    testWidgets('zero appointments keeps an in-slot empty state with CTA', (
      tester,
    ) async {
      final s = AppStore(now: fixedNow())
        ..cancelAppointment('a1')
        ..cancelAppointment('a2');
      await pumpHome(tester, store: s);
      // Section header stays; the slot shows a CTA, never a hole.
      expect(find.text('Next appointment'), findsOneWidget);
      expect(find.text('Nothing booked yet'), findsOneWidget);
      expect(find.text('Book an appointment'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('clinic card collapses to essentials and expands on tap', (
      tester,
    ) async {
      await pumpHome(tester, reduceMotion: true);
      expect(
        await revealHome(tester, find.text('CarePaws Veterinary Clinic')),
        isTrue,
      );
      // Collapsed: name + open/closed status, no address/phone/hours.
      expect(find.textContaining('Open now'), findsWidgets);
      expect(find.text(Seed.clinicAddress), findsNothing);
      expect(find.text('Hours'), findsNothing);
      // The card sits at the very bottom — scroll to max extent so it sits
      // clear of the floating tab-bar overlay and the tap lands on it.
      final scrollable = find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      for (var i = 0; i < 6; i++) {
        await tester.drag(scrollable, const Offset(0, -220));
        await tester.pumpAndSettle();
      }
      // Tap expands the full info inline.
      await tester.tap(find.text('CarePaws Veterinary Clinic'));
      await tester.pumpAndSettle();
      expect(find.text(Seed.clinicAddress), findsOneWidget);
      expect(find.text(Seed.clinicPhone), findsOneWidget);
      expect(find.text('Hours'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('home fits at AX5 text scale (3.2)', (tester) async {
      // Pump the Home screen alone (no tab bar): the pre-existing
      // FloatingTabBar slot overflow at 3.2 is outside this task's scope —
      // this asserts the redesigned sections never overflow.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
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
      // Scroll through every section like a user would; nothing may overflow.
      for (final label in [
        'Next appointment',
        'My Pets',
        'Care reminders',
        'CarePaws Veterinary Clinic',
      ]) {
        expect(await revealHome(tester, find.text(label)), isTrue);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
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
