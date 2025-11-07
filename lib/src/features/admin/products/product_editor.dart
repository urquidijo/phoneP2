// lib/features/admin/products/product_editor.dart
import 'package:flutter/material.dart';
import '../../../core/models.dart';
import '../../../utils/formatters.dart';

class ProductEditor extends StatefulWidget {
  const ProductEditor({
    super.key,
    required this.product,
    required this.onSave,
    required this.onDelete,
  });

  final Product product;
  final Future<void> Function(Product, Map<String, dynamic>) onSave;
  final Future<void> Function(Product) onDelete;

  @override
  State<ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<ProductEditor> {
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _thresholdCtrl;
  late final TextEditingController _descriptionCtrl;
  final Map<String, dynamic> _draft = {};

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.product.precioRaw);
    _stockCtrl = TextEditingController(text: widget.product.stock.toString());
    _thresholdCtrl = TextEditingController(
      text: widget.product.lowStockThreshold.toString(),
    );
    _descriptionCtrl = TextEditingController(
      text: widget.product.descripcion ?? '',
    );
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          'Stock ${p.stock} · ${currencyFormatter.format(p.precio)}',
        ),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: (p.imagen?.isNotEmpty ?? false)
              ? Image.network(
                  p.imagen!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 44,
                  height: 44,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  child: const Icon(Icons.image_not_supported_outlined),
                ),
        ),
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Precio USD',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _draft['precio'] = v,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _stockCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Stock',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      _draft['stock'] = int.tryParse(v) ?? p.stock,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _thresholdCtrl,
            decoration: const InputDecoration(
              labelText: 'Umbral bajo',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (v) => _draft['low_stock_threshold'] =
                int.tryParse(v) ?? p.lowStockThreshold,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionCtrl,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (v) => _draft['descripcion'] = v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onDelete(p),
                  child: const Text('Eliminar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => widget.onSave(p, _draft),
                  child: const Text('Guardar cambios'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
