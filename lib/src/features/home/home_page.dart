import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/models.dart';
import '../../core/navigation_scope.dart';
import '../../state/cart_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/product_card.dart';
import '../../widgets/state_views.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _api = ApiService.instance;

  bool _loading = true;
  String? _error;
  List<Product> _products = const [];
  List<Category> _categories = const [];
  int? _categoryFilter;

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
      final results = await Future.wait([
        _api.fetchProducts(),
        _api.fetchCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<Product>;
        _categories = results[1] as List<Category>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar el catálogo: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    final cart = context.watch<CartController>();
    final showStock = user?.isAdmin ?? false;

    final filteredProducts = _categoryFilter == null
        ? _products
        : _products.where((p) => p.categoria?.id == _categoryFilter).toList();

    if (_loading) {
      return const LoadingView(message: 'Cargando catálogo...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _fetch);
    }

    final media = MediaQuery.of(context);
    final width = media.size.width;
    // Para teléfonos normales apunta a 2 columnas; en pantallas angostas permite 1.
    // El maxCrossAxisExtent controla el ancho máximo de cada card de forma fluida.
    final maxTileWidth = width <= 340 ? 320.0 : 220.0;
    // Relación de aspecto: más alta en portrait, más ancha en landscape
    final isLandscape = media.orientation == Orientation.landscape;
    final childAspectRatio = isLandscape ? 0.95 : 0.68;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetch,
        edgeOffset: 0,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              sliver: SliverToBoxAdapter(child: _HomeHeader(user: user)),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: _CategoryFilter(
                  categories: _categories,
                  selected: _categoryFilter,
                  onChanged: (id) => setState(() => _categoryFilter = id),
                ),
              ),
            ),
            if (filteredProducts.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: _EmptyProducts(),
                ),
              )
            else
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
                    final product = filteredProducts[index];
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
                  }, childCount: filteredProducts.length),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ===================== HEADER ===================== */

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({this.user});

  final User? user;

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
            user == null ? 'Explora ElectroStore' : 'Hola, ${user!.username}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user == null
                ? 'Descubre ofertas inteligentes y compra en segundos.'
                : 'Gracias por volver. Tu panel se sincronizó automáticamente.',
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

/* ===================== CATEGORY FILTER ===================== */

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  final List<Category> categories;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isActive = selected == category.id;
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: ChoiceChip(
              label: Text(
                category.nombre,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              selected: isActive,
              pressElevation: 0,
              labelStyle: TextStyle(
                color: isActive
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onSelected: (_) => onChanged(isActive ? null : category.id),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: categories.length,
      ),
    );
  }
}

/* ===================== EMPTY STATE ===================== */

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          Icons.inventory_2_outlined,
          size: 48,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 10),
        Text(
          'No hay productos para esta categoría todavía.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
