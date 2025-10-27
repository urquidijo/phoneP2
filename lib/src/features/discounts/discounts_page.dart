import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_service.dart';
import '../../core/models.dart';
import '../../state/cart_controller.dart';
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
      if (!context.mounted) return;
      setState(() {
        _products = data.map((item) => item.producto).toList();
        _loading = false;
      });
    } catch (error) {
      if (!context.mounted) return;
      setState(() {
        _error = 'No pudimos cargar las promociones: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    if (_loading) return const LoadingView(message: 'Revisando promociones...');
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _fetch);
    }
    if (_products.isEmpty) {
      return const Center(child: Text('Aún no hay descuentos activos.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: _products.length,
      itemBuilder: (_, index) {
        final product = _products[index];
        return ProductCard(
          product: product,
          onPressed: () async {
            await cart.add(product);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${product.nombre} agregado al carrito.')),
            );
          },
        );
      },
    );
  }
}
