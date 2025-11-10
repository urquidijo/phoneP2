import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart'; // <- para launchUrlString fallback

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

  // pull-to-refresh
  Future<void> _refresh() => _load();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<SessionController>().user;

    if (user == null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 56,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  'Inicia sesión para ver tus facturas.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).pushNamed('/auth'),
                  child: const Text('Iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_loading) {
      return const LoadingView(message: 'Sincronizando con Stripe...');
    }
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: _invoices.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _Header(theme: theme),
                  const SizedBox(height: 24),
                  _EmptyState(theme: theme),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: _invoices.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _Header(theme: theme),
                    );
                  }
                  final invoice = _invoices[index - 1];
                  return _InvoiceCard(
                    invoice: invoice,
                    // Botón siempre visible: manejamos la validez dentro del handler
                    onOpen: () => _openHostedInvoice(invoice.hostedInvoiceUrl),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openHostedInvoice(String? rawUrl) async {
    // 1) validar/normalizar
    final normalized = (rawUrl ?? '').trim();
    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta factura no tiene enlace público de Stripe.'),
        ),
      );
      return;
    }

    // Forzar https si viene sin esquema o con http
    Uri? uri = Uri.tryParse(normalized);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enlace de Stripe inválido.')),
      );
      return;
    }
    if (uri.scheme.isEmpty) {
      uri = Uri.parse('https://$normalized');
    } else if (uri.scheme == 'http') {
      uri = uri.replace(scheme: 'https');
    }

    // 2) intento 1: app externa
    final okExternal = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (okExternal) return;

    // 3) fallback: in-app browser view (SafariViewController/Chrome Custom Tabs)
    final okInApp = await launchUrl(
      uri,
      mode: LaunchMode.inAppBrowserView,
      webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
    );

    if (okInApp) return;

    // 4) último fallback con launchUrlString (tolerante a caracteres raros)
    final okString = await launchUrlString(
      uri.toString(),
      mode: LaunchMode.inAppBrowserView,
    );

    if (!okString && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la factura en Stripe.')),
      );
    }
  }
}

/* ===================== Subwidgets UI ===================== */

class _Header extends StatelessWidget {
  const _Header({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withOpacity(.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Historial de facturas',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 10),
          Text(
            'Aún no registramos pagos para tu cuenta.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cuando completes un pago, verás tus facturas aquí.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice, required this.onOpen});

  final Invoice invoice;
  final VoidCallback onOpen;

  Color _statusBg(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = (invoice.status).toLowerCase();
    if (s == 'paid') return scheme.primary.withOpacity(.12);
    if (s == 'open' || s == 'draft') return scheme.tertiary.withOpacity(.14);
    if (s == 'uncollectible' || s == 'void') {
      return scheme.error.withOpacity(.12);
    }
    return scheme.secondary.withOpacity(.12);
  }

  Color _statusFg(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = (invoice.status).toLowerCase();
    if (s == 'paid') return scheme.primary;
    if (s == 'open' || s == 'draft') return scheme.tertiary;
    if (s == 'uncollectible' || s == 'void') return scheme.error;
    return scheme.secondary;
  }

  IconData _statusIcon() {
    final s = (invoice.status).toLowerCase();
    if (s == 'paid') return Icons.check_circle_rounded;
    if (s == 'open' || s == 'draft') return Icons.hourglass_bottom_rounded;
    if (s == 'uncollectible' || s == 'void') return Icons.cancel_rounded;
    return Icons.receipt_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLink =
        (invoice.hostedInvoiceUrl != null &&
        invoice.hostedInvoiceUrl!.trim().isNotEmpty);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // TOP ROW
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar / ícono
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.receipt_rounded),
                    ),
                    const SizedBox(width: 12),
                    // Info principal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título + estado
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  'Factura ${invoice.stripeInvoiceId}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FittedBox(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusBg(context),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _statusIcon(),
                                        size: 16,
                                        color: _statusFg(context),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        invoice.status,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: _statusFg(context),
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatDateTime(invoice.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  color: theme.colorScheme.outlineVariant.withOpacity(.4),
                ),

                const SizedBox(height: 12),
                // Amount + botón
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        currencyFormatter.format(invoice.amountTotal),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Tooltip(
                      message: hasLink
                          ? 'Abrir factura alojada en Stripe'
                          : 'Esta factura no tiene enlace público de Stripe',
                      preferBelow: false,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 142),
                        child: FilledButton.tonalIcon(
                          // El botón siempre se muestra; si no hay link queda deshabilitado
                          onPressed: hasLink ? onOpen : () {},
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Ver en Stripe'),
                          style:
                              FilledButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 8 : 12,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ).copyWith(
                                // deshabilitar visual si no hay link
                                backgroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                      if (!hasLink)
                                        return theme.colorScheme.surfaceVariant;
                                      return null;
                                    }),
                                foregroundColor:
                                    WidgetStateProperty.resolveWith((states) {
                                      if (!hasLink)
                                        return theme.colorScheme.outline;
                                      return null;
                                    }),
                              ),
                        ),
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
