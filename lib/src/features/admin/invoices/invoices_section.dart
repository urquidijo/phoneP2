// lib/features/admin/invoices/invoices_section.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/api_service.dart';
import '../../../core/models.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/state_views.dart';
import '../shared/section_scaffold.dart';
import '../shared/empty_state.dart';

enum _StatusFilter { all, paid, open }

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
  String _q = '';
  _StatusFilter _filter = _StatusFilter.all;

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No pudimos cargar las facturas: $e';
        _loading = false;
      });
    }
  }

  List<Invoice> _applyFilters() {
    var list = _invoices;

    switch (_filter) {
      case _StatusFilter.paid:
        list = list.where((i) => i.status == 'paid').toList();
        break;
      case _StatusFilter.open:
        list = list.where((i) => i.status != 'paid').toList();
        break;
      case _StatusFilter.all:
        break;
    }

    if (_q.isNotEmpty) {
      list = list.where((inv) {
        final user = _users.firstWhere(
          (u) => u.id == inv.usuario,
          orElse: () =>
              User(id: 0, username: 'Desconocido', email: '', rol: null),
        );
        return inv.stripeInvoiceId.toLowerCase().contains(_q) ||
            user.username.toLowerCase().contains(_q);
      }).toList();
    }
    return list;
  }

  double _sumAmount(List<Invoice> items) =>
      items.fold<double>(0, (s, i) => s + i.amountTotal);

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const LoadingView(message: 'Sincronizando facturas...');
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);

    final filtered = _applyFilters();
    final total = _sumAmount(filtered);

    return SectionScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderBar(
            count: filtered.length,
            totalFormatted: currencyFormatter.format(total),
            filter: _filter,
            onFilter: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 12),
          _SearchBar(
            value: _q,
            onChange: (v) => setState(() => _q = v.trim().toLowerCase()),
            onClear: () => setState(() => _q = ''),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const EmptyState(
              message: 'No encontramos facturas con ese criterio.',
            )
          else
            ...filtered.map((inv) {
              final u = _users.firstWhere(
                (x) => x.id == inv.usuario,
                orElse: () =>
                    User(id: 0, username: 'Desconocido', email: '', rol: null),
              );
              return _InvoiceRow(
                id: inv.stripeInvoiceId,
                customer: u.username,
                date: formatDateTime(inv.createdAt),
                amountFormatted: currencyFormatter.format(inv.amountTotal),
                status: inv.status,
              );
            }),
        ],
      ),
    );
  }
}

/* ------------------------- UI widgets privados ------------------------- */

class _HeaderBar extends StatelessWidget {
  const _HeaderBar({
    required this.count,
    required this.totalFormatted,
    required this.filter,
    required this.onFilter,
  });

  final int count;
  final String totalFormatted;
  final _StatusFilter filter;
  final ValueChanged<_StatusFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Wrap evita overflow horizontal y permite saltar a 2 líneas
    return LayoutBuilder(
      builder: (context, cons) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant.withOpacity(.6)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count factura${count == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                totalFormatted,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Spacer equivalente para Wrap: usamos SizedBox con width dinámico
            SizedBox(width: cons.maxWidth > 560 ? cons.maxWidth - 360 : 0),
            SegmentedButton<_StatusFilter>(
              segments: const [
                ButtonSegment(
                  value: _StatusFilter.all,
                  label: Text('Todas'),
                  icon: Icon(Icons.all_inbox_outlined),
                ),
                ButtonSegment(
                  value: _StatusFilter.paid,
                  label: Text('Pagadas'),
                  icon: Icon(Icons.verified_outlined),
                ),
                ButtonSegment(
                  value: _StatusFilter.open,
                  label: Text('Pendientes'),
                  icon: Icon(Icons.timelapse_outlined),
                ),
              ],
              showSelectedIcon: false,
              selected: {filter},
              onSelectionChanged: (s) => onFilter(s.first),
            ),
          ],
        );
      },
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.value,
    required this.onChange,
    required this.onClear,
  });

  final String value;
  final ValueChanged<String> onChange;
  final VoidCallback onClear;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _c.text != widget.value) {
      _c.text = widget.value;
      _c.selection = TextSelection.fromPosition(
        TextPosition(offset: _c.text.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      onChanged: widget.onChange,
      decoration: InputDecoration(
        hintText: 'Buscar por cliente o factura',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar',
                onPressed: () {
                  _c.clear();
                  widget.onClear();
                },
                icon: const Icon(Icons.close),
              ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.id,
    required this.customer,
    required this.date,
    required this.amountFormatted,
    required this.status,
  });

  final String id;
  final String customer;
  final String date;
  final String amountFormatted;
  final String status;

  bool get isPaid => status == 'paid';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, cons) {
        final narrow = cons.maxWidth < 420; // breakpoint móvil
        final row = Row(
          children: [
            // ID + copiar
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copiar ID',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ID copiado')),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Cliente + fecha
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            ),

            // Monto + estado
            Expanded(
              flex: 4,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      amountFormatted,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(
                    text: isPaid ? 'pagada' : status,
                    color: isPaid ? Colors.green : Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        );

        // Contenedor con borde suave (fila compacta)
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withOpacity(.5)),
          ),
          child: narrow
              // En móviles apilamos: arriba (ID + copiar) y monto/estado,
              // abajo (cliente + fecha)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copiar ID',
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ID copiado')),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              amountFormatted,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _StatusPill(
                          text: isPaid ? 'pagada' : status,
                          color: isPaid ? Colors.green : Colors.orange,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$customer • $date',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: cs.outline),
                    ),
                  ],
                )
              : row,
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final bg = color.withOpacity(.12);
    final fg = color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(.4)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: .2,
          height: 1,
        ),
      ),
    );
  }
}
