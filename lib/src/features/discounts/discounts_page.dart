import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/models.dart';
import '../../core/navigation_scope.dart';
import '../../state/cart_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/product_card.dart';
import '../../widgets/state_views.dart';

class DiscountsPage extends StatefulWidget {
  const DiscountsPage({super.key});

  @override
  State<DiscountsPage> createState() => _DiscountsPageState();
}

class _DiscountsPageState extends State<DiscountsPage> {
  final ApiService _api = ApiService.instance;

  bool _loading = true;
  String? _error;
  List<Product> _products = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchActiveDiscounts();
      if (!mounted) return;
      setState(() {
        _products = data.map((e) => e.producto).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar las promociones: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final cart = context.watch<CartController>();
    final showStock = user?.isAdmin ?? false;

    if (_loading) return const LoadingView(message: 'Revisando promociones...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _fetch);
    if (_products.isEmpty) {
      return const Center(child: Text('Aún no hay descuentos activos.'));
    }

    // === Misma lógica de grilla que HomePage ===
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final isLandscape = media.orientation == Orientation.landscape;
    final maxTileWidth = width <= 340 ? 320.0 : 220.0;
    final childAspectRatio = isLandscape ? 0.95 : 0.68;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetch,
        edgeOffset: 0,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Encabezado visual similar
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              sliver: SliverToBoxAdapter(child: _DiscountsHeader()),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxTileWidth,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: childAspectRatio,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final product = _products[index];
                  return ProductCard(
                    product: product,
                    showStock: showStock,
                    onPressed: () async {
                      await cart.add(product);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          margin: const EdgeInsets.all(16),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          content: Text(
                            '${product.nombre} agregado al carrito.',
                            style: const TextStyle(color: Colors.white),
                          ),
                          action: SnackBarAction(
                            label: 'Ver carrito',
                            textColor: Colors.white,
                            onPressed: () => ShellNavigationScope.of(
                              context,
                            )?.onNavigate('cart'),
                          ),
                        ),
                      );
                    },
                  );
                }, childCount: _products.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Promociones activas',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Aprovecha los descuentos de tiempo limitado.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withOpacity(0.9),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
