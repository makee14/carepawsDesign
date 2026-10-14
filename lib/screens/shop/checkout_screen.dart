import 'package:flutter/cupertino.dart';

import 'dart:math' as math;

import '../../app.dart';
import '../../data/models.dart';
import '../../data/seed.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import 'order_success_screen.dart';

enum PayMethod { gcash, card }

/// Checkout — one screen, one "Pay". Pickup only.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  PayMethod _method = PayMethod.gcash;
  bool _paying = false;

  /// Set only when a payment attempt genuinely fails. The cart stays intact
  /// and the inline error offers a retry — no canned failure for demo.
  bool _paymentFailed = false;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final lines = store.cart;
    final blocked = store.blockedRestricted;
    final total = store.cartTotal;

    if (lines.isEmpty) {
      return CupertinoPageScaffold(
        backgroundColor: p.background,
        navigationBar: const DetailNavBar(title: 'Checkout'),
        child: EmptyState(
          icon: Ic.cart,
          title: 'Nothing to pay for',
          body: 'Add at least one item to continue to checkout.',
          actionLabel: 'Back to cart',
          onAction: () => dismissSheet(context),
        ),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Checkout'),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  Text('Order summary', style: Type.title2(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        for (final l in lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                ProductArt(
                                  art: store.productOf(l.productId).art,
                                  radius: 10,
                                  size: 40,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        store.productOf(l.productId).name,
                                        style: Type.footnoteEmph(p),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Qty ${l.qty}',
                                        style: Type.caption(p),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  peso(
                                    store.productOf(l.productId).price * l.qty,
                                  ),
                                  style: Type.footnoteEmph(p),
                                ),
                              ],
                            ),
                          ),
                        Divider(height: 1, color: p.divider),
                        const SizedBox(height: 4),
                        AmountRow(label: 'Subtotal', value: peso(total)),
                        AmountRow(
                          label: 'Pickup',
                          value: 'Free',
                          note: 'Collect at the clinic counter',
                        ),
                        AmountRow(
                          label: 'Total',
                          value: peso(total),
                          bold: true,
                          emphasis: true,
                        ),
                      ],
                    ),
                  ),
                  if (blocked.isNotEmpty) ...[
                    const SizedBox(height: T.s16),
                    _PrescriptionBlock(ids: blocked, store: store),
                  ],
                  const SizedBox(height: T.s20),
                  Text('Payment method', style: Type.title2(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _MethodRow(
                          label: 'GCash',
                          sub: 'GCash · •••• 4412',
                          icon: Ic.wallet,
                          selected: _method == PayMethod.gcash,
                          onTap: () =>
                              setState(() => _method = PayMethod.gcash),
                        ),
                        Divider(height: 1, color: p.divider, indent: 56),
                        _MethodRow(
                          label: 'Credit / debit card',
                          sub: 'Visa · •••• 9082',
                          icon: Ic.card2,
                          selected: _method == PayMethod.card,
                          onTap: () => setState(() => _method = PayMethod.card),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s20),
                  Text('Pickup', style: Type.title2(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Ic.svg(Ic.pin, color: p.accent, size: 20),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                Seed.clinicName,
                                style: Type.headline(p),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(Seed.clinicAddress, style: Type.footnote(p)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Ic.svg(Ic.clock, color: p.textSecondary, size: 14),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                Seed.clinicHours,
                                style: Type.caption(p),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: T.amber.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Ic.svg(Ic.truck, color: p.accentText, size: 16),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'No delivery — pickup at the clinic. We hold orders for 7 days.',
                                  style: Type.footnote(p)
                                      .copyWith(color: p.warning),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_paymentFailed) ...[
                    const SizedBox(height: T.s16),
                    _PaymentError(onRetry: _pay),
                  ],
                ],
              ),
            ),
            StickyCta(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: 'Pay ${peso(total)}',
                    icon: _method == PayMethod.gcash ? Ic.wallet : Ic.card2,
                    busy: _paying,
                    onPressed: blocked.isNotEmpty ? null : _pay,
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Cancel',
                    onPressed: _paying
                        ? null
                        : () async {
                            // Cancel discards the checkout attempt; the cart stays intact.
                            dismissSheet(context);
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pay() async {
    if (_paying) return;
    final store = AppScope.read(context);
    setState(() {
      _paying = true;
      _paymentFailed = false;
    });
    Order? order;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));

      final lines = [
        for (final c in store.cart)
          OrderLine(c.productId, c.qty, store.productOf(c.productId).price),
      ];
      order = Order(
        id: 'o${store.now.microsecondsSinceEpoch}',
        placedAt: store.now,
        lines: lines,
        status: OrderStatus.paid,
        pickupCode: _code(store.now.microsecondsSinceEpoch),
        method: _method == PayMethod.gcash ? 'GCash' : 'Card',
      );
      store.addOrder(order);
      store.clearCart();
      successHaptic();
    } catch (_) {
      // A real payment failure lands here: the cart stays fully intact and
      // the inline error offers a retry.
      if (!mounted) return;
      setState(() {
        _paying = false;
        _paymentFailed = true;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _paying = false);
    Navigator.of(context)
        .pushReplacement(appRoute(OrderSuccessScreen(orderId: order.id)));
  }

  static String _code(int seed) {
    final rng = math.Random(seed);
    return 'PC-${1000 + rng.nextInt(8999)}';
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.label,
    required this.sub,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final String icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, ${selected ? 'selected' : 'not selected'}',
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          scale: 0.99,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Ic.svg(
                      icon,
                      color: p.primaryFill,
                      size: 18,
                      stroke: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: Type.body(p)),
                      const SizedBox(height: 2),
                      Text(sub, style: Type.footnote(p)),
                    ],
                  ),
                ),
                SelectDot(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PrescriptionBlock extends StatelessWidget {
  const _PrescriptionBlock({required this.ids, required this.store});
  final List<String> ids;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SoftCard(
      color: p.destructive.withValues(alpha: 0.07),
      borderColor: p.destructive.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Ic.svg(Ic.shield, color: p.destructive, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Prescription required',
                  style: Type.headline(p).copyWith(color: p.destructive),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'These items need an active digital prescription signed by the veterinarian:\n'
            '${ids.map((i) => '· ${store.productOf(i).name}').join('\n')}',
            style: Type.body(p),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Remove items',
                  icon: Ic.trash,
                  destructive: true,
                  onPressed: () {
                    for (final id in ids) {
                      store.removeFromCart(id);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: 'Ask clinic',
                  icon: Ic.chat,
                  onPressed: () {
                    store.tab = 1;
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentError extends StatelessWidget {
  const _PaymentError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SoftCard(
      color: p.destructive.withValues(alpha: 0.07),
      borderColor: p.destructive.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Ic.svg(Ic.alert, color: p.destructive, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Payment did not go through',
                  style: Type.headline(p).copyWith(color: p.destructive),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Your cart is unchanged — nothing was charged. This is usually a brief network issue.',
            style: Type.body(p),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Retry payment',
            icon: Ic.refresh,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
