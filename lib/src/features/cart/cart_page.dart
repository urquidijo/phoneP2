import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../core/api_service.dart';
import '../../core/models.dart';
import '../../state/cart_controller.dart';
import '../../state/session_controller.dart';
import '../../utils/formatters.dart';
import '../../widgets/state_views.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> with WidgetsBindingObserver {
  final ApiService _api = ApiService.instance;
  final TextEditingController _commandController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _loadingCatalog = true;

  // === estados de sync con servidor ===
  bool _isHydrating = false; // evita sync durante hidratación/limpieza forzada
  Timer? _syncDebounce; // debounce para POST /carritos/actual/

  String? _feedback;
  List<Product> _catalog = const [];

  // Vista previa
  Product? _previewProduct;
  int _previewQty = 1;
  bool _previewWasAction = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCatalog();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateFromServerIfNeeded();
      _attachCartListenerForSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _commandController.dispose();
    _speech.stop();
    _syncDebounce?.cancel();
    final cart = context.read<CartController>();
    cart.removeListener(_onCartChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  Future<void> _onAppResumed() async {
    final cartBefore = List.of(context.read<CartController>().items);
    await _hydrateFromServerIfNeeded();
    if (!mounted) return;
    final cart = context.read<CartController>();
    final seVacio = cartBefore.isNotEmpty && cart.isEmpty;
    if (seVacio) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago confirmado. Carrito vaciado.')),
      );
    }
    setState(() {});
  }

  /* ======================= CATALOGO + VOZ ======================= */

  Future<void> _loadCatalog() async {
    try {
      final products = await _api.fetchProducts();
      if (!mounted) return;
      setState(() {
        _catalog = products;
        _loadingCatalog = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _feedback = 'No pudimos cargar el catálogo para comandos por voz.';
        _loadingCatalog = false;
      });
    }
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize();
    if (!mounted) return;
    setState(() => _speechAvailable = available);
  }

  /* ======================= HIDRATAR Y SINCRONIZAR ======================= */

  void _attachCartListenerForSync() {
    final cart = context.read<CartController>();
    cart.addListener(_onCartChanged);
  }

  void _onCartChanged() {
    if (_isHydrating) return;
    final session = context.read<SessionController>();
    if (!session.isAuthenticated) return;
    _scheduleSync();
  }

  void _scheduleSync() {
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 500), () {
      _syncServerCartFromLocal();
    });
  }

  Future<void> _hydrateFromServerIfNeeded() async {
    final session = context.read<SessionController>();
    final cart = context.read<CartController>();

    if (!session.isAuthenticated) return;

    try {
      _isHydrating = true;
      final serverCart = await _api.fetchCurrentCart();

      if (serverCart.detalles.isNotEmpty) {
        cart.clear();
        for (final d in serverCart.detalles) {
          cart.add(d.producto, quantity: d.cantidad);
        }
      } else if (!cart.isEmpty) {
        await _syncServerCartFromLocal();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No pudimos cargar tu carrito remoto (${e.message}). Inicia sesión nuevamente.',
          ),
          action: SnackBarAction(
            label: 'Login',
            onPressed: () => Navigator.of(context).pushNamed('/auth'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error cargando tu carrito remoto.')),
      );
    } finally {
      _isHydrating = false;
    }
  }

  Future<void> _syncServerCartFromLocal() async {
    final session = context.read<SessionController>();
    if (!session.isAuthenticated) return;

    final cart = context.read<CartController>();
    final payload = CartSyncPayload(
      items: cart.items
          .map(
            (it) => CartSyncItemPayload(
              productId: it.product.id,
              quantity: it.quantity,
            ),
          )
          .toList(),
    );

    try {
      await _api.syncCart(payload);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No pudimos sincronizar tu carrito (${e.message}).'),
          action: SnackBarAction(
            label: 'Login',
            onPressed: () => Navigator.of(context).pushNamed('/auth'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al sincronizar tu carrito.')),
      );
    }
  }

  // === NUEVO: limpieza forzada DESPUÉS de crear la sesión (no bloquea la compra)
  Future<void> _clearBackendCartAfterSessionCreated() async {
    final session = context.read<SessionController>();
    final cart = context.read<CartController>();
    if (!session.isAuthenticated) return;

    _syncDebounce?.cancel();
    final prevHydrating = _isHydrating;
    _isHydrating = true;

    // Limpio LOCAL primero (UX inmediata)
    cart.clear();
    setState(() {});

    try {
      // Vacío también en BACKEND (envío items vacíos)
      final emptyPayload = CartSyncPayload(items: const []);
      await _api.syncCart(emptyPayload);
    } on ApiException catch (e) {
      if (!mounted) return;
      // No interrumpimos el flujo de pago
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo vaciar el carrito en el servidor (${e.message}).',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fallo al vaciar carrito en el servidor.'),
        ),
      );
    } finally {
      _isHydrating = prevHydrating;
    }
  }

  /* ======================= PULL-TO-REFRESH ======================= */

  Future<void> _refreshAll() async {
    try {
      final products = await _api.fetchProducts();
      if (mounted) {
        setState(() {
          _catalog = products;
        });
      }
    } catch (_) {}
    await _hydrateFromServerIfNeeded();
    if (mounted) setState(() {});
  }

  /* ======================= COMANDOS POR VOZ/TEXTO ======================= */

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;
    if (_isListening) {
      await _speech.stop();
      if (!mounted) return;
      setState(() => _isListening = false);
    } else {
      final started = await _speech.listen(
        localeId: 'es_MX',
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
        ),
        onResult: (result) {
          if (!mounted) return;
          setState(() => _commandController.text = result.recognizedWords);
          if (result.finalResult) {
            _interpretCommand(result.recognizedWords, fromVoice: true);
          }
        },
      );
      if (!mounted) return;
      setState(() => _isListening = started);
    }
  }

  void _setFeedback(String text, {bool fromVoice = false}) {
    setState(() => _feedback = '$text (${fromVoice ? "voz" : "texto"})');
  }

  void _clearPreview() {
    setState(() {
      _previewProduct = null;
      _previewQty = 1;
      _previewWasAction = false;
    });
  }

  void _interpretCommand(String command, {bool fromVoice = false}) {
    final cart = context.read<CartController>();
    final normalized = command.toLowerCase().trim();
    if (normalized.isEmpty) return;

    _clearPreview();

    if (normalized.contains('limpiar')) {
      cart.clear();
      _setFeedback('Carrito reiniciado', fromVoice: fromVoice);
      return;
    }

    if (normalized.contains('pagar')) {
      _startCheckout();
      return;
    }

    final quantityMatch = RegExp(r'(\d+)').firstMatch(normalized);
    final quantity = quantityMatch != null
        ? int.parse(quantityMatch.group(1)!)
        : 1;

    String clean(String s) => s
        .replaceAll(RegExp(r'\b(agregar|añadir|anadir|quitar|remover)\b'), '')
        .replaceAll(quantityMatch?.group(0) ?? '', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    Product? _findProduct(String q) {
      if (q.isEmpty) return null;
      final byStart = _catalog
          .where((p) => p.nombre.toLowerCase().startsWith(q))
          .toList();
      if (byStart.isNotEmpty) return byStart.first;
      try {
        return _catalog.firstWhere((p) => p.nombre.toLowerCase().contains(q));
      } catch (_) {
        return null;
      }
    }

    if (normalized.contains('agregar') ||
        normalized.contains('añadir') ||
        normalized.contains('anadir')) {
      final pname = clean(normalized);
      if (pname.isEmpty) {
        _setFeedback('Necesito el nombre del producto', fromVoice: fromVoice);
        return;
      }
      final product = _findProduct(pname);
      if (product == null) {
        _setFeedback('No encontramos $pname', fromVoice: fromVoice);
        return;
      }
      cart.add(product, quantity: quantity);
      setState(() {
        _previewProduct = product;
        _previewQty = quantity;
        _previewWasAction = true;
      });
      _setFeedback(
        'Agregamos ${product.nombre} x$quantity',
        fromVoice: fromVoice,
      );
      _scheduleSync();
      return;
    }

    if (normalized.contains('quitar') || normalized.contains('remover')) {
      final pname = clean(normalized);
      if (pname.isEmpty) {
        _setFeedback(
          'Especifica qué producto deseas quitar',
          fromVoice: fromVoice,
        );
        return;
      }
      final product = _findProduct(pname);
      if (product == null) {
        _setFeedback('No encontramos ese producto', fromVoice: fromVoice);
        return;
      }
      context.read<CartController>().remove(product.id);
      setState(() {
        _previewProduct = product;
        _previewQty = 1;
        _previewWasAction = true;
      });
      _setFeedback('Quitamos ${product.nombre}', fromVoice: fromVoice);
      _scheduleSync();
      return;
    }

    _setFeedback('No entendí el comando.', fromVoice: fromVoice);
  }

  Future<void> _startCheckout() async {
    final session = context.read<SessionController>();
    final cart = context.read<CartController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!session.isAuthenticated) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Necesitas iniciar sesión para pagar.'),
          action: SnackBarAction(
            label: 'Iniciar sesión',
            onPressed: () => navigator.pushNamed('/auth'),
          ),
        ),
      );
      return;
    }
    if (cart.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Tu carrito está vacío.')),
      );
      return;
    }

    // Tomo un snapshot de items ANTES de modificar nada
    final itemsSnapshot = cart.items
        .map(
          (item) => CheckoutItemPayload(
            productId: item.product.id,
            quantity: item.quantity,
          ),
        )
        .toList();

    // Loader
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1) Creo la sesión de checkout con el snapshot (Stripe ya tiene las líneas)
      final payload = CheckoutPayload(
        usuarioId: session.user!.id,
        items: itemsSnapshot,
        successUrl:
            'https://frontend-p2.vercel.app/checkout/success?session_id={CHECKOUT_SESSION_ID}',
        cancelUrl: 'https://frontend-p2.vercel.app/checkout/cancel',
      );

      final checkout = await _api.createCheckoutSession(payload);
      if (!mounted) return;

      // 2) Vacío carrito BACKEND + LOCAL inmediatamente (no bloquea si falla)
      await _clearBackendCartAfterSessionCreated();

      navigator.pop(); // cierro loader

      // 3) Abro Stripe
      final url = checkout.url;
      final uri = Uri.tryParse(url);
      final opened =
          uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      }

      // Nota: si cancela en Stripe, el carrito ya quedó vacío (tal como pediste).
    } catch (error) {
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Error al iniciar el pago: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    if (_loadingCatalog) {
      return const LoadingView(message: 'Preparando carrito...');
    }

    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          // ====== CARD COMANDOS / VOZ ======
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            color: theme.colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? theme.colorScheme.primary.withOpacity(.12)
                              : theme.colorScheme.surfaceVariant,
                          boxShadow: _isListening
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withOpacity(.35),
                                    blurRadius: 14,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          _isListening
                              ? Icons.graphic_eq
                              : Icons.mic_none_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Comandos rápidos',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (_speechAvailable)
                        FilledButton.tonalIcon(
                          onPressed: _toggleListening,
                          icon: Icon(_isListening ? Icons.stop : Icons.mic),
                          label: Text(_isListening ? 'Detener' : 'Hablar'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        )
                      else
                        Text(
                          'Voz no disponible',
                          style: theme.textTheme.bodySmall,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _commandController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (v) => _interpretCommand(v),
                    decoration: InputDecoration(
                      hintText:
                          'Ej: agregar 2 laptops / quitar monitor / pagar',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.play_arrow_rounded),
                        onPressed: () =>
                            _interpretCommand(_commandController.text),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceVariant.withOpacity(
                        .4,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                  if (_feedback != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _feedback!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Vista previa
                  if (_previewProduct != null) ...[
                    const SizedBox(height: 12),
                    _ProductPreviewTile(
                      product: _previewProduct!,
                      qty: _previewQty,
                      wasAction: _previewWasAction,
                      onClear: _clearPreview,
                      onAdd: () {
                        context.read<CartController>().add(
                          _previewProduct!,
                          quantity: _previewQty,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${_previewProduct!.nombre} agregado x$_previewQty',
                            ),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                        setState(() => _previewWasAction = true);
                        _scheduleSync();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ====== LISTA DEL CARRITO ======
          if (cart.isEmpty)
            _EmptyCartState(theme: theme)
          else ...[
            ...cart.items.map(
              (item) => _CartItemTile(
                product: item.product,
                quantity: item.quantity,
                onRemove: () {
                  cart.remove(item.product.id);
                  _scheduleSync();
                },
                onInc: () {
                  cart.updateQuantity(item.product.id, item.quantity + 1);
                  _scheduleSync();
                },
                onDec: () {
                  final next = (item.quantity - 1).clamp(1, 999);
                  cart.updateQuantity(item.product.id, next);
                  _scheduleSync();
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          currencyFormatter.format(cart.total),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _startCheckout,
                        icon: const Icon(Icons.lock),
                        label: const Text('Pagar'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ==================== SUBWIDGETS UI ==================== */

class _EmptyCartState extends StatelessWidget {
  const _EmptyCartState({required this.theme});
  final ThemeData theme;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 36),
        Icon(
          Icons.shopping_bag_outlined,
          size: 64,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 10),
        Text(
          'Tu carrito está vacío',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Usa la voz o busca productos para agregarlos.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.product,
    required this.quantity,
    required this.onRemove,
    required this.onInc,
    required this.onDec,
  });

  final Product product;
  final int quantity;
  final VoidCallback onRemove;
  final VoidCallback onInc;
  final VoidCallback onDec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? imageUrl = product.imagen;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      color: theme.colorScheme.surfaceVariant,
                      child: Icon(
                        Icons.image_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.descripcion ?? 'Sin descripción',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _QtyButton(icon: Icons.remove, onTap: onDec),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _QtyButton(icon: Icons.add, onTap: onInc),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormatter.format(product.effectivePrice),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (product.activeDiscount?.estaActivo ?? false)
                            Text(
                              currencyFormatter.format(product.precio),
                              style: const TextStyle(
                                decoration: TextDecoration.lineThrough,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class _ProductPreviewTile extends StatelessWidget {
  const _ProductPreviewTile({
    required this.product,
    required this.qty,
    required this.wasAction,
    required this.onClear,
    required this.onAdd,
  });

  final Product product;
  final int qty;
  final bool wasAction;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String? imageUrl = product.imagen;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 360;

        Widget image = ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 56,
                  height: 56,
                  color: theme.colorScheme.surfaceVariant,
                  child: Icon(
                    Icons.image_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        );

        final List<Widget> priceChips = [
          if (product.activeDiscount?.estaActivo ?? false)
            Text(
              currencyFormatter.format(product.precio),
              style: const TextStyle(
                decoration: TextDecoration.lineThrough,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          Text(
            currencyFormatter.format(product.effectivePrice),
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          Text('x$qty', style: theme.textTheme.bodySmall),
        ];

        final Widget prices = compact
            ? Wrap(spacing: 6, runSpacing: 2, children: priceChips)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...priceChips.expand((w) sync* {
                    yield w;
                    if (w != priceChips.last) yield const SizedBox(width: 8);
                  }),
                ],
              );

        final infoColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            prices,
            if (wasAction)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Comando aplicado',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        );

        final addButton = FilledButton.tonal(
          onPressed: onAdd,
          child: const Text('Agregar'),
        );
        final clearButton = IconButton(
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Ocultar',
        );

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        image,
                        const SizedBox(width: 10),
                        Expanded(child: infoColumn),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: wasAction
                          ? clearButton
                          : SizedBox(width: double.infinity, child: addButton),
                    ),
                  ],
                )
              : Row(
                  children: [
                    image,
                    const SizedBox(width: 10),
                    Expanded(child: infoColumn),
                    const SizedBox(width: 8),
                    if (!wasAction)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 96),
                          child: addButton,
                        ),
                      )
                    else
                      clearButton,
                  ],
                ),
        );
      },
    );
  }
}
