import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_service.dart';
import '../../core/models.dart';
import '../../state/session_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/state_views.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final ApiService _api = ApiService.instance;

  bool _loading = true;
  String? _error;
  List<Invoice> _invoices = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<SessionController>().user;
    if (user == null) {
      setState(() {
        _loading = false;
        _invoices = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchInvoices(userId: user.id);
      if (!context.mounted) return;
      setState(() {
        _invoices = data;
        _loading = false;
      });
    } catch (error) {
      if (!context.mounted) return;
      setState(() {
        _error = 'No pudimos sincronizar tus facturas: $error';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<SessionController>().user;
    if (user == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Inicia sesión para ver tus facturas.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pushNamed('/auth'),
              child: const Text('Iniciar sesión'),
            ),
          ],
        ),
      );
    }

    if (_loading) return const LoadingView(message: 'Sincronizando con Stripe...');
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_invoices.isEmpty) {
      return const Center(child: Text('Aún no registramos pagos para tu cuenta.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: _invoices.length,
      itemBuilder: (_, index) {
        final invoice = _invoices[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Factura ${invoice.stripeInvoiceId}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatDateTime(invoice.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currencyFormatter.format(invoice.amountTotal),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                          label: Text(invoice.status),
                          backgroundColor: invoice.status == 'paid'
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                        ),
                      ],
                    ),
                  ],
                ),
                if (invoice.hostedInvoiceUrl != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _openHostedInvoice(invoice.hostedInvoiceUrl!),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Ver en Stripe'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openHostedInvoice(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
