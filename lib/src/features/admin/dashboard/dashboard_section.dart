// lib/features/admin/dashboard/dashboard_section.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/api_service.dart';
import '../../../core/models.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/state_views.dart';
import '../shared/section_header.dart';
import '../shared/section_scaffold.dart';
import '../shared/kpi_pill.dart';

class AdminDashboardSection extends StatefulWidget {
  const AdminDashboardSection({super.key});

  @override
  State<AdminDashboardSection> createState() => _AdminDashboardSectionState();
}

class _AdminDashboardSectionState extends State<AdminDashboardSection> {
  final ApiService _api = ApiService.instance;
  bool _loading = true;
  String? _error;
  List<User> _users = const [];
  List<Product> _products = const [];
  List<Invoice> _invoices = const [];
  SalesHistoryResponse? _history;
  SalesPredictionsResponse? _predictions;

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
        _api.fetchUsers(),
        _api.fetchProducts(),
        _api.fetchAllInvoices(),
        _api.fetchSalesHistory(),
        _api.fetchSalesPredictions(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<User>;
        _products = results[1] as List<Product>;
        _invoices = results[2] as List<Invoice>;
        _history = results[3] as SalesHistoryResponse;
        _predictions = results[4] as SalesPredictionsResponse;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar el dashboard: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Actualizando métricas...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _fetch);

    final totalStock = _products.fold<int>(0, (sum, p) => sum + p.stock);
    final totalRevenue = _invoices.fold<double>(
      0,
      (sum, i) => sum + i.amountTotal,
    );
    final historic = _history?.monthlyTotals ?? [];
    final predictions = _predictions?.predictions ?? [];

    return SectionScaffold(
      onRefresh: _fetch,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Resumen'),
          const SizedBox(height: 12),
          // KPIs compactos (píldoras)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              KpiPill(
                icon: Icons.people,
                value: '${_users.length}',
                label: 'Usuarios',
                helper: 'Registrados',
              ),
              KpiPill(
                icon: Icons.widgets,
                value: '${_products.length}',
                label: 'Productos',
                helper: 'En catálogo',
              ),
              KpiPill(
                icon: Icons.inventory_2,
                value: '$totalStock',
                label: 'Inventario',
                helper: 'Unidades',
              ),
              KpiPill(
                icon: Icons.receipt_long,
                value: currencyFormatter.format(totalRevenue),
                label: 'Facturación',
                helper: '${_invoices.length} facturas',
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Card de gráfico con leyenda minimal
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Histórico vs predicción',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _LegendDot(
                        color: Theme.of(context).colorScheme.primary,
                        label: 'Histórico',
                      ),
                      const SizedBox(width: 12),
                      _LegendDot(
                        color: Theme.of(context).colorScheme.secondary,
                        label: 'Predicción',
                        dashed: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < historic.length; i++)
                                FlSpot(i.toDouble(), historic[i].total),
                            ],
                            color: Theme.of(context).colorScheme.primary,
                            barWidth: 3,
                            isCurved: true,
                            dotData: const FlDotData(show: false),
                          ),
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < predictions.length; i++)
                                FlSpot(
                                  (historic.length + i).toDouble(),
                                  predictions[i].total,
                                ),
                            ],
                            color: Theme.of(context).colorScheme.secondary,
                            barWidth: 3,
                            isCurved: true,
                            dashArray: const [6, 4],
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Leyenda compacta para series del gráfico
class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: dashed ? color.withOpacity(0.0) : color,
            borderRadius: BorderRadius.circular(2),
            border: dashed ? Border.all(color: color, width: 2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
