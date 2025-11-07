// lib/features/admin/forecast/forecast_section.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/api_service.dart';
import '../../../core/models.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/state_views.dart';
import '../shared/section_scaffold.dart';
import '../shared/section_header.dart';

class AdminForecastSection extends StatefulWidget {
  const AdminForecastSection({super.key});
  @override
  State<AdminForecastSection> createState() => _AdminForecastSectionState();
}

class _AdminForecastSectionState extends State<AdminForecastSection> {
  final ApiService _api = ApiService.instance;
  bool _loading = true;
  String? _error;
  SalesHistoryResponse? _history;
  SalesPredictionsResponse? _predictions;

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
      final r = await Future.wait([
        _api.fetchSalesHistory(),
        _api.fetchSalesPredictions(),
      ]);
      if (!mounted) return;
      setState(() {
        _history = r[0] as SalesHistoryResponse;
        _predictions = r[1] as SalesPredictionsResponse;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar las predicciones: $e';
        _loading = false;
      });
    }
  }

  Future<void> _retrain() async {
    await _api.retrainSalesModel();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Modelo reentrenado.')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingView(message: 'Generando proyecciones...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    final historic = _history?.monthlyTotals ?? [];
    final predicted = _predictions?.predictions ?? [];

    return SectionScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 360;

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header sin trailing para evitar overflow
                  const SectionHeader(title: 'Predicción de ventas'),

                  const SizedBox(height: 16),

                  // Gráfico
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        barGroups: [
                          for (var i = 0; i < historic.length; i++)
                            BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: historic[i].total,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                            ),
                        ],
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(show: false),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Botón reentrenar reubicado (debajo del gráfico)
                  if (isNarrow)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _retrain,
                        icon: const Icon(Icons.auto_graph),
                        label: const Text('Reentrenar modelo'),
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _retrain,
                        icon: const Icon(Icons.auto_graph),
                        label: const Text('Reentrenar modelo'),
                      ),
                    ),

                  const SizedBox(height: 16),

                  Text(
                    'Siguiente periodo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),

                  ...predicted.map(
                    (p) => ListTile(
                      title: Text(
                        p.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        currencyFormatter.format(p.total),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      minVerticalPadding: 8,
                    ),
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
