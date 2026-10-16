import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../data/models.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/nav_actions.dart';
import '../widgets/product_card.dart';
import 'shop/cart_screen.dart';
import 'shop/orders_screen.dart';
import 'shop/product_detail_screen.dart';

/// SHOPS — catalog with search and filter chips, pickup only.
class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  String _query = '';
  PetNeed _need = PetNeed.all;
  Species? _species;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;

    final results = store.products.where((prod) {
      final q = _query.trim().toLowerCase();
      final matchesQuery =
          q.isEmpty ||
          prod.name.toLowerCase().contains(q) ||
          prod.tagline.toLowerCase().contains(q) ||
          prod.description.toLowerCase().contains(q);
      final matchesNeed = _need == PetNeed.all || prod.need == _need;
      final matchesSpecies =
          _species == null || prod.species.contains(_species!);
      return matchesQuery && matchesNeed && matchesSpecies;
    }).toList();

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      child: CustomScrollView(
        slivers: [
          const LargeTitleBar(title: 'Shop'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(T.s16, 4, T.s16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search field and its actions share one row.
                  Row(
                    children: [
                      Expanded(
                        child: CupertinoSearchTextField(
                          placeholder: 'Search food, medicine, grooming',
                          style: Type.body(p),
                          placeholderStyle: Type.body(p)
                              .copyWith(color: p.textSecondary),
                          onChanged: (v) => setState(() => _query = v),
                          backgroundColor: p.surface,
                          itemColor: p.textSecondary,
                          borderRadius: BorderRadius.circular(T.rControl),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      NavActions(
                        actions: [
                          IconTap(
                            path: Ic.doc,
                            label: 'My orders',
                            color: p.primaryFill,
                            onPressed: () =>
                                Navigator.of(context)
                                    .push(appRoute(const OrdersScreen())),
                          ),
                          _CartBadge(),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        FilterPill(
                          label: 'All',
                          selected: _need == PetNeed.all,
                          onTap: () => setState(() => _need = PetNeed.all),
                        ),
                        for (final n in PetNeed.values.skip(1)) ...[
                          const SizedBox(width: 8),
                          FilterPill(
                            label: n.label,
                            selected: _need == n,
                            onTap: () => setState(() => _need = n),
                          ),
                        ],
                        const SizedBox(width: 8),
                        FilterPill(
                          label: 'For dogs',
                          icon: Ic.dog,
                          selected: _species == Species.dog,
                          onTap: () => setState(
                            () => _species = _species == Species.dog
                                ? null
                                : Species.dog,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilterPill(
                          label: 'For cats',
                          icon: Ic.cat,
                          selected: _species == Species.cat,
                          onTap: () => setState(
                            () => _species = _species == Species.cat
                                ? null
                                : Species.cat,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Ic.svg(Ic.truck, color: p.textSecondary, size: 15),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'No delivery — pickup at the clinic counter.',
                          style: Type.caption(p),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          if (results.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: EmptyState(
                  icon: Ic.search,
                  title: 'No products match',
                  body:
                      'Nothing matches “$_query” in this category. Browse everything instead.',
                  actionLabel: 'Browse all products',
                  onAction: () => setState(() {
                    _query = '';
                    _need = PetNeed.all;
                    _species = null;
                  }),
                ),
              ),
            )
          else
            // SliverLayoutBuilder (not MediaQuery) decides the column count:
            // it measures the width the grid actually gets, so split-screen
            // and test harnesses can't disagree with it.
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final screenW = constraints.crossAxisExtent;
                final cols = screenW >= 700 ? 3 : 2;
                final cardW = (screenW - T.s16 * 2 - T.s12 * (cols - 1)) / cols;
                // Contract anatomy: 4:3 image + ~106pt text block at 1.0x
                // (s12, name 2 lines, tagline, s8, price row, s12). The text
                // block scales with Dynamic Type so the card grows at AX5
                // instead of clipping (sweep gate); Stream A re-tunes this
                // against its measured card at merge if needed.
                final textScale = MediaQuery.textScalerOf(context)
                    .scale(1)
                    .clamp(1.0, 3.2);
                final cellH = cardW * 3 / 4 + 106 * textScale;
                return SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    T.s16,
                    0,
                    T.s16,
                    40 + TabBarClearance.of(context),
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: T.s12,
                      crossAxisSpacing: T.s12,
                      childAspectRatio: cardW / cellH,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => ProductCard(
                        product: results[i],
                        onTap: () => Navigator.of(context).push(
                          appRoute(
                            ProductDetailScreen(productId: results[i].id),
                          ),
                        ),
                      ),
                      childCount: results.length,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final n = store.cartCount;
    return Semantics(
      button: true,
      label: n == 0 ? 'Cart, empty' : 'Cart, $n items',
      child: ExcludeSemantics(
        child: PressScale(
          onTap: () => Navigator.of(context).push(appRoute(const CartScreen())),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox.square(
                dimension: T.tap,
                child: Center(
                  child: Ic.svg(
                    Ic.cart,
                    color: context.p.primaryFill,
                    size: 24,
                  ),
                ),
              ),
              if (n > 0)
                Positioned(
                  right: 2,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '$n',
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared add-to-cart behaviour: in stock adds, out of stock registers a
/// "Notify me" instead of hiding the product.
Future<void> addToCartWithFeedback(
  BuildContext context,
  Product product,
) async {
  final store = AppScope.read(context);
  if (product.inStock) {
    store.addToCart(product.id);
    successHaptic();
    if (!context.mounted) return;
    await _addedSheet(context, product);
    return;
  }
  store.notifyMe.add(product.id);
  if (!context.mounted) return;
  await showAppSheet(
    context,
    scrollable: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Ic.svg(Ic.bell, color: context.p.accent, size: 38, stroke: 1.8),
          const SizedBox(height: 12),
          Text(
            'We will let you know',
            style: Type.title2(context.p),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${product.name} is out of stock. We will notify you the moment a new batch arrives at the clinic.',
            style: Type.body(context.p)
                .copyWith(color: context.p.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: T.s20),
          PrimaryButton(label: 'Done', onPressed: () => dismissSheet(context)),
        ],
      ),
    ),
  );
}

Future<void> _addedSheet(BuildContext context, Product product) async {
  await showAppSheet(
    context,
    scrollable: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ProductArt(art: product.art, radius: 14, size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Added to cart', style: Type.headline(context.p)),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      style: Type.footnote(context.p),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: T.s24),
          PrimaryButton(
            label: 'View cart',
            icon: Ic.cart,
            onPressed: () {
              dismissSheet(context);
              Navigator.of(context).push(appRoute(const CartScreen()));
            },
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Keep shopping',
            onPressed: () => dismissSheet(context),
          ),
        ],
      ),
    ),
  );
}
