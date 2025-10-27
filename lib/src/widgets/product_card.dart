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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount = product.activeDiscount?.estaActivo ?? false;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.nombre,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                  ),
                ),
                if (hasDiscount)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '-${product.activeDiscount!.porcentaje}%',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              product.descripcion?.isNotEmpty == true
                  ? product.descripcion!
                  : 'Sin descripcion',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
            const Spacer(),
            if (showStock)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Stock: ${product.stock}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDiscount)
                  Text(
                    currencyFormatter.format(product.precio),
                    style: theme.textTheme.bodySmall?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: theme.hintColor,
                    ),
                  ),
                Text(
                  currencyFormatter.format(product.effectivePrice),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('Comprar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
