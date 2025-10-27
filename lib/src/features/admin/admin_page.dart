import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/api_service.dart';
import '../../core/models.dart';
import '../../state/session_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/state_views.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Dashboard'),
            Tab(text: 'Facturas'),
            Tab(text: 'Reportes'),
            Tab(text: 'Predicción'),
            Tab(text: 'Descuentos'),
            Tab(text: 'Stock bajo'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              AdminDashboardSection(),
              AdminInvoicesSection(),
              AdminReportsSection(),
              AdminForecastSection(),
              AdminDiscountsSection(),
              AdminLowStockSection(),
            ],
          ),
        ),
      ],
    );
  }
}

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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar el dashboard: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Actualizando métricas...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _fetch);

    final totalStock = _products.fold<int>(0, (sum, product) => sum + product.stock);
    final totalRevenue =
        _invoices.fold<double>(0, (sum, invoice) => sum + invoice.amountTotal);

    final historic = _history?.monthlyTotals ?? [];
    final predictions = _predictions?.predictions ?? [];

    return RefreshIndicator(
      onRefresh: _fetch,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(
                title: 'Usuarios',
                helper: 'Registrados',
                icon: Icons.people,
                value: '${_users.length}',
              ),
              _MetricCard(
                title: 'Productos',
                helper: 'En catálogo',
                icon: Icons.devices_other,
                value: '${_products.length}',
              ),
              _MetricCard(
                title: 'Inventario',
                helper: 'Unidades disponibles',
                icon: Icons.inventory_2,
                value: '$totalStock',
              ),
              _MetricCard(
                title: 'Facturación',
                helper: '${_invoices.length} facturas',
                icon: Icons.receipt_long,
                value: currencyFormatter.format(totalRevenue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Histórico vs predicción',
                    style: Theme.of(context).textTheme.titleMedium,
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
                                FlSpot((historic.length + i).toDouble(), predictions[i].total),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.helper,
    required this.icon,
  });

  final String title;
  final String value;
  final String helper;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 40) / 2;
    return SizedBox(
      width: width,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(helper, style: Theme.of(context).textTheme.bodySmall),
              Text(title, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminUsersSection extends StatefulWidget {
  const AdminUsersSection({super.key});

  @override
  State<AdminUsersSection> createState() => _AdminUsersSectionState();
}

class _AdminUsersSectionState extends State<AdminUsersSection> {
  final ApiService _api = ApiService.instance;
  bool _loading = true;
  String? _error;
  List<User> _users = const [];
  List<Role> _roles = const [];
  final Map<int, int?> _draftRoles = {};

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
      final results = await Future.wait([
        _api.fetchUsers(),
        _api.fetchRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<User>;
        _roles = results[1] as List<Role>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los usuarios: $error';
        _loading = false;
      });
    }
  }

  Future<void> _saveRole(User user) async {
    final selection = _draftRoles[user.id];
    try {
      await _api.adminUpdateUser(user.id, AdminUserPayload(rol: selection));
      _draftRoles.remove(user.id);
      _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No pudimos actualizarlo: $error')));
    }
  }

  Future<void> _delete(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar usuario'),
        content: Text('¿Eliminar definitivamente a ${user.username}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _api.adminDeleteUser(user.id);
      _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No pudimos eliminarlo: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Sincronizando usuarios...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_users.isEmpty) return const Center(child: Text('No hay usuarios registrados.'));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _users.length,
      itemBuilder: (_, index) {
        final user = _users[index];
        final draft = _draftRoles[user.id] ?? user.rol;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(user.username, style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Text('#${user.id}'),
                  ],
                ),
                Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: draft,
                  decoration: const InputDecoration(
                    labelText: 'Rol asignado',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin rol')),
                    ..._roles.map((role) => DropdownMenuItem(
                          value: role.id,
                          child: Text(role.nombre),
                        )),
                  ],
                  onChanged: (value) => setState(() => _draftRoles[user.id] = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _delete(user),
                        child: const Text('Eliminar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => _saveRole(user),
                        child: const Text('Guardar rol'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar los productos: $error';
        _loading = false;
      });
    }
  }

  Future<void> _save(Product product, Map<String, dynamic> draft) async {
    try {
      final payload = ProductPayload(
        nombre: product.nombre,
        precio: draft['precio'] ?? product.precioRaw,
        stock: draft['stock'] ?? product.stock,
        descripcion: draft['descripcion'] ?? product.descripcion,
        lowStockThreshold: draft['low_stock_threshold'] ?? product.lowStockThreshold,
        categoriaId: product.categoria?.id,
        imagen: draft['imagen'] ?? product.imagen,
      );
      await _api.updateProduct(product.id, payload);
      _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No pudimos guardar: $error')));
    }
  }

  Future<void> _delete(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar definitivamente ${product.nombre}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _api.deleteProduct(product.id);
      _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No pudimos eliminarlo: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Sincronizando inventario...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_products.isEmpty) return const Center(child: Text('No hay productos registrados.'));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _products.length,
      itemBuilder: (_, index) => _ProductEditor(
        key: ValueKey(_products[index].id),
        product: _products[index],
        onSave: _save,
        onDelete: _delete,
      ),
    );
  }
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({
    super.key,
    required this.product,
    required this.onSave,
    required this.onDelete,
  });

  final Product product;
  final Future<void> Function(Product, Map<String, dynamic>) onSave;
  final Future<void> Function(Product) onDelete;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  late TextEditingController _priceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _thresholdCtrl;
  late TextEditingController _descriptionCtrl;
  final Map<String, dynamic> _draft = {};

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.product.precioRaw);
    _stockCtrl = TextEditingController(text: widget.product.stock.toString());
    _thresholdCtrl = TextEditingController(text: widget.product.lowStockThreshold.toString());
    _descriptionCtrl = TextEditingController(text: widget.product.descripcion ?? '');
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
    final product = widget.product;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ExpansionTile(
        title: Text(product.nombre),
        subtitle: Text('Stock ${product.stock} · ${currencyFormatter.format(product.precio)}'),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(labelText: 'Precio USD'),
            keyboardType: TextInputType.number,
            onChanged: (value) => _draft['precio'] = value,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _stockCtrl,
            decoration: const InputDecoration(labelText: 'Stock'),
            keyboardType: TextInputType.number,
            onChanged: (value) => _draft['stock'] = int.tryParse(value) ?? product.stock,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _thresholdCtrl,
            decoration: const InputDecoration(labelText: 'Umbral bajo'),
            keyboardType: TextInputType.number,
            onChanged: (value) =>
                _draft['low_stock_threshold'] = int.tryParse(value) ?? product.lowStockThreshold,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionCtrl,
            decoration: const InputDecoration(labelText: 'Descripción'),
            maxLines: 2,
            onChanged: (value) => _draft['descripcion'] = value,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => widget.onDelete(product),
                  child: const Text('Eliminar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => widget.onSave(product, _draft),
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

class AdminInvoicesSection extends StatefulWidget {
  const AdminInvoicesSection({super.key});

  @override
  State<AdminInvoicesSection> createState() => _AdminInvoicesSectionState();
}

class _AdminInvoicesSectionState extends State<AdminInvoicesSection> {
  final ApiService _api = ApiService.instance;
  bool _loading = true;
  String? _error;
  List<Invoice> _invoices = const [];
  List<User> _users = const [];
  String _search = '';

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
      final results = await Future.wait([
        _api.fetchAllInvoices(),
        _api.fetchUsers(),
      ]);
      if (!mounted) return;
      setState(() {
        _invoices = results[0] as List<Invoice>;
        _users = results[1] as List<User>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar las facturas: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Sincronizando facturas...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final filtered = _invoices.where((invoice) {
      if (_search.isEmpty) return true;
      final user = _users.firstWhere(
        (u) => u.id == invoice.usuario,
        orElse: () => User(id: 0, username: 'Desconocido', email: '', rol: null),
      );
      return invoice.stripeInvoiceId.toLowerCase().contains(_search) ||
          user.username.toLowerCase().contains(_search);
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar por cliente o factura',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (value) => setState(() => _search = value.toLowerCase()),
        ),
        const SizedBox(height: 16),
        ...filtered.map((invoice) {
          final user = _users.firstWhere(
            (u) => u.id == invoice.usuario,
            orElse: () => User(id: 0, username: 'Desconocido', email: '', rol: null),
          );
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(invoice.stripeInvoiceId),
              subtitle: Text('${user.username} • ${formatDateTime(invoice.createdAt)}'),
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(currencyFormatter.format(invoice.amountTotal)),
                  const SizedBox(height: 4),
                  Text(
                    invoice.status,
                    style: TextStyle(
                      color: invoice.status == 'paid' ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(child: Text('No encontramos facturas con ese criterio.')),
          ),
      ],
    );
  }
}

class AdminReportsSection extends StatefulWidget {
  const AdminReportsSection({super.key});

  @override
  State<AdminReportsSection> createState() => _AdminReportsSectionState();
}

class _AdminReportsSectionState extends State<AdminReportsSection> {
  final ApiService _api = ApiService.instance;
  final TextEditingController _promptCtrl = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _loading = false;
  bool _speechReady = false;
  bool _listening = false;
  ReportFormat _format = ReportFormat.screen;
  ReportScreenResponse? _report;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final ready = await _speech.initialize();
    if (mounted) setState(() => _speechReady = ready);
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleSpeech() async {
    if (!_speechReady) return;
    if (_listening) {
      await _speech.stop();
      setState(() => _listening = false);
      return;
    }
    final started = await _speech.listen(onResult: (result) {
      setState(() => _promptCtrl.text = result.recognizedWords);
      if (result.finalResult) {
        _generate();
      }
    });
    setState(() => _listening = started);
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) {
      setState(() => _feedback = 'Describe el reporte que necesitas.');
      return;
    }
    setState(() {
      _loading = true;
      _feedback = null;
    });
    try {
      final payload = ReportPromptPayload(prompt: prompt, format: _format);
      if (_format == ReportFormat.screen) {
        final report = await _api.generateReportScreen(payload);
        if (!mounted) return;
        setState(() => _report = report);
      } else {
        final file = await _api.generateReportFile(payload);
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/${file.filename}';
        final out = File(path);
        await out.writeAsBytes(file.bytes);
        await OpenFilex.open(out.path);
        if (!mounted) return;
        setState(() => _feedback = 'Archivo descargado en $path');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _feedback = 'No pudimos generar el reporte: $error');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        TextField(
          controller: _promptCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Describe el reporte',
            suffixIcon: IconButton(
              onPressed: _toggleSpeech,
              icon: Icon(_listening ? Icons.stop : Icons.mic),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<ReportFormat>(
          segments: const [
            ButtonSegment(value: ReportFormat.screen, label: Text('Pantalla')),
            ButtonSegment(value: ReportFormat.pdf, label: Text('PDF')),
            ButtonSegment(value: ReportFormat.excel, label: Text('Excel')),
          ],
          selected: {_format},
          onSelectionChanged: (selection) => setState(() => _format = selection.first),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading ? null : _generate,
          icon: const Icon(Icons.play_arrow),
          label: Text(_loading ? 'Generando...' : 'Generar reporte'),
        ),
        if (_feedback != null) ...[
          const SizedBox(height: 8),
          Text(_feedback!),
        ],
        if (_format == ReportFormat.screen && _report != null) ...[
          const SizedBox(height: 16),
          Text('Resumen', style: Theme.of(context).textTheme.titleMedium),
          ..._report!.summary.map((row) => ListTile(
                title: Text(row.label),
                subtitle: Text('${row.cantidad} unidades'),
                trailing: Text(currencyFormatter.format(row.montoTotal)),
              )),
          const Divider(),
          ..._report!.rows.take(20).map(
                (row) => ListTile(
                  title: Text(row.factura),
                  subtitle: Text('${row.cliente} · ${row.producto}'),
                  trailing: Text(currencyFormatter.format(row.montoTotal)),
                ),
              ),
        ],
      ],
    );
  }
}

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
      final results = await Future.wait([
        _api.fetchSalesHistory(),
        _api.fetchSalesPredictions(),
      ]);
      if (!mounted) return;
      setState(() {
        _history = results[0] as SalesHistoryResponse;
        _predictions = results[1] as SalesPredictionsResponse;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar las predicciones: $error';
        _loading = false;
      });
    }
  }

  Future<void> _retrain() async {
    await _api.retrainSalesModel();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Modelo reentrenado.')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Generando proyecciones...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final historic = _history?.monthlyTotals ?? [];
    final predicted = _predictions?.predictions ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        FilledButton.icon(
          onPressed: _retrain,
          icon: const Icon(Icons.auto_graph),
          label: const Text('Reentrenar modelo'),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        Text('Siguiente periodo', style: Theme.of(context).textTheme.titleMedium),
        ...predicted.map(
          (point) => ListTile(
            title: Text(point.label),
            trailing: Text(currencyFormatter.format(point.total)),
          ),
        ),
      ],
    );
  }
}

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
      final results = await Future.wait([
        _api.fetchProducts(),
        _api.fetchDiscounts(),
      ]);
      if (!mounted) return;
      setState(() {
        _products = results[0] as List<Product>;
        _discounts = results[1] as List<ProductDiscount>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _feedback = 'No pudimos cargar los descuentos: $error';
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
    } catch (error) {
      setState(() => _feedback = 'No pudimos guardarlo: $error');
    }
  }

  Future<void> _delete(ProductDiscount discount) async {
    await _api.deleteDiscount(discount.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Cargando descuentos...');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        DropdownButtonFormField<Product>(
          initialValue: _selectedProduct,
          decoration: const InputDecoration(
            labelText: 'Producto a promover',
            border: OutlineInputBorder(),
          ),
          items: _products
              .map((product) => DropdownMenuItem(value: product, child: Text(product.nombre)))
              .toList(),
          onChanged: (value) => setState(() => _selectedProduct = value),
        ),
        const SizedBox(height: 12),
        Text('Porcentaje: ${_percentage.toStringAsFixed(0)}%'),
        Slider(
          min: 5,
          max: 80,
          value: _percentage,
          divisions: 15,
          label: '${_percentage.toStringAsFixed(0)}%',
          onChanged: (value) => setState(() => _percentage = value),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDate(true),
                child: Text('Inicio: ${formatShortDate(_startDate.toIso8601String())}'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _pickDate(false),
                child: Text(
                  _endDate == null
                      ? 'Sin fecha fin'
                      : 'Fin: ${formatShortDate(_endDate!.toIso8601String())}',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _save,
          child: const Text('Guardar descuento'),
        ),
        if (_feedback != null) ...[
          const SizedBox(height: 8),
          Text(_feedback!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 16),
        ..._discounts.map(
          (discount) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(discount.producto.nombre),
              subtitle: Text(
                '${discount.porcentaje}% '
                '• ${formatDateTime(discount.fechaInicio)}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(discount),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar las alertas: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView(message: 'Buscando productos críticos...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_products.isEmpty) {
      return const Center(child: Text('No hay productos por debajo del umbral.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _products.length,
      itemBuilder: (_, index) {
        final product = _products[index];
        final shortage = (product.lowStockThreshold - product.stock).clamp(0, 999);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(product.nombre),
            subtitle: Text('Stock ${product.stock} • Falta $shortage para el umbral'),
            trailing: Text(
              product.stock == 0 ? 'Sin stock' : 'Crítico',
              style: TextStyle(
                color: product.stock == 0 ? Colors.red : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
