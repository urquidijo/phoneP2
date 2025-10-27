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
      if (!context.mounted) return;
      setState(() {
        _products = results[0] as List<Product>;
        _categories = results[1] as List<Category>;
        _loading = false;
      });
    } catch (error) {
      if (!context.mounted) return;
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

    final filteredProducts = _categoryFilter == null
        ? _products
        : _products.where((p) => p.categoria?.id == _categoryFilter).toList();
    final showStock = user?.isAdmin ?? false;

    return RefreshIndicator(
      onRefresh: _fetch,
      child: _loading
          ? const LoadingView(message: 'Cargando catálogo...')
          : _error != null
              ? ErrorView(message: _error!, onRetry: _fetch)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                    _HomeHeader(user: user),
                    const SizedBox(height: 24),
                    _CategoryFilter(
                      categories: _categories,
                      selected: _categoryFilter,
                      onChanged: (id) => setState(() => _categoryFilter = id),
                    ),
                    const SizedBox(height: 16),
                    if (filteredProducts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: Text(
                          'No hay productos para esta categoría todavía.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];
                          return ProductCard(
                            product: product,
                            showStock: showStock,
                            onPressed: () async {
                              await cart.add(product);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${product.nombre} agregado al carrito.'),
                                  action: SnackBarAction(
                                    label: 'Ver carrito',
                                    onPressed: () => ShellNavigationScope.of(context)
                                        ?.onNavigate('cart'),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({this.user});

  final User? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user == null ? 'Explora ElectroStore' : 'Hola, ${user!.username}',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            user == null
                ? 'Descubre ofertas inteligentes y compra en segundos.'
                : 'Gracias por volver. Tu panel se sincronizó automáticamente.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

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
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isActive = selected == category.id;
          return ChoiceChip(
            label: Text(category.nombre),
            selected: isActive,
            onSelected: (_) => onChanged(isActive ? null : category.id),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: categories.length,
      ),
    );
  }
}
