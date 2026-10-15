import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepaws/data/models.dart';
import 'package:carepaws/design/theme.dart';
import 'package:carepaws/widgets/product_card.dart';

Product product({
  String id = 't1',
  String name = 'Test Food',
  int stock = 5,
  bool restricted = false,
}) => Product(
  id: id,
  name: name,
  tagline: '1 kg pouch',
  description: 'desc',
  price: 250,
  stock: stock,
  species: const [Species.dog],
  need: PetNeed.food,
  icon: 'bag',
  art: 0,
  restricted: restricted,
);

Future<void> pumpCard(WidgetTester tester, Widget card) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    CupertinoApp(
      theme: themeFor(AppPalette.light),
      home: CupertinoPageScaffold(
        child: Center(child: SizedBox(width: 200, child: card)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders entirely from Product data', (tester) async {
    await pumpCard(tester, ProductCard(product: product(), onTap: () {}));
    expect(find.text('Test Food'), findsOneWidget);
    expect(find.text('1 kg pouch'), findsOneWidget);
    expect(find.text('₱250'), findsOneWidget);
    // In stock and unrestricted: no badge at all (cleaner).
    expect(find.text('Out of stock'), findsNothing);
    expect(find.text('Rx'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('out-of-stock badge when stock is zero', (tester) async {
    await pumpCard(
      tester,
      ProductCard(product: product(stock: 0), onTap: () {}),
    );
    expect(find.text('Out of stock'), findsOneWidget);
    expect(find.text('Rx'), findsNothing);
  });

  testWidgets('Rx badge when restricted and in stock', (tester) async {
    await pumpCard(
      tester,
      ProductCard(product: product(restricted: true), onTap: () {}),
    );
    expect(find.text('Rx'), findsOneWidget);
    expect(find.text('Out of stock'), findsNothing);
  });

  testWidgets('tap fires onTap', (tester) async {
    var tapped = 0;
    await pumpCard(
      tester,
      ProductCard(product: product(), onTap: () => tapped++),
    );
    await tester.tap(find.byType(ProductCard));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('AX5: no clipping', (tester) async {
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
          child: Center(
            child: SizedBox(
              width: 200,
              child: ProductCard(
                product: product(
                  name: 'An extremely long product name that must ellipsize',
                ),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AX5: out-of-stock badge does not overflow', (tester) async {
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
          child: Center(
            child: SizedBox(
              width: 200,
              child: ProductCard(product: product(stock: 0), onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // The badge flexes and ellipsizes instead of overflowing the Row.
    expect(find.text('Out of stock'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
