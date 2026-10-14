import 'package:flutter/cupertino.dart';

import '../app.dart';
import '../data/models.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/nav_actions.dart';
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
      final matchesSpecies = _species == null || prod.species.contains(_species!);
      return matchesQuery && matchesNeed && matchesSpecies;
    }).toList();

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      child: CustomScrollView(
        slivers: [
          const LargeTitleBar(title: 'Shop'),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
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
                          placeholderStyle: Type.body(p).copyWith(color: p.textSecondary),
                          onChanged: (v) => setState(() => _query = v),
                          backgroundColor: p.surface,
                          itemColor: p.textSecondary,
                          borderRadius: BorderRadius.circular(T.rControl),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      NavActions(
                        actions: [
                          IconTap(
                            path: Ic.doc,
                            label: 'My orders',
                            color: p.primaryFill,
                            onPressed: () => Navigator.of(context).push(
                              appRoute(const OrdersScreen()),
                            ),
                          ),
                          _CartBadge(),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 38,
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
                          onTap: () => setState(() =>
                              _species = _species == Species.dog ? null : Species.dog),
                        ),
                        const SizedBox(width: 8),
                        FilterPill(
                          label: 'For cats',
                          icon: Ic.cat,
                          selected: _species == Species.cat,
                          onTap: () => setState(() =>
                              _species = _species == Species.cat ? null : Species.cat),
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
                  body: 'Nothing matches “$_query” in this category. Browse everything instead.',
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
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 40 + TabBarClearance.of(context)),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 620 ? 3 : 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => ProductCard(product: results[i]),
                  childCount: results.length,
                ),
              ),
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
                  child: Ic.svg(Ic.cart, color: context.p.primaryFill, size: 24),
                ),
              ),
              if (n > 0)
                Positioned(
                  right: 2,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final inCart = store.qtyOf(product.id);

    // The card is a link to the detail screen; the "Add" control is a separate
    // sibling button so VoiceOver still reaches it (no nested exclusion).
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label:
                  '${product.name}. ${product.tagline}. ${peso(product.price)}. '
                  '${product.inStock ? '${product.stock} in stock' : 'Out of stock'}',
              child: ExcludeSemantics(
                child: PressScale(
                  scale: 0.98,
                  onTap: () => Navigator.of(context).push(
                    appRoute(ProductDetailScreen(productId: product.id)),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ProductArt(art: product.art, radius: 14),
                      ),
                      if (product.restricted)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: StatusChip(
                            label: 'Rx',
                            icon: Ic.shield,
                            compact: true,
                            fg: p.onPrimaryFill,
                            bg: p.primaryFill,
                          ),
                        ),
                      if (!product.inStock)
                        Positioned(
                          left: 6,
                          bottom: 6,
                          child: StatusChip(
                            label: 'Out of stock',
                            compact: true,
                            fg: p.onPrimaryFill,
                            bg: p.destructive,
                          ),
                        ),
                      if (inCart > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: StatusChip(
                            label: '$inCart in cart',
                            compact: true,
                            fg: T.espresso,
                            bg: T.cream.withValues(alpha: 0.92),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              product.name,
              style: Type.headline(p),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            product.tagline,
            style: Type.footnote(p).copyWith(color: p.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  peso(product.price),
                  style: Type.headline(p).copyWith(color: p.accentText),
                  // One line, always: at large Dynamic Type the price must
                  // ellipsize instead of wrapping and pushing the card taller.
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _MiniAdd(product: product),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniAdd extends StatelessWidget {
  const _MiniAdd({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      enabled: product.inStock,
      label: product.inStock
          ? 'Add ${product.name} to cart'
          : '${product.name} is out of stock. Tap to notify me when it returns',
      child: ExcludeSemantics(
        child: PressScale(
          onTap: () => addToCartWithFeedback(context, product),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: product.inStock ? p.primaryFill : p.fieldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Ic.svg(
                product.inStock ? Ic.plus : Ic.bell,
                color: product.inStock ? p.onPrimaryFill : p.textSecondary,
                size: 20,
                stroke: 2.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared add-to-cart behaviour: in stock adds, out of stock registers a
/// "Notify me" instead of hiding the product.
Future<void> addToCartWithFeedback(BuildContext context, Product product) async {
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
          Text('We will let you know', style: Type.title2(context.p), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            '${product.name} is out of stock. We will notify you the moment a new batch arrives at the clinic.',
            style: Type.body(context.p).copyWith(color: context.p.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: T.s20),
          PrimaryButton(
            label: 'Done',
            onPressed: () => dismissSheet(context),
          ),
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
