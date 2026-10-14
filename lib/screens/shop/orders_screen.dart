import 'package:flutter/cupertino.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import 'order_success_screen.dart';

/// My Orders: pending payment / paid ready for pickup / picked up / cancelled,
/// with per-order receipt, pickup code and a pre-pickup refund path.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'My orders'),
      child: SafeArea(
        child: store.orders.isEmpty
            ? EmptyState(
                icon: Ic.bag,
                title: 'No orders yet',
                body: 'Anything you buy is collected at the clinic counter — we do not deliver.',
                actionLabel: 'Shop now',
                onAction: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  store.tab = 3;
                },
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                itemCount: store.orders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _OrderCard(order: store.orders[i]),
              ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final cancelled = order.status == OrderStatus.cancelled;
    final refundable =
        !cancelled &&
        !order.refunded &&
        (order.status == OrderStatus.paid ||
            order.status == OrderStatus.pendingPayment);

    return SoftCard(
      padding: EdgeInsets.zero,
      semanticLabel:
          'Order ${order.id}. ${order.status.label}. Total ${peso(order.total)}. '
          'Pickup code ${order.pickupCode}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Order ${order.id.replaceFirst('o', '#')}',
                        style: Type.headline(p),
                      ),
                    ),
                    Text(
                      peso(order.total),
                      style: Type.headline(p).copyWith(color: p.accentText),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${dayMonth(order.placedAt)} · ${order.method} · ${order.lines.length} items',
                  style: Type.footnote(p),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(
                      label: order.refunded ? 'Refunded' : order.status.label,
                      icon: order.refunded
                          ? Ic.refresh
                          : switch (order.status) {
                              OrderStatus.paid => Ic.checkCircle,
                              OrderStatus.pendingPayment => Ic.clock,
                              OrderStatus.pickedUp => Ic.gift,
                              OrderStatus.cancelled => Ic.close,
                            },
                      compact: true,
                      fg: order.refunded
                          ? p.warning
                          : switch (order.status) {
                              OrderStatus.paid => p.success,
                              OrderStatus.pendingPayment => p.warning,
                              OrderStatus.pickedUp => p.warning,
                              OrderStatus.cancelled => p.destructive,
                            },
                      bg: order.refunded
                          ? T.amber.withValues(alpha: 0.24)
                          : switch (order.status) {
                              OrderStatus.paid =>
                                p.isDark
                                    ? p.success.withValues(alpha: 0.12)
                                    : const Color(0xFFDDF2E3),
                              OrderStatus.pendingPayment => T.amber.withValues(
                                alpha: 0.28,
                              ),
                              OrderStatus.pickedUp => T.amber.withValues(
                                alpha: 0.24,
                              ),
                              OrderStatus.cancelled => const Color(0x1FDC2626),
                            },
                    ),
                    StatusChip(
                      label: 'Code ${order.pickupCode}',
                      icon: Ic.qr,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final l in order.lines.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        ProductArt(
                          art: store.productOf(l.productId).art,
                          radius: 8,
                          size: 30,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '${store.productOf(l.productId).name} × ${l.qty}',
                            style: Type.footnote(p),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(peso(l.total), style: Type.footnote(p)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: p.divider),
          Row(
            children: [
              Expanded(
                child: _Action(
                  label: 'Receipt',
                  icon: Ic.doc,
                  onTap: () => Navigator.of(context)
                      .push(appRoute(OrderSuccessScreen(orderId: order.id))),
                ),
              ),
              if (refundable) ...[
                Container(width: 1, height: 44, color: p.divider),
                Expanded(
                  child: _Action(
                    label: order.refunded ? 'Refunded' : 'Refund',
                    icon: Ic.refresh,
                    destructive: !order.refunded,
                    onTap: order.refunded ? null : () => _refund(context),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _refund(BuildContext context) async {
    final store = AppScope.read(context);
    final ok = await confirmDestructive(
      context,
      title: 'Cancel and refund?',
      message:
          'Order ${order.id.replaceFirst('o', '#')} is refunded and released. '
          'The pickup code stops working immediately.',
      confirmLabel: 'Refund order',
    );
    if (!ok || !context.mounted) return;
    store.updateOrder(
      order.id,
      (o) => o.copyWith(status: OrderStatus.cancelled, refunded: true),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

  final String label;
  final String icon;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final c = onTap == null
        ? p.textSecondary
        : destructive
        ? p.destructive
        : p.accentText;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: ExcludeSemantics(
        child: PressScale(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Ic.svg(icon, color: c, size: 16, stroke: 2.1),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    style: Type.footnoteEmph(p).copyWith(color: c),
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
