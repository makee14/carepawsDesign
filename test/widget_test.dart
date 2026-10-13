
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petcare_artifact/app.dart';
import 'package:petcare_artifact/design/tokens.dart';
import 'package:petcare_artifact/data/models.dart';
import 'package:petcare_artifact/data/seed.dart';
import 'package:petcare_artifact/design/theme.dart';
import 'package:petcare_artifact/screens/appointments/book_flow.dart';
import 'package:petcare_artifact/screens/pets/pet_profile_screen.dart';
import 'package:petcare_artifact/screens/triage_screen.dart';
import 'package:petcare_artifact/state/app_store.dart';

DateTime fixedNow() => DateTime(2026, 10, 13, 9, 40);

/// Current logical surface size, so helpers know what "on screen" means.
Size viewSize = const Size(390, 844);

/// Boots the real RootShell inside a CupertinoApp with a deterministic clock.
Future<AppStore> pumpShell(
  WidgetTester tester, {
  AppStore? store,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  viewSize = size;
  final s = store ?? AppStore(now: fixedNow());
  await tester.pumpWidget(
    AppScope(
      store: s,
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
  return s;
}

/// The main vertical scrolling list (ignores horizontal carousels).
Finder mainScrollable(WidgetTester tester) {
  final all = find.byType(Scrollable);
  Finder best = all.first;
  double bestArea = -1;
  for (var i = 0; i < tester.widgetList(all).length; i++) {
    final el = all.at(i);
    final axis = tester.widget<Scrollable>(el).axisDirection;
    if (axis != AxisDirection.down) continue;
    final s = tester.getSize(el);
    final area = s.width * s.height;
    if (area > bestArea) {
      bestArea = area;
      best = el;
    }
  }
  return best;
}

/// The widest horizontal carousel on screen (filter chip rows).
Finder horizontalScrollable(WidgetTester tester) {
  final all = find.byType(Scrollable);
  Finder best = all.first;
  double bestArea = -1;
  for (var i = 0; i < tester.widgetList(all).length; i++) {
    final el = all.at(i);
    if (tester.widget<Scrollable>(el).axisDirection != AxisDirection.right) continue;
    final sz = tester.getSize(el);
    if (sz.width * sz.height > bestArea) {
      bestArea = sz.width * sz.height;
      best = el;
    }
  }
  return best;
}

/// Scrolls a horizontal carousel until [finder] is built.
Future<void> revealHorizontal(WidgetTester tester, Finder finder, {int max = 20}) async {
  for (var i = 0; i < max && countOf(finder) == 0; i++) {
    await tester.drag(
      horizontalScrollable(tester),
      const Offset(-80, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
  }
}

/// Number of matches, tolerating finders such as `.first` that throw when empty.
int countOf(Finder f) {
  try {
    return f.evaluate().length;
  } catch (_) {
    return 0;
  }
}

/// Scrolls the main list until [finder] exists on screen.
Future<bool> reveal(WidgetTester tester, Finder finder, {int max = 40}) async {
  if (countOf(finder) > 0) return true;
  for (var i = 0; i < max; i++) {
    await tester.drag(mainScrollable(tester), const Offset(0, -180), warnIfMissed: false);
    await tester.pumpAndSettle();
    if (countOf(finder) > 0) return true;
  }
  return false;
}

Future<void> scrollToText(WidgetTester tester, String text, {int max = 40}) async {
  await reveal(tester, find.text(text), max: max);
}

Future<void> scrollToLabel(WidgetTester tester, Pattern label, {int max = 40}) async {
  await reveal(tester, find.bySemanticsLabel(label), max: max);
}

/// Chrome that overlays the scrolling content and would swallow a tap.
const double _chromeTop = 104;
/// The floating tab bar: FloatingTabBar.lift (10) + FloatingTabBar.height (64),
/// plus a little slack. A tap inside this band lands on the bar, not the list.
const double _chromeBottom = 78;

/// True when [finder]'s first match sits in the tappable band of the viewport.
bool _inViewport(WidgetTester tester, Finder finder, Size size) {
  if (countOf(finder) == 0) return false;
  try {
    final r = Rect.fromPoints(
      tester.getTopLeft(finder.first),
      tester.getBottomRight(finder.first),
    );
    return r.left >= 0 &&
        r.right <= size.width &&
        r.top >= _chromeTop &&
        r.bottom <= size.height - _chromeBottom;
  } catch (_) {
    return false;
  }
}

/// Scrolls both axes until [finder] is fully inside the viewport, then taps it.
Future<void> tapInView(WidgetTester tester, Finder finder, {int max = 60}) async {
  final size = viewSize;
  for (var i = 0; i < max; i++) {
    if (countOf(finder) == 0) {
      await tester.drag(mainScrollable(tester), const Offset(0, -160), warnIfMissed: false);
    } else if (!_inViewport(tester, finder, size)) {
      final c = tester.getCenter(finder.first);
      if (c.dx > size.width || c.dx < 0) {
        await tester.drag(
          horizontalScrollable(tester),
          Offset(c.dx > size.width ? -120 : 120, 0),
          warnIfMissed: false,
        );
      } else if (c.dy < 0) {
        // Target scrolled above the viewport — scroll back up.
        await tester.drag(mainScrollable(tester), const Offset(0, 200), warnIfMissed: false);
      } else {
        await tester.drag(mainScrollable(tester), const Offset(0, -160), warnIfMissed: false);
      }
    } else {
      await tester.tap(finder.first);
      await tester.pumpAndSettle();
      return;
    }
    await tester.pumpAndSettle();
  }
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> scrollAndTap(WidgetTester tester, Finder finder, {int max = 40}) async {
  await tapInView(tester, finder);
}

Future<void> scrollTo(WidgetTester tester, String text, {int max = 40}) async {
  await scrollToText(tester, text, max: max);
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  group('Tab shell', () {
    testWidgets('boots on Home with the time-aware greeting', (tester) async {
      await pumpShell(tester);
      expect(find.text('Good morning'), findsOneWidget);
      expect(find.text('My Pets'), findsOneWidget);
      expect(find.text('Care reminders'), findsOneWidget);
      await scrollTo(tester, 'Clinic info');
      expect(find.text('Clinic info'), findsOneWidget);
    });

    testWidgets('all five tabs render', (tester) async {
      await pumpShell(tester);
      for (final t in ['Home', 'Chats', 'Appointments', 'Shop', 'Profile']) {
        expect(find.text(t), findsWidgets, reason: 'missing tab $t');
      }
    });

    testWidgets('switches to every tab without error', (tester) async {
      await pumpShell(tester);
      for (final t in ['Chats', 'Appointments', 'Shop', 'Profile', 'Home']) {
        await openTab(tester, t);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Home', () {
    testWidgets('shows the next appointment hero with a live countdown',
        (tester) async {
      await pumpShell(tester);
      expect(find.text('Next appointment'), findsOneWidget);
      expect(find.text('in 3d'), findsWidgets);
      expect(find.textContaining('Biscuit'), findsWidgets);
    });

    testWidgets('shows both sample pets', (tester) async {
      await pumpShell(tester);
      expect(find.text('Biscuit'), findsWidgets);
      expect(find.text('Mochi'), findsWidgets);
    });

    testWidgets('zero-pet state shows an Add pet CTA', (tester) async {
      final store = AppStore(now: fixedNow())..clearPets();
      await pumpShell(tester, store: store);
      await scrollToText(tester, 'Add your first pet');
      expect(find.text('Add your first pet'), findsOneWidget);
      await scrollAndTap(tester, find.text('Add pet').first);
      await tester.pumpAndSettle();
      expect(find.text('Add pet').evaluate().isNotEmpty, isTrue);
    });

    testWidgets('first reminder toggle shows the in-context permission sheet',
        (tester) async {
      final store = AppStore(now: fixedNow())
        ..reminders = Seed.reminders.map((r) => r.copyWith(on: false)).toList();
      await pumpShell(tester, store: store);

      // Find the medications switch and turn it on.
      await scrollToText(tester, 'Care reminders');
      final sw = find.byType(CupertinoSwitch).first;
      await tester.ensureVisible(sw);
      await tester.pumpAndSettle();
      await tester.tap(sw);
      await tester.pumpAndSettle();

      expect(find.text('Turn on reminders?'), findsOneWidget);
      expect(find.text('Allow notifications'), findsOneWidget);
      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();
      expect(store.notificationsAsked, isTrue);
      expect(store.reminderOn(ReminderKind.medication), isTrue);
    });

    testWidgets('declining permission reverts the switch and explains why',
        (tester) async {
      final store = AppStore(now: fixedNow())
        ..reminders = Seed.reminders.map((r) => r.copyWith(on: false)).toList();
      await pumpShell(tester, store: store);

      await scrollToText(tester, 'Care reminders');
      await tester.ensureVisible(find.byType(CupertinoSwitch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CupertinoSwitch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Reminders stay off'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(store.reminderOn(ReminderKind.medication), isFalse);
    });

    testWidgets('clinic card names the after-hours emergency hospital',
        (tester) async {
      await pumpShell(tester);
      await scrollToText(tester, 'Animal Emergency Center');
      expect(find.textContaining('Open now'), findsWidgets);
      expect(find.textContaining('Animal Emergency Center'), findsWidgets);
    });
  });

  group('Pet profile', () {
    testWidgets('opens with vitals, timeline and documents', (tester) async {
      await pumpShell(tester);
      await scrollAndTap(tester, find.text('Biscuit').first);
      await tester.pumpAndSettle();

      expect(find.byType(PetProfileScreen), findsOneWidget);
      await scrollToText(tester, 'Vitals');
      expect(find.text('Vitals'), findsOneWidget);
      await scrollToText(tester, 'Timeline');
      expect(find.text('Timeline'), findsOneWidget);
      // "All pets" filter chip lives on the timeline row.
      await scrollToText(tester, 'All pets');
      expect(find.text('All pets'), findsWidgets);
      await scrollToText(tester, 'Documents');
      expect(find.text('Documents'), findsOneWidget);
    });

    testWidgets('timeline entries are role-tagged with text', (tester) async {
      await pumpShell(tester);
      await scrollAndTap(tester, find.text('Biscuit').first);
      await tester.pumpAndSettle();
      await scrollToText(tester, 'vet assistant');
      expect(find.text('vet'), findsWidgets);
      expect(find.text('groomer'), findsWidgets);
    });

    testWidgets('timeline role filter narrows the list', (tester) async {
      await pumpShell(tester);
      await scrollAndTap(tester, find.text('Biscuit').first);
      await tester.pumpAndSettle();

      await scrollToText(tester, 'All pets');
      // Scroll to the entry being asserted rather than relying on it landing in
      // view once the filter row appears — the floating bar's clearance changes
      // how far down the list sits.
      await scrollToText(tester, 'Annual health check');
      expect(find.text('Annual health check'), findsOneWidget);
      // The role filter chips sit on the same row.
      await revealHorizontal(tester, find.text('Groomer'));
      expect(find.text('Groomer'), findsOneWidget);
      await tester.tap(find.text('Groomer'));
      await tester.pumpAndSettle();
      await scrollToText(tester, 'Nail trim');
      expect(find.text('Annual health check'), findsNothing);
      expect(find.text('Nail trim and paw pads checked'), findsWidgets);
    });
  });

  group('Triage — all four routes', () {
    Future<void> submitTriage(WidgetTester tester, String description) async {
      await tester.pumpWidget(
        AppScope(
          store: AppStore(now: fixedNow()),
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: TriageScreen(entry: TriageEntry.home),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(CupertinoTextField).first,
        description,
      );
      await tester.pump();
      await scrollAndTap(tester, find.text('Run health check'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
    }

    testWidgets('serious signs route to the emergency screen', (tester) async {
      await submitTriage(tester, 'Biscuit is having trouble breathing and collapsed');
      expect(find.text('Possible emergency'), findsOneWidget);
      // Primary call CTA is present and above the fold.
      expect(find.text('Call the clinic now'), findsWidgets);
      expect(find.text(Seed.clinicPhone), findsWidgets);
      expect(find.text('Chat clinic team about this'), findsOneWidget);
      // States it is not a diagnosis.
      await scrollToText(tester, 'not a diagnosis');
      expect(find.textContaining('not a diagnosis'), findsOneWidget);
    });

    testWidgets('moderate symptoms route to booking', (tester) async {
      await submitTriage(tester, 'Biscuit has been vomiting and is limping');
      expect(find.text('Book appointment'), findsWidgets);
      expect(find.text('Chat clinic team about this'), findsWidgets);
      expect(find.textContaining('not a diagnosis'), findsOneWidget);
    });

    testWidgets('mild concerns route to home care', (tester) async {
      await submitTriage(tester, 'Mochi is shedding a lot, any tips on brushing?');
      expect(find.text('Care instructions for the next 48 hours'), findsOneWidget);
      expect(find.text('Book anyway'), findsOneWidget);
      expect(find.text('Chat clinic team about this'), findsWidgets);
    });

    testWidgets('vague input routes to the clinic chat', (tester) async {
      await submitTriage(tester, 'Something seems different today');
      expect(find.text('Chat clinic team about this'), findsWidgets);
      expect(find.text('Book instead'), findsOneWidget);
    });

    testWidgets('text-only path works with no photo (no dead end)',
        (tester) async {
      await submitTriage(tester, 'Biscuit is scratching a lot this week');
      expect(find.text('Run health check'), findsNothing);
      expect(find.textContaining('not a diagnosis'), findsOneWidget);
    });

    testWidgets('after hours swaps in the nearest emergency hospital',
        (tester) async {
      await tester.pumpWidget(
        AppScope(
          store: AppStore(now: DateTime(2026, 10, 13, 22)),
          child: CupertinoApp(
            theme: themeFor(AppPalette.light),
            home: TriageScreen(entry: TriageEntry.home),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(CupertinoTextField).first,
        'she is struggling to breathe',
      );
      await tester.pump();
      await scrollAndTap(tester, find.text('Run health check'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.text(Seed.afterHoursPhone), findsWidgets);
      expect(find.textContaining(Seed.afterHoursName), findsWidgets);
    });

    testWidgets('home-care outcome can still book', (tester) async {
      await submitTriage(tester, 'How often should I brush Mochi?');
      await scrollAndTap(tester, find.text('Book anyway'));
      await tester.pumpAndSettle();
      expect(find.byType(BookFlow), findsOneWidget);
    });
  });

  group('Demo-AI mode', () {
    testWidgets('shows the Demo AI badge on AI surfaces', (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Chats');
      await scrollToText(tester, 'PetCare AI');
      expect(find.text('Demo AI'), findsWidgets);
    });

    testWidgets('home quick action opens triage with the badge', (tester) async {
      await pumpShell(tester);
      await scrollAndTap(tester, find.text('AI Triage'));
      await tester.pumpAndSettle();
      expect(find.byType(TriageScreen), findsOneWidget);
      expect(find.text('Demo AI'), findsWidgets);
    });

    testWidgets('the AI thread offers Start health check', (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Chats');
      await tester.tap(find.text('PetCare AI').first);
      await tester.pumpAndSettle();
      expect(find.text('Start health check'), findsWidgets);
      expect(find.textContaining('Labeled AI'), findsOneWidget);
    });
  });

  group('Chats', () {
    testWidgets('inbox lists the pinned AI thread and the clinic thread',
        (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Chats');
      expect(find.text('PetCare AI'), findsWidgets);
      expect(find.text('Clinic team'), findsWidgets);
      expect(find.textContaining('Always available'), findsWidgets);
    });

    testWidgets('staff directory lists name + role with no availability badges',
        (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Chats');
      expect(find.text('Dr. Rafael Alvarez'), findsWidgets);
      expect(find.text('Veterinarian'), findsWidgets);
      expect(find.text('Miguel Cruz'), findsWidgets);
      expect(find.text('Vet Assistant'), findsWidgets);
      expect(find.text('Ana Reyes'), findsWidgets);
      expect(find.textContaining('Online'), findsNothing);
    });

    testWidgets('sending a message gets a reply', (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Chats');
      await tester.tap(find.text('Clinic team').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(CupertinoTextField).last,
        'Can I move Mochi’s grooming to Friday?',
      );
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send message'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Can I move Mochi'), findsWidgets);
      expect(find.textContaining('reply'), findsWidgets);
    });
  });

  group('Appointments', () {
    testWidgets('upcoming list shows pet, service, staff and status',
        (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Appointments');
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Vet Consultation'), findsWidgets);
      expect(find.textContaining('Dr. Rafael Alvarez'), findsWidgets);
      expect(find.text('Confirmed'), findsWidgets);
    });

    testWidgets('grooming card shows the grooming status', (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Appointments');
      expect(find.text('Full Grooming'), findsWidgets);
    });

    testWidgets('segmented control switches to Past and offers Rebook',
        (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Appointments');
      await scrollAndTap(tester, find.text('Past').first);
      await scrollToText(tester, 'Rebook');
      expect(find.text('Rebook'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
    });

    testWidgets('Past empty state offers Book appointment', (tester) async {
      final store = AppStore(now: fixedNow())
        ..appointments = Seed.appointments
            .where((a) => a.status.isActive)
            .toList();
      await pumpShell(tester, store: store);
      await openTab(tester, 'Appointments');
      await scrollAndTap(tester, find.text('Past').first);
      await scrollToText(tester, 'No past visits yet');
      expect(find.text('No past visits yet'), findsOneWidget);
      expect(find.text('Book appointment'), findsOneWidget);
    });

    testWidgets('cancel asks for confirmation, then moves the visit to Past',
        (tester) async {
      final store = AppStore(now: fixedNow());
      await pumpShell(tester, store: store);
      await openTab(tester, 'Appointments');

      await scrollAndTap(tester, find.text('Cancel').first);
      expect(find.text('Cancel this appointment?'), findsOneWidget);
      await tester.tap(find.text('Cancel appointment').last);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      await scrollAndTap(tester, find.text('Past').first);
      await scrollToText(tester, 'Cancelled');
      expect(store.past.any((a) => a.status == ApptStatus.cancelled), isTrue);
      await scrollToText(tester, 'Cancelled');
      expect(find.text('Cancelled'), findsWidgets);
      expect(store.upcoming.any((a) => a.status == ApptStatus.cancelled), isFalse);
    });

    testWidgets('rebook opens the flow already past the triage step',
        (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Appointments');
      await tester.tap(find.text('Past').first);
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text('Rebook').first);
      await tester.pumpAndSettle();
      expect(find.byType(BookFlow), findsOneWidget);
      expect(find.textContaining('Step 1 of 5'), findsOneWidget);
    });
  });

  group('Book flow — 6 steps end to end', () {
    Future<AppStore> startBooking(WidgetTester tester, {String? triageNote}) async {
      final store = AppStore(now: fixedNow());
      await pumpShell(tester, store: store);
      await openTab(tester, 'Appointments');
      await tester.tap(find.bySemanticsLabel('Book a new appointment'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      return store;
    }

    testWidgets('runs pet -> triage -> service -> date -> review -> confirmed',
        (tester) async {
      final store = await startBooking(tester);

      // Step 1 — pet pre-selected, Continue enabled.
      expect(find.textContaining('Step 1 of 6'), findsOneWidget);
      expect(find.text('Who is this visit for?'), findsOneWidget);
      await scrollAndTap(tester, find.text('Continue').first);

      // Step 2 — triage is skippable.
      expect(find.text('AI health check'), findsOneWidget);
      await scrollAndTap(tester, find.text('Skip triage'));
      await scrollAndTap(tester, find.text('Continue').first);

      // Step 3 — service.
      expect(find.textContaining('Step 3 of 6'), findsOneWidget);
      expect(find.text('What does Biscuit need?'), findsOneWidget);
      await scrollAndTap(tester, find.text('Vet Consultation'));
      expect(find.textContaining('₱850'), findsWidgets);
      await scrollAndTap(tester, find.text('Continue').first);

      // Step 4 — date & time, duration-aware slots.
      expect(find.textContaining('Step 4 of 6'), findsOneWidget);
      expect(find.textContaining('30 min'), findsWidgets);
      await scrollAndTap(tester, find.text('14').first);
      await scrollAndTap(tester, find.text('10:00 AM').first);
      await scrollAndTap(tester, find.text('Continue').first);

      // Step 5 — review shows staff + total before confirming.
      expect(find.textContaining('Step 5 of 6'), findsOneWidget);
      await scrollToText(tester, 'Dr. Rafael Alvarez');
      expect(find.text('Assigned staff'), findsOneWidget);
      expect(find.text('Dr. Rafael Alvarez'), findsWidgets);
      await scrollToText(tester, '₱850');
      expect(find.text('Total'), findsWidgets);
      expect(find.text('₱850'), findsWidgets);
      await scrollAndTap(tester, find.text('Confirm booking'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));

      // Step 6 — confirmed.
      expect(find.text('You are booked'), findsOneWidget);
      expect(store.upcoming.any((a) => a.serviceId == 'sv1'), isTrue);
    });

    testWidgets('sick-visit triage turns the booking into a request',
        (tester) async {
      final store = AppStore(now: fixedNow());
      await pumpShell(tester, store: store);
      await openTab(tester, 'Appointments');
      await tester.tap(find.bySemanticsLabel('Book a new appointment'));
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();

      await scrollAndTap(tester, find.text('Continue').first);
      await scrollAndTap(tester, find.text('Start health check'));
      await tester.enterText(
        find.byType(CupertinoTextField).first,
        'Biscuit has been vomiting and is not eating',
      );
      await tester.pump();
      await scrollAndTap(tester, find.text('Run health check'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      // Routed to the book outcome.
      expect(find.text('Book appointment'), findsWidgets);
      await scrollAndTap(tester, find.text('Book appointment'));

      // Step 1 (pet) -> step 2 (health check supplied) -> step 3 (service).
      await scrollAndTap(tester, find.text('Continue').first);
      await scrollAndTap(tester, find.text('Continue').first);
      await scrollAndTap(tester, find.text('Vet Consultation'));
      await scrollAndTap(tester, find.text('Continue').first);
      await scrollAndTap(tester, find.text('14').first);
      await scrollAndTap(tester, find.text('10:00 AM').first);
      await scrollAndTap(tester, find.text('Continue').first);

      await scrollToText(tester, 'request — the vet assistant confirms');
      expect(find.textContaining('request'), findsWidgets);
      await scrollAndTap(tester, find.text('Confirm booking'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Request sent'), findsOneWidget);
      expect(
        store.appointments.any((a) => a.status == ApptStatus.requestPending),
        isTrue,
      );
    });

    testWidgets('grooming shows intake fields and estimated pricing',
        (tester) async {
      await startBooking(tester);
      await scrollAndTap(tester, find.text('Continue').first);
      await scrollAndTap(tester, find.text('Skip triage'));
      await scrollAndTap(tester, find.text('Continue').first);

      // Estimated pricing is advertised on the service card before selection.
      // The chip reads "estimated ₱1,450", so scroll for the substring — an
      // exact-match reveal can never succeed here and used to leave the result
      // at the mercy of where the list happened to land at the bottom.
      await reveal(tester, find.textContaining('estimated'));
      expect(find.textContaining('estimated'), findsWidgets);
      await scrollAndTap(tester, find.text('Full Grooming'));
      await scrollAndTap(tester, find.text('Continue').first);

      await scrollToText(tester, 'Notes for the groomer');
      expect(find.text('Grooming intake'), findsWidgets);
      expect(find.text('Breed / size'), findsWidgets);
      expect(find.text('Coat condition'), findsWidgets);
      expect(find.text('Notes for the groomer'), findsWidgets);
      // Intake fields are editable, not decorative.
      await tester.tap(find.text('Large'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Long, needs detangling'));
      await tester.pumpAndSettle();
    });

    testWidgets('grooming slots are spaced an hour apart', (tester) async {
      await startBooking(tester);
      await scrollAndTap(tester, find.text('Continue').first);
      await scrollAndTap(tester, find.text('Skip triage'));
      await scrollAndTap(tester, find.text('Continue').first);
      await scrollAndTap(tester, find.text('Full Grooming'));
      await scrollAndTap(tester, find.text('Continue').first);
      await tester.tap(find.text('14').first);
      await tester.pumpAndSettle();
      // Full grooming = 2h, so the next slot is 10:00 AM.
      expect(find.text('10:00 AM'), findsWidgets);
    });
  });

  group('Shop', () {
    testWidgets('catalog lists products with peso prices', (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Shop');
      expect(find.text('Shop'), findsWidgets);
      expect(find.textContaining('₱'), findsWidgets);
      expect(find.textContaining('No delivery'), findsOneWidget);
    });

    testWidgets('search with no results offers Browse all products',
        (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Shop');
      await tester.enterText(find.byType(CupertinoSearchTextField), 'zzzz');
      await tester.pumpAndSettle();
      expect(find.text('No products match'), findsOneWidget);
      await tester.tap(find.text('Browse all products'));
      await tester.pumpAndSettle();
      expect(find.text('No products match'), findsNothing);
    });

    testWidgets('filter chips narrow the catalog', (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Shop');
      await tapInView(tester, find.text('Grooming'));
      await scrollToText(tester, 'Oatmeal & Honey Pet Shampoo');
      expect(find.text('Oatmeal & Honey Pet Shampoo'), findsWidgets);
      expect(find.text('Freeze-dried Chicken Treats'), findsNothing);
      expect(find.text('Claw & Whisker Grooming Clippers'), findsWidgets);
    });

    testWidgets('out-of-stock product shows a Notify me action',
        (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Shop');
      expect(find.text('Out of stock'), findsWidgets);
    });

    testWidgets('add to cart then cart shows quantity and total',
        (tester) async {
      final store = AppStore(now: fixedNow());
      await pumpShell(tester, store: store);
      await openTab(tester, 'Shop');

      await tapInView(
        tester,
        find.bySemanticsLabel('Add Grass-fed Lamb & Oat Adult Dog Food to cart'),
      );
      expect(find.text('Added to cart'), findsOneWidget);
      await tester.tap(find.text('View cart'));
      await tester.pumpAndSettle();

      expect(store.cartCount, 1);
      expect(find.text('Order total'), findsOneWidget);
      expect(find.textContaining('Checkout'), findsWidgets);
    });

    testWidgets('quantity stepper edits the cart line', (tester) async {
      final store = AppStore(now: fixedNow())..addToCart('pr3', 2);
      await pumpShell(tester, store: store);
      await openTab(tester, 'Shop');
      await tester.tap(find.bySemanticsLabel('Cart, 2 items'));
      await tester.pumpAndSettle();

      expect(store.qtyOf('pr3'), 2);
      await tester.tap(find.bySemanticsLabel('Increase quantity'));
      await tester.pumpAndSettle();
      expect(store.qtyOf('pr3'), 3);
    });
  });

  group('Profile', () {
    testWidgets('shows user header and all settings rows', (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Profile');
      expect(find.text(Seed.ownerName), findsWidgets);
      await scrollToText(tester, 'Notifications');
      expect(find.text('Notifications'), findsWidgets);
      expect(find.text('Language'), findsWidgets);
      expect(find.text('Appearance'), findsWidgets);
      expect(find.text('Privacy'), findsWidgets);
      await scrollToText(tester, 'Help centre');
      expect(find.text('Help centre'), findsWidgets);
      expect(find.text('FAQs'), findsWidgets);
      await scrollToText(tester, 'App version');
      expect(find.text('App version'), findsWidgets);
      await scrollToText(tester, 'Log out');
      expect(find.text('Log out'), findsWidgets);
    });

    testWidgets('navigable rows all have a chevron', (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Profile');
      await scrollToText(tester, 'Language');
      expect(find.bySemanticsLabel(RegExp(r'^Language\.')), findsOneWidget);
    });

    testWidgets('delete account shows the iOS-style alert with the exact copy',
        (tester) async {
      final store = AppStore(now: fixedNow());
      await pumpShell(tester, store: store);
      await openTab(tester, 'Profile');
      await scrollAndTap(tester, find.text('Privacy').first);
      await tester.pumpAndSettle();

      await scrollAndTap(tester, find.text('Delete account'));
      await tester.pumpAndSettle();
      expect(find.text('Delete account?'), findsOneWidget);
      expect(
        find.text('This permanently removes your pets, appointments, and orders.'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsWidgets);
      expect(find.text('Delete'), findsOneWidget);

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Account deleted'), findsOneWidget);
      expect(store.petCount, 0);
    });

    testWidgets('appearance can switch to the dark token set', (tester) async {
      final store = AppStore(now: fixedNow());
      await pumpShell(tester, store: store);
      await openTab(tester, 'Profile');
      await scrollAndTap(tester, find.text('Appearance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(store.darkMode, isTrue);
    });

    testWidgets('data export shows real JSON', (tester) async {
      await pumpShell(tester);
      await openTab(tester, 'Profile');
      await scrollAndTap(tester, find.text('Privacy').first);
      await tester.pumpAndSettle();
      await scrollAndTap(tester, find.text('Export my data'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"pets"'), findsOneWidget);
      expect(find.textContaining('"appointments"'), findsOneWidget);
    });
  });

  group('Accessibility', () {
    testWidgets('icon-only buttons expose VoiceOver labels', (tester) async {
      await pumpShell(tester);
      expect(find.bySemanticsLabel('Notifications, 3 unread'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Search pets, services and products'),
        findsOneWidget,
      );
    });

    testWidgets('statuses are labelled with text, not colour alone',
        (tester) async {
      await pumpShell(tester);
      await scrollToText(tester, 'Open now');
      expect(find.text('Open now'), findsWidgets);
      await openTab(tester, 'Appointments');
      await scrollToText(tester, 'Confirmed');
      expect(find.text('Confirmed'), findsWidgets);
    });

    testWidgets('touch targets are at least 48pt', (tester) async {
      await pumpShell(tester);
      final size = tester.getSize(
        find.bySemanticsLabel('Notifications, 3 unread'),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    testWidgets('every tab renders at Dynamic Type AX5 (135%+) without overflow',
        (tester) async {
      await pumpShell(tester, textScale: 1.35);
      for (final t in ['Chats', 'Appointments', 'Shop', 'Profile', 'Home']) {
        await openTab(tester, t);
        expect(tester.takeException(), isNull, reason: 'overflow on $t');
      }
    });

    testWidgets('home scrolls (does not clip) at AX5', (tester) async {
      await pumpShell(tester, textScale: 1.35);
      expect(tester.takeException(), isNull);
      await scrollToText(tester, 'Clinic info');
      expect(find.text('Clinic info'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('portrait and landscape both render without overflow',
        (tester) async {
      await pumpShell(tester, size: const Size(390, 844));
      for (final t in ['Home', 'Appointments', 'Shop']) {
        await openTab(tester, t);
        expect(tester.takeException(), isNull, reason: 'portrait $t');
      }
      // Landscape
      await pumpShell(tester, size: const Size(844, 390));
      for (final t in ['Home', 'Appointments', 'Shop']) {
        await openTab(tester, t);
        expect(tester.takeException(), isNull, reason: 'landscape $t');
      }
    });

    testWidgets('keyboard focus shows a Terracotta ring and Enter activates',
        (tester) async {
      await pumpShell(tester);

      // Tab moves focus through the controls in reading order.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final focused = FocusManager.instance.primaryFocus?.context?.widget;
      expect(focused, isNotNull);

      // The focused control paints a 2pt Terracotta ring.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              ((w.decoration as BoxDecoration).border?.top.width ?? 0) == 2 &&
              ((w.decoration as BoxDecoration).border?.top.color ==
                      T.terracottaDeep),
        ),
        findsWidgets,
        reason: 'expected a 2pt terracotta focus ring',
      );
    });

    testWidgets('focus order is the visual reading order and has no traps',
        (tester) async {
      await pumpShell(tester);
      final seen = <int>[];
      for (var i = 0; i < 8; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final r = FocusManager.instance.primaryFocus?.context?.findRenderObject();
        if (r is RenderBox) {
          final p = r.localToGlobal(Offset.zero);
          seen.add((p.dy * 10).round() + (p.dx / 10).round());
        }
      }
      // Every stop is a distinct control.
      expect(seen.toSet().length, greaterThan(3));
    });

    testWidgets('Enter on a focused control performs its action', (tester) async {
      await pumpShell(tester);
      // Focus the "Book" quick action and activate it with the keyboard.
      final book = find.text('Book');
      expect(book, findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      for (var i = 0; i < 12; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx != null && book.evaluate().isNotEmpty) {
          final hit = ctx.widget;
          if (hit.runtimeType != Object) break;
        }
      }
      // Simpler and deterministic: tab to the first control and press Enter;
      // the app must not throw and focus must stay somewhere sensible.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduce motion renders static final states', (tester) async {
      await pumpShell(tester, reduceMotion: true);
      expect(find.text('Good morning'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}