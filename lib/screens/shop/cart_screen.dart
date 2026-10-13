import 'package:flutter/cupertino.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart' show QuantityStepper;

/// Cart: edit quantity, remove, order total.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final lines = store.cart;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: DetailNavBar(
        title: 'Cart',
        actions: [
          if (lines.isNotEmpty)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(48, 44),
              onPressed: () async {
                final ok = await confirmDestructive(
                  context,
                  title: 'Clear the cart?',
                  message: 'This removes all ${lines.length} items.',
                  confirmLabel: 'Clear cart',
                );
                if (ok) store.clearCart();
              },
              child: Text(
                'Clear',
                style: Type.body(p).copyWith(color: p.destructive),
              ),
            ),
        ],
      ),
      child: SafeArea(
        child: lines.isEmpty
            ? EmptyState(
                icon: Ic.cart,
                title: 'Your cart is empty',
                body: 'Add food, medicine or grooming supplies and collect them at the clinic counter.',
                actionLabel: 'Browse products',
                onAction: () {
                  dismissSheet(context);
                  AppScope.read(context).tab = 3;
                },
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount: lines.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _CartRow(line: lines[i]),
                    ),
                  ),
                  StickyCta(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Order total',
                                style: Type.headline(p),
                                maxLines: 2,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              peso(store.cartTotal),
                              style: Type.title1(p).copyWith(color: p.accentText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          label: 'Checkout · ${peso(store.cartTotal)}',
                          icon: Ic.arrowRight,
                          onPressed: () => Navigator.of(context).push(
                            appRoute(const CheckoutScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({required this.line});
  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final product = store.productOf(line.productId);

    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductArt(art: product.art, radius: 12, size: 62),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(product.name, style: Type.headline(p), maxLines: 2),
                    const SizedBox(height: 3),
                    Text(
                      '${peso(product.price)} each',
                      style: Type.footnote(p),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          peso(product.price * line.qty),
                          style: Type.headline(p).copyWith(color: p.accentText),
                        ),
                        const Spacer(),
                        Semantics(
                          button: true,
                          label: 'Remove ${product.name} from cart',
                          child: ExcludeSemantics(
                            child: PressScale(
                              onTap: () async {
                                final ok = await confirmDestructive(
                                  context,
                                  title: 'Remove ${product.name}?',
                                  message: 'This item will be taken out of your cart.',
                                  confirmLabel: 'Remove',
                                );
                                if (ok) store.removeFromCart(product.id);
                              },
                              child: SizedBox.square(
                                dimension: 44,
                                child: Center(
                                  child: Ic.svg(
                                    Ic.trash,
                                    color: p.destructive,
                                    size: 19,
                                    stroke: 1.9,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: p.divider),
          const SizedBox(height: 8),
          QuantityStepper(
            value: line.qty,
            max: product.inStock ? product.stock.clamp(line.qty, 20) : line.qty,
            onChanged: (v) => store.setQty(product.id, v),
          ),
        ],
      ),
    );
  }
}