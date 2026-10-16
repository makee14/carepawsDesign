import 'package:flutter/cupertino.dart';

import '../data/models.dart';
import '../design/icons.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import 'common.dart';

/// Data-driven product card (Stream A owns it; Stream D consumes it in the
/// shop grid and product detail — never forked).
///
/// Every visual difference comes from [Product] data: [Product.art] image,
/// [Product.name], [Product.tagline], [Product.price], stock badge
/// ([Product.inStock]) and the [Product.restricted] "Rx" badge. No
/// per-product layout variants.
///
/// Anatomy: 4:3 image clipped to the card's top radius, s12 padding, name
/// (14pt semibold, 2 lines), tagline (12pt secondary, 1 line), price row
/// (16pt semibold + badge right). Whole card is one tap target → [onTap].
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.p;

    final card = Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(T.rCard),
        // Same elevation language as SoftCard: shadow in light, flat in dark.
        boxShadow: p.isDark
            ? null
            : const [
                BoxShadow(
                  color: T.shadowLight,
                  blurRadius: T.shadowBlur,
                  offset: Offset(0, T.shadowDy),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(T.rCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: ProductArt(art: product.art, radius: 0),
            ),
            Padding(
              padding: const EdgeInsets.all(T.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.tagline,
                    style: Type.footnote(p)
                        .copyWith(fontSize: 12, color: p.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: T.s8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          peso(product.price),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: p.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!product.inStock)
                        const _CardBadge(
                          label: 'Out of stock',
                          background: null, // taupe 20%
                          foreground: null, // taupe
                        )
                      else if (product.restricted)
                        Flexible(
                          child: _CardBadge(
                            label: 'Rx',
                            background: T.amber,
                            foreground: T.text,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      button: onTap != null,
      label:
          '${product.name}. ${product.tagline}. ${peso(product.price)}. '
          '${product.inStock ? '${product.stock} in stock' : 'Out of stock'}'
          '${product.restricted ? '. Prescription required' : ''}',
      child: ExcludeSemantics(
        child: PressScale(scale: 0.98, onTap: onTap, child: card),
      ),
    );
  }
}

/// 11pt pill badge. `null` colors select the taupe out-of-stock treatment.
class _CardBadge extends StatelessWidget {
  const _CardBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final p = context.p;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? p.textSecondary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(T.rPill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground ?? p.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
