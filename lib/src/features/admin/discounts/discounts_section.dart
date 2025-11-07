// lib/features/admin/discounts/discounts_section.dart
import 'package:flutter/material.dart';
import '../../../core/api_service.dart';
import '../../../core/models.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/state_views.dart';
import '../shared/section_scaffold.dart';
import '../shared/empty_state.dart';

class AdminDiscountsSection extends StatefulWidget {
  const AdminDiscountsSection({super.key});
  @override
  State<AdminDiscountsSection> createState() => _AdminDiscountsSectionState();
}

class _AdminDiscountsSectionState extends State<AdminDiscountsSection> {
  final ApiService _api = ApiService.instance;
  bool _loading = true;
  String? _feedback;
  List<Product> _products = const [];
  List<ProductDiscount> _discounts = const [];
  Product? _selectedProduct;
  double _percentage = 10;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _feedback = null;
    });
    try {
      final r = await Future.wait([
        _api.fetchProducts(),
        _api.fetchDiscounts(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = r[0] as List<Product>;
        _discounts = r[1] as List<ProductDiscount>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _feedback = 'No pudimos cargar los descuentos: $e';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (_selectedProduct == null) {
      setState(() => _feedback = 'Selecciona un producto.');
      return;
    }
    try {
      final payload = DiscountPayload(
        porcentaje: _percentage,
        fechaInicio: _startDate,
        fechaFin: _endDate,
        productoId: _selectedProduct!.id,
      );
      await _api.createDiscounts(payload);
      _load();
      setState(() => _feedback = 'Descuento guardado correctamente.');
    } catch (e) {
      setState(() => _feedback = 'No pudimos guardarlo: $e');
    }
  }

  Future<void> _delete(ProductDiscount d) async {
    await _api.deleteDiscount(d.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Cargando descuentos...');

    return SectionScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 420;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== Dropdown sin overflow =====
                  SizedBox(
                    width: double.infinity,
                    child: DropdownButtonFormField<Product>(
                      value: _selectedProduct,
                      isExpanded: true, // <- clave para evitar overflow
                      alignment: AlignmentDirectional.centerStart,
                      decoration: const InputDecoration(
                        labelText: 'Producto a promover',
                        border: OutlineInputBorder(),
                      ),
                      items: _products
                          .map(
                            (p) => DropdownMenuItem<Product>(
                              value: p,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                p.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      // Esto controla cómo se renderiza el ítem SELECCIONADO (cerrado)
                      selectedItemBuilder: (context) => _products
                          .map(
                            (p) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                p.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedProduct = v),
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (isNarrow) ...[
                    Text('Porcentaje: ${_percentage.toStringAsFixed(0)}%'),
                    Slider(
                      min: 5,
                      max: 80,
                      value: _percentage,
                      divisions: 15,
                      label: '${_percentage.toStringAsFixed(0)}%',
                      onChanged: (v) => setState(() => _percentage = v),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Porcentaje: ${_percentage.toStringAsFixed(0)}%',
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            min: 5,
                            max: 80,
                            value: _percentage,
                            divisions: 15,
                            label: '${_percentage.toStringAsFixed(0)}%',
                            onChanged: (v) => setState(() => _percentage = v),
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: isNarrow
                            ? double.infinity
                            : (constraints.maxWidth - 12) / 2,
                        child: OutlinedButton(
                          onPressed: () => _pickDate(true),
                          child: Text(
                            'Inicio: ${formatShortDate(_startDate.toIso8601String())}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: isNarrow
                            ? double.infinity
                            : (constraints.maxWidth - 12) / 2,
                        child: OutlinedButton(
                          onPressed: () => _pickDate(false),
                          child: Text(
                            _endDate == null
                                ? 'Sin fecha fin'
                                : 'Fin: ${formatShortDate(_endDate!.toIso8601String())}',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Align(
                    alignment: isNarrow
                        ? Alignment.center
                        : Alignment.centerRight,
                    child: SizedBox(
                      width: isNarrow ? double.infinity : null,
                      child: FilledButton(
                        onPressed: _save,
                        child: const Text('Guardar descuento'),
                      ),
                    ),
                  ),

                  if (_feedback != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _feedback!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 16),

                  if (_discounts.isEmpty)
                    const EmptyState(message: 'No hay descuentos activos.')
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _discounts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final d = _discounts[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            title: Text(
                              d.producto.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${d.porcentaje}% • ${formatDateTime(d.fechaInicio)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _delete(d),
                              tooltip: 'Eliminar',
                            ),
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
