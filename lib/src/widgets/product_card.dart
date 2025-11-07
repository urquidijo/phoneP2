import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../utils/formatters.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onPressed,
    this.showStock = false,
  });

  final Product product;
  final VoidCallback onPressed;
  final bool showStock;

  bool get _hasDiscount => (product.activeDiscount?.estaActivo ?? false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = product.imagen;
    final hasDiscount = _hasDiscount;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==== Imagen protagonista ====
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _NetworkImageNice(url: imageUrl),

                    // Gradiente inferior suave
                    const Align(
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ),

                    // === Fila superior de badges (evita que se "choquen") ===
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (hasDiscount)
                            _Badge(
                              label: "-${product.activeDiscount!.porcentaje}%",
                              color: theme.colorScheme.secondary,
                              compact: true, // más pequeño
                            )
                          else
                            const SizedBox.shrink(),
                          if (showStock)
                            _Badge(
                              label: "Stock: ${product.stock ?? 0}",
                              color: (product.stock ?? 0) <= 3
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                              compact: true, // más pequeño
                            ),
                        ],
                      ),
                    ),

                    // === Franja de precio ===
                    Positioned(
                      bottom: 8,
                      left: 10,
                      child: _PriceStripe(
                        hasDiscount: hasDiscount,
                        original: product.precio,
                        effective: product.effectivePrice,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ==== Info producto ====
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título un pelín más compacto
                    Text(
                      product.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5, // antes 15
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (product.descripcion?.isNotEmpty ?? false)
                          ? product.descripcion!
                          : 'Sin descripción',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                        height: 1.22,
                        fontSize: 12.5,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 34, // 35 -> 34 para dar aire
                      child: FilledButton.icon(
                        onPressed: onPressed,
                        icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                        label: const Text('Agregar'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================= SUBWIDGETS ================= */

class _NetworkImageNice extends StatelessWidget {
  const _NetworkImageNice({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (url == null || url!.isEmpty) {
      return _ImageFallback(theme: theme);
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: theme.colorScheme.surfaceVariant.withOpacity(.5),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _ImageFallback(theme: theme),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.theme});
  final ThemeData theme;
  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: theme.colorScheme.onSurfaceVariant,
        size: 28,
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padH = compact ? 8.0 : 10.0;
    final padV = compact ? 4.0 : 5.0;
    final fontSize = compact ? 11.0 : 12.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
        ),
      ),
    );
  }
}

class _PriceStripe extends StatelessWidget {
  const _PriceStripe({
    required this.hasDiscount,
    required this.original,
    required this.effective,
  });

  final bool hasDiscount;
  final double original;
  final double effective;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ), // antes 10 / 6
          color: Colors.black38,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasDiscount)
                Text(
                  currencyFormatter.format(original),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11, // antes 12
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              if (hasDiscount) const SizedBox(width: 6),
              Text(
                currencyFormatter.format(effective),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13, // antes 14
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
