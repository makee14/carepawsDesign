import 'package:flutter/cupertino.dart';

import '../../app.dart';
import '../../data/models.dart';
import '../../design/icons.dart';
import '../../design/theme.dart';
import '../../design/tokens.dart';
import '../../state/app_store.dart';
import '../../widgets/common.dart';
import '../shops_screen.dart' show addToCartWithFeedback;
import 'checkout_screen.dart';

/// Product detail: description, stock count, quantity, add to cart.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final p = context.p;
    final product = store.productOf(widget.productId);
    final hasRx = store.hasPrescription(product.id);

    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: DetailNavBar(title: product.name),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  // Hero art with a floating glass metadata card.
                  SizedBox(
                    height: Layout.heroHeight(context, 220),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: ProductArt(
                            art: product.art,
                            radius: T.rCard,
                            size: 320,
                          ),
                        ),
                        if (product.restricted)
                          Positioned(
                            left: 12,
                            top: 12,
                            child: StatusChip(
                              label: hasRx ? 'Prescription on file' : 'Prescription required',
                              icon: Ic.shield,
                              fg: p.onPrimaryFill,
                              bg: hasRx ? p.success : p.primaryFill,
                            ),
                          ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: -30,
                          child: GlassCard(
                            padding: const EdgeInsets.all(T.s16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(product.name, style: Type.title2(p)),
                                const SizedBox(height: 4),
                                Text(product.tagline, style: Type.footnote(p)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    StatusChip(
                                      label: peso(product.price),
                                      icon: Ic.wallet,
                                      compact: true,
                                      fg: p.accentText,
                                      bg: p.accent.withValues(alpha: 0.12),
                                    ),
                                    StatusChip(
                                      label: product.inStock
                                          ? '${product.stock} in stock'
                                          : 'Out of stock',
                                      icon: product.inStock ? Ic.checkCircle : Ic.alert,
                                      compact: true,
                                      fg: product.inStock
                                          ? p.success
                                          : p.destructive,
                                      bg: product.inStock
                                          ? const Color(0xFFDDF2E3)
                                          : const Color(0x1FDC2626),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 44),
                  Text('About this product', style: Type.headline(p)),
                  const SizedBox(height: 8),
                  Text(product.description, style: Type.body(p)),
                  if (product.restricted) ...[
                    const SizedBox(height: T.s16),
                    SoftCard(
                      color: T.amber.withValues(alpha: 0.14),
                      borderColor: p.accent.withValues(alpha: 0.3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Ic.svg(Ic.shield, color: p.accentText, size: 18),
                              const SizedBox(width: 8),
                              Text('Restricted item', style: Type.headline(p)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hasRx
                                ? 'Your digital prescription from ${store.prescriptions.firstWhere((r) => r.productId == product.id).vetName} is active, so you can pay for this at checkout.'
                                : 'This item needs an active digital prescription signed by the veterinarian. Book a visit and the clinic can issue one.',
                            style: Type.body(p),
                          ),
                          const SizedBox(height: 10),
                          SecondaryButton(
                            label: hasRx ? 'View prescription' : 'Ask the clinic',
                            icon: hasRx ? Ic.doc : Ic.chat,
                            onPressed: () => _askClinic(context, product),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: T.s20),
                  Text('Gallery', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  GalleryRow(
                    count: product.gallery.isEmpty ? 4 : product.gallery.length,
                    onTap: () => _gallery(context, product),
                  ),
                  const SizedBox(height: T.s20),
                  Text('Quantity', style: Type.headline(p)),
                  const SizedBox(height: 10),
                  QuantityStepper(
                    value: _qty,
                    max: product.inStock ? product.stock.clamp(1, 20) : 0,
                    onChanged: (v) => setState(() => _qty = v),
                  ),
                  const SizedBox(height: T.s12),
                  Row(
                    children: [
                      Text('Subtotal', style: Type.headline(p)),
                      const Spacer(),
                      Text(
                        peso(product.price * _qty),
                        style: Type.title2(p).copyWith(color: p.accentText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            StickyCta(
              child: product.inStock
                  ? PrimaryButton(
                      label: 'Add to cart · ${peso(product.price * _qty)}',
                      icon: Ic.cart,
                      onPressed: () => addToCartWithFeedback(context, product),
                    )
                  : PrimaryButton(
                      label: store.notifyMe.contains(product.id)
                          ? 'You will be notified'
                          : 'Notify me when available',
                      icon: Ic.bell,
                      onPressed: () => addToCartWithFeedback(context, product),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _askClinic(BuildContext context, Product product) {
    final store = AppScope.read(context);
    store.pushMessage(
      ChatMessage(
        id: 'rx${store.now.microsecondsSinceEpoch}',
        threadId: 'th_clinic',
        author: ChatAuthor.vetAssistant,
        text: 'Asked about ${product.name} — is a prescription needed for ${store.pet(store.pets.first.id)?.name}?',
        at: store.now,
        sentByMe: true,
        petId: store.pets.first.id,
      ),
    );
    Navigator.of(context).push(
      appRoute(
        const _RxAskScreen(productName: ''),
      ),
    );
  }

  void _gallery(BuildContext context, Product product) {
    Navigator.of(context).push(appRoute(ProductGalleryScreen(product: product)));
  }
}

class _RxAskScreen extends StatelessWidget {
  const _RxAskScreen({required this.productName});
  final String productName;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Clinic team'),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(T.s24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Ic.svg(Ic.checkCircle, color: p.success, size: 44, stroke: 1.9),
              const SizedBox(height: T.s16),
              Text('Message sent', style: Type.title1(p), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Miguel will reply about the prescription during clinic hours. '
                'Your request is waiting in the Chats tab.',
                style: Type.body(p).copyWith(color: p.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: T.s24),
              PrimaryButton(
                label: 'Open Chats',
                icon: Ic.chat,
                onPressed: () {
                  Navigator.of(context).popUntil((r) => r.isFirst);
                  AppScope.read(context).tab = 1;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProductGalleryScreen extends StatelessWidget {
  const ProductGalleryScreen({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final arts = product.gallery.isEmpty ? [product.art] : product.gallery;
    return CupertinoPageScaffold(
      backgroundColor: p.background,
      navigationBar: const DetailNavBar(title: 'Gallery'),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(product.name, style: Type.title2(p)),
          const SizedBox(height: 6),
          Text('${arts.length} photos', style: Type.footnote(p)),
          const SizedBox(height: T.s16),
          for (final a in arts)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ProductArt(art: a, radius: T.rCard, size: 320),
            ),
        ],
      ),
    );
  }
}

/// Shared quantity stepper. Every swipe / long-press affordance also has an
/// explicit button alternative here.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 20,
    this.min = 1,
    this.label,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int max;
  final int min;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    final enabled = max >= min;
    return Row(
      children: [
        if (label != null) Expanded(child: Text(label!, style: Type.body(p))),
        Semantics(
          button: true,
          enabled: enabled && value > min,
          label: 'Decrease quantity',
          child: ExcludeSemantics(
            child: PressScale(
              onTap: enabled && value > min ? () => onChanged(value - 1) : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: value > min ? p.fieldBg : p.fieldBg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.divider),
                ),
                child: Center(
                  child: Ic.svg(
                    Ic.minus,
                    color: value > min ? p.primaryFill : p.textSecondary,
                    size: 18,
                    stroke: 2.3,
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 54,
          child: Text(
            '$value',
            style: Type.title2(p),
            textAlign: TextAlign.center,
            semanticsLabel: 'Quantity $value',
          ),
        ),
        Semantics(
          button: true,
          enabled: enabled && value < max,
          label: 'Increase quantity',
          child: ExcludeSemantics(
            child: PressScale(
              onTap: enabled && value < max ? () => onChanged(value + 1) : null,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: value < max ? p.fieldBg : p.fieldBg.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.divider),
                ),
                child: Center(
                  child: Ic.svg(
                    Ic.plus,
                    color: value < max ? p.primaryFill : p.textSecondary,
                    size: 18,
                    stroke: 2.3,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reached from Cart — thin wrapper so checkout can be pushed from several
/// places without duplicating the import graph.
class CheckoutRoute extends StatelessWidget {
  const CheckoutRoute({super.key});
  @override
  Widget build(BuildContext context) => const CheckoutScreen();
}