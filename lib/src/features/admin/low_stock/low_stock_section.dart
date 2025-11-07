// lib/features/admin/low_stock/low_stock_section.dart
import 'package:flutter/material.dart';
import '../../../core/api_service.dart';
import '../../../core/models.dart';
import '../../../widgets/state_views.dart';
import '../shared/section_scaffold.dart';
import '../shared/empty_state.dart';

class AdminLowStockSection extends StatefulWidget {
  const AdminLowStockSection({super.key});
  @override
  State<AdminLowStockSection> createState() => _AdminLowStockSectionState();
}

class _AdminLowStockSectionState extends State<AdminLowStockSection> {
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
      final products = await _api.fetchLowStockProducts();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar las alertas: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const LoadingView(message: 'Buscando productos críticos...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_products.isEmpty)
      return const EmptyState(
        message: 'No hay productos por debajo del umbral.',
      );

    return SectionScaffold(
      child: Column(
        children: _products.map((p) {
          final shortage = (p.lowStockThreshold - p.stock).clamp(0, 999);
          final isZero = p.stock == 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(p.nombre),
              subtitle: Text(
                'Stock ${p.stock} • Falta $shortage para el umbral',
              ),
              trailing: Text(
                isZero ? 'Sin stock' : 'Crítico',
                style: TextStyle(
                  color: isZero ? Colors.red : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
