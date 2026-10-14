import 'package:flutter/cupertino.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import 'orders_screen.dart';

/// Payment success → pickup code, QR, receipt.
class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, required this.orderId});
  final String orderId;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final order = store.orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => store.orders.first,
    );

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(
        title: 'Order confirmed',
        showBack: false,
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0x1FDDF2E3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Ic.svg(
                          Ic.checkCircle,
                          color: p.success,
                          size: 38,
                          stroke: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: T.s16),
                  Text(
                    'Paid',
                    style: Type.largeTitle(p),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Paid via ${order.method} · ready for pickup at the clinic',
                    style: Type.body(p).copyWith(color: p.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: T.s24),
                  _PickupCodeCard(order: order),
                  const SizedBox(height: T.s16),
                  Text('Receipt', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  SoftCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        for (final l in order.lines)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${store.productOf(l.productId).name} × ${l.qty}',
                                    style: Type.footnote(p),
                                  ),
                                ),
                                Text(
                                  peso(l.total),
                                  style: Type.footnoteEmph(p),
                                ),
                              ],
                            ),
                          ),
                        Divider(height: 1, color: p.divider),
                        AmountRow(
                          label: 'Total paid',
                          value: peso(order.total),
                          emphasis: true,
                        ),
                        AmountRow(label: 'Order', value: order.id),
                        AmountRow(label: 'Status', value: order.status.label),
                      ],
                    ),
                  ),
                  const SizedBox(height: T.s16),
                  SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Ic.svg(Ic.pin, color: p.accent, size: 18),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Collect at',
                                style: Type.headline(p),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('CarePaws Veterinary Clinic', style: Type.body(p)),
                        const SizedBox(height: 4),
                        Text(
                          'Unit 12, Greenhills Shopping Centre, Shaw Blvd, Mandaluyong City',
                          style: Type.footnote(p),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Show the pickup code at the counter. We hold orders for 7 days.',
                          style: Type.footnote(p)
                              .copyWith(color: p.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            StickyCta(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: 'View my orders',
                    icon: Ic.doc,
                    onPressed: () =>
                        Navigator.of(context)
                            .pushReplacement(appRoute(const OrdersScreen())),
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    label: 'Done',
                    onPressed: () => doneToTab(context, 3),
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

class _PickupCodeCard extends StatelessWidget {
  const _PickupCodeCard({required this.order});
  final Order order;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return SoftCard(
      padding: const EdgeInsets.all(T.s20),
      child: Column(
        children: [
          Row(
            children: [
              Ic.svg(Ic.qr, color: p.accent, size: 22, stroke: 1.9),
              const SizedBox(width: 10),
              Expanded(child: Text('Pickup code', style: Type.headline(p))),
            ],
          ),
          const SizedBox(height: T.s16),
          // Deterministic code grid — a scannable-looking matrix built from the
          // pickup code so it always renders identically in tests.
          _CodeMatrix(code: order.pickupCode, color: p.text),
          const SizedBox(height: T.s16),
          Text(
            order.pickupCode,
            style: Type.largeTitle(p)
                .copyWith(letterSpacing: 3, color: p.accentText),
          ),
          const SizedBox(height: 6),
          Text('Show this at the clinic counter', style: Type.footnote(p)),
        ],
      ),
    );
  }
}

class _CodeMatrix extends StatelessWidget {
  const _CodeMatrix({required this.code, required this.color});
  final String code;
  final Color color;

  static const _finder = [
    [0, 0],
    [0, 1],
    [0, 2],
    [1, 0],
    [1, 1],
    [1, 2],
    [2, 0],
    [2, 1],
    [2, 2],
    [0, 6],
    [0, 7],
    [0, 8],
    [1, 6],
    [1, 7],
    [1, 8],
    [2, 6],
    [2, 7],
    [2, 8],
    [6, 0],
    [6, 1],
    [6, 2],
    [7, 0],
    [7, 1],
    [7, 2],
    [8, 0],
    [8, 1],
    [8, 2],
  ];

  @override
  Widget build(BuildContext context) {
    var seed = code.codeUnits.fold<int>(7, (a, b) => a * 31 + b);
    bool filled(int x, int y) {
      if (_finder.any((f) => f[0] == x && f[1] == y)) return true;
      if (x >= 3 && x <= 5 && y >= 3 && y <= 5) {
        return false; // centre quiet zone
      }
      seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
      return (seed >> 7) % 3 != 0;
    }

    return Semantics(
      image: true,
      label: 'Pickup code QR. Code ${code.replaceFirst('PC-', '')}',
      child: Container(
        width: 168,
        height: 168,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.p.divider),
        ),
        child: CustomPaint(painter: _MatrixPainter(filled, color)),
      ),
    );
  }
}

class _MatrixPainter extends CustomPainter {
  _MatrixPainter(this.filled, this.color);
  final bool Function(int, int) filled;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 9;
    final cell = size.width / n;
    final paint = Paint()..color = color;
    for (var x = 0; x < n; x++) {
      for (var y = 0; y < n; y++) {
        if (filled(x, y)) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell - 0.6, cell - 0.6),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MatrixPainter old) =>
      old.filled != filled || old.color != color;
}
