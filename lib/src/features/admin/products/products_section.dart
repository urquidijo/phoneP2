// lib/features/admin/products/products_section.dart
import 'package:flutter/material.dart';
import '../../../core/api_service.dart';
import '../../../core/models.dart';
import '../../../widgets/state_views.dart';
import '../shared/section_scaffold.dart';
import 'product_editor.dart';

class AdminProductsSection extends StatefulWidget {
  const AdminProductsSection({super.key});
  @override
  State<AdminProductsSection> createState() => _AdminProductsSectionState();
}

class _AdminProductsSectionState extends State<AdminProductsSection> {
  final ApiService _api = ApiService.instance;
  bool _loading = true;
  String? _error;
  List<Product> _products = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _api.fetchProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los productos: $e';
        _loading = false;
      });
    }
  }

  Future<void> _save(Product p, Map<String, dynamic> draft) async {
    try {
      final payload = ProductPayload(
        nombre: p.nombre,
        precio: draft['precio'] ?? p.precioRaw,
        stock: draft['stock'] ?? p.stock,
        descripcion: draft['descripcion'] ?? p.descripcion,
        lowStockThreshold: draft['low_stock_threshold'] ?? p.lowStockThreshold,
        categoriaId: p.categoria?.id,
        imagen: draft['imagen'] ?? p.imagen,
      );
      await _api.updateProduct(p.id, payload);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No pudimos guardar: $e')));
    }
  }

  Future<void> _delete(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar definitivamente ${p.nombre}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteProduct(p.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No pudimos eliminarlo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const LoadingView(message: 'Sincronizando inventario...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_products.isEmpty) {
      return const SectionScaffold(
        child: Text('No hay productos registrados.'),
      );
    }
    return SectionScaffold(
      child: Column(
        children: _products
            .map(
              (p) => ProductEditor(
                key: ValueKey(p.id),
                product: p,
                onSave: _save,
                onDelete: _delete,
              ),
            )
            .toList(),
      ),
    );
  }
}
