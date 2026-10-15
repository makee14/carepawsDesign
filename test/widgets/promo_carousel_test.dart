import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/data/models.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/widgets/promo_carousel.dart';

const promos = [
  Promo(
    id: 'p1',
    title: 'Fresh cut season',
    subtitle: 'Full grooms from ₱850',
    art: 4,
    ctaLabel: 'Book grooming',
    route: 'book',
  ),
  Promo(
    id: 'p2',
    title: 'Vaccination drive',
    subtitle: 'Walk-in boosters Saturdays',
    art: 5,
    ctaLabel: 'Learn more',
    route: 'book',
  ),
  Promo(
    id: 'p3',
    title: 'New in the shop',
    subtitle: 'Pickup at the clinic',
    art: 6,
    ctaLabel: 'Browse shop',
    route: 'shop',
  ),
];

/// Active-dot widths: the page indicator is the honest record of which page
/// is current (PageView pre-builds adjacent pages, so text finders see
/// offstage titles too). Measured after settle, so the implicit animation
/// has landed on its final width.
List<double> dotWidths(WidgetTester tester) {
  final dots = find.descendant(
    of: find.byType(PromoCarousel),
    matching: find.byType(AnimatedContainer),
  );
  return [
    for (var i = 0; i < dots.evaluate().length; i++)
      tester.getSize(dots.at(i)).width,
  ];
}

Future<void> pumpCarousel(
  WidgetTester tester,
  Widget carousel, {
  bool reduceMotion = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    CupertinoApp(
      theme: themeFor(AppPalette.light),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(disableAnimations: reduceMotion),
          child: child!,
        );
      },
      home: CupertinoPageScaffold(child: carousel),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the first promo and page indicators', (tester) async {
    await pumpCarousel(
      tester,
      const PromoCarousel(promos: promos, autoAdvance: false),
    );
    expect(find.text('Fresh cut season'), findsOneWidget);
    expect(find.text('Book grooming'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty promos render nothing', (tester) async {
    await pumpCarousel(
      tester,
      const PromoCarousel(promos: [], autoAdvance: false),
    );
    expect(find.byType(PromoCarousel), findsOneWidget);
    expect(find.text('Fresh cut season'), findsNothing);
  });

  testWidgets('CTA tap reports the promo', (tester) async {
    Promo? tapped;
    await pumpCarousel(
      tester,
      PromoCarousel(
        promos: promos,
        autoAdvance: false,
        onCta: (p) => tapped = p,
      ),
    );
    await tester.tap(find.text('Book grooming'));
    await tester.pumpAndSettle();
    expect(tapped?.id, 'p1');
  });

  testWidgets('swiping changes the page', (tester) async {
    await pumpCarousel(
      tester,
      const PromoCarousel(promos: promos, autoAdvance: false),
    );
    expect(dotWidths(tester), [18.0, 6.0, 6.0]);
    await tester.drag(find.byType(PageView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(dotWidths(tester), [6.0, 18.0, 6.0]);
  });

  testWidgets('reduced motion: no auto-advance timer fires', (tester) async {
    await pumpCarousel(
      tester,
      const PromoCarousel(promos: promos),
      reduceMotion: true,
    );
    expect(dotWidths(tester), [18.0, 6.0, 6.0]);
    // Fake-async clock: a periodic timer would fire here and turn the page.
    await tester.pump(const Duration(seconds: 12));
    expect(dotWidths(tester), [18.0, 6.0, 6.0]);
  });

  testWidgets('auto-advance turns the page when motion is allowed', (
    tester,
  ) async {
    await pumpCarousel(tester, const PromoCarousel(promos: promos));
    expect(dotWidths(tester), [18.0, 6.0, 6.0]);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(dotWidths(tester), [6.0, 18.0, 6.0]);
    // Teardown asserts zero pending timers — dispose() cancelling them is
    // what keeps this green.
  });
}
