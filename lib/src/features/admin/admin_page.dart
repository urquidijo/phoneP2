// lib/features/admin/admin_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../state/session_controller.dart';

import 'dashboard/dashboard_section.dart';
import 'invoices/invoices_section.dart';
import 'reports/reports_section.dart';
import 'forecast/forecast_section.dart';
import 'discounts/discounts_section.dart';
import 'low_stock/low_stock_section.dart';
import 'users/users_section.dart';
import 'products/products_section.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with TickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    // añadí Users y Products como secciones dedicadas
    _tab = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    if (!(user?.isAdmin ?? false)) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64),
            const SizedBox(height: 12),
            const Text('Solo administradores pueden ver este panel.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pushNamed('/auth'),
              child: const Text('Iniciar sesión como admin'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelPadding: const EdgeInsets.symmetric(horizontal: 16),
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Dashboard'),
              Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Facturas'),
              Tab(icon: Icon(Icons.analytics_outlined), text: 'Reportes'),
              Tab(icon: Icon(Icons.auto_graph_outlined), text: 'Predicción'),
              Tab(icon: Icon(Icons.local_offer_outlined), text: 'Descuentos'),
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'Stock bajo'),
              Tab(icon: Icon(Icons.people_alt_outlined), text: 'Usuarios'),
              Tab(icon: Icon(Icons.widgets_outlined), text: 'Productos'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              AdminDashboardSection(),
              AdminInvoicesSection(),
              AdminReportsSection(),
              AdminForecastSection(),
              AdminDiscountsSection(),
              AdminLowStockSection(),
              AdminUsersSection(),
              AdminProductsSection(),
            ],
          ),
        ),
      ],
    );
  }
}
