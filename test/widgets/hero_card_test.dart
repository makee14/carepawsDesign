import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/widgets/hero_card.dart';

/// Pumps [card] at a fixed 360pt width, iPhone-size surface.
Future<void> pumpCard(
  WidgetTester tester,
  Widget card, {
  double textScale = 1,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    CupertinoApp(
      theme: themeFor(AppPalette.light),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        );
      },
      home: CupertinoPageScaffold(
        child: Center(child: SizedBox(width: 360, child: card)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget testImage(Key key) =>
    Container(key: key, color: const Color(0xFFE4843E));

void main() {
  testWidgets('renders title, description and detail rows', (tester) async {
    await pumpCard(
      tester,
      HeroCard(
        image: testImage(const Key('img')),
        title: 'Checkup — Biscuit',
        description: 'Annual wellness exam',
        details: const [Text('detail row')],
        onTap: () {},
      ),
    );
    expect(find.text('Checkup — Biscuit'), findsOneWidget);
    expect(find.text('Annual wellness exam'), findsOneWidget);
    expect(find.text('detail row'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single outer clip with the card radius', (tester) async {
    await pumpCard(
      tester,
      HeroCard(image: testImage(const Key('img')), title: 'T', onTap: () {}),
    );
    final clips = tester.widgetList<ClipRRect>(find.byType(ClipRRect));
    // The plain-Container test image brings no clip of its own: exactly the
    // one outer ClipRRect the contract mandates.
    expect(clips, hasLength(1));
    expect(clips.single.borderRadius, BorderRadius.circular(22));
  });

  testWidgets('image fills ~75% of the minimum card height plus overlap', (
    tester,
  ) async {
    await pumpCard(
      tester,
      HeroCard(image: testImage(const Key('img')), title: 'T', onTap: () {}),
    );
    // minH = 360 / (4/3) = 270; imageH = 270 * 0.75 + 12 = 214.5.
    expect(tester.getSize(find.byKey(const Key('img'))).height, 214.5);
  });

  testWidgets('tap fires onTap; no onTap means no button semantics', (
    tester,
  ) async {
    var tapped = 0;
    await pumpCard(
      tester,
      HeroCard(
        image: testImage(const Key('img')),
        title: 'T',
        onTap: () => tapped++,
      ),
    );
    await tester.tap(find.byType(HeroCard));
    await tester.pumpAndSettle();
    expect(tapped, 1);

    await pumpCard(
      tester,
      HeroCard(image: testImage(const Key('img')), title: 'T'),
    );
    // No onTap: the card does not present itself as a button.
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'T' &&
            w.properties.button == false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('AX5: panel grows, nothing clips', (tester) async {
    // In a scrollable, like every real screen: the card grows instead of
    // clipping, and the page scrolls.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      CupertinoApp(
        theme: themeFor(AppPalette.light),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: const TextScaler.linear(3.2)),
            child: child!,
          );
        },
        home: CupertinoPageScaffold(
          child: SingleChildScrollView(
            child: Center(
              child: SizedBox(
                width: 360,
                child: HeroCard(
                  image: testImage(const Key('img')),
                  title: 'A very long appointment title that must wrap or ellipsize',
                  description: 'A much longer description that exercises the two-line ellipsis path under large Dynamic Type without pushing anything off the card.',
                  details: const [
                    Text('Sat, 17 Oct · 10:30 AM with Dr. Rafael Alvarez'),
                    Text('Second detail row with even more text in it'),
                  ],
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // The card grew past its 4/3 minimum to fit the panel.
    final cardH = tester.getSize(find.byType(HeroCard)).height;
    expect(cardH, greaterThan(360 / (4 / 3)));
  });

  testWidgets('16/10 reads shorter than the 4/3 default', (tester) async {
    await pumpCard(
      tester,
      HeroCard(image: testImage(const Key('img')), title: 'T', onTap: () {}),
    );
    final defaultH = tester.getSize(find.byType(HeroCard)).height;

    await pumpCard(
      tester,
      HeroCard(
        aspectRatio: 16 / 10,
        image: testImage(const Key('img')),
        title: 'T',
        onTap: () {},
      ),
    );
    final wideH = tester.getSize(find.byType(HeroCard)).height;
    // Same panel, smaller minimum: the 16/10 card reads subordinate to the
    // 140pt promo carousel.
    expect(wideH, lessThan(defaultH));
  });
}
