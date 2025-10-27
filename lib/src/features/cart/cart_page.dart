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

class _CartPageState extends State<CartPage> {
  final ApiService _api = ApiService.instance;
  final TextEditingController _commandController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _loadingCatalog = true;
  String? _feedback;
  List<Product> _catalog = const [];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
    _initSpeech();
  }

  Future<void> _loadCatalog() async {
    try {
      final products = await _api.fetchProducts();
      if (!context.mounted) return;
      setState(() {
        _catalog = products;
        _loadingCatalog = false;
      });
    } catch (error) {
      if (!context.mounted) return;
      setState(() {
        _feedback = 'No pudimos cargar el catálogo para comandos por voz.';
        _loadingCatalog = false;
      });
    }
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize();
    if (!context.mounted) return;
    setState(() => _speechAvailable = available);
  }

  @override
  void dispose() {
    _commandController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;
    if (_isListening) {
      await _speech.stop();
      if (!context.mounted) return;
      setState(() => _isListening = false);
    } else {
      final started = await _speech.listen(
        localeId: 'es_MX',
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
        ),
        onResult: (result) {
          if (!context.mounted) return;
          setState(() => _commandController.text = result.recognizedWords);
          if (result.finalResult) {
            _interpretCommand(result.recognizedWords, fromVoice: true);
          }
        },
      );
      if (!context.mounted) return;
      setState(() => _isListening = started);
    }
  }

  void _interpretCommand(String command, {bool fromVoice = false}) {
    final cart = context.read<CartController>();
    final normalized = command.toLowerCase().trim();
    if (normalized.isEmpty) return;

    void setFeedback(String text) {
      setState(() => _feedback = '$text (${fromVoice ? "voz" : "texto"})');
    }

    if (normalized.contains('limpiar')) {
      cart.clear();
      setFeedback('Carrito reiniciado');
      return;
    }

    if (normalized.contains('pagar')) {
      _startCheckout();
      return;
    }

    final quantityMatch = RegExp(r'(\d+)').firstMatch(normalized);
    final quantity = quantityMatch != null ? int.parse(quantityMatch.group(1)!) : 1;

    if (normalized.contains('agregar') ||
        normalized.contains('añadir') ||
        normalized.contains('anadir')) {
      final productName = normalized
          .replaceAll(RegExp(r'agregar|añadir|anadir'), '')
          .replaceAll(quantityMatch?.group(0) ?? '', '')
          .trim();
      if (productName.isEmpty) {
        setFeedback('Necesito el nombre del producto');
        return;
      }
      try {
        final product = _catalog.firstWhere(
          (item) => item.nombre.toLowerCase().contains(productName),
        );
        cart.add(product, quantity: quantity);
        setFeedback('Agregamos ${product.nombre} x$quantity');
      } catch (_) {
        setFeedback('No encontramos $productName');
      }
      return;
    }

    if (normalized.contains('quitar') || normalized.contains('remover')) {
      final productName = normalized
          .replaceAll(RegExp(r'quitar|remover'), '')
          .replaceAll(quantityMatch?.group(0) ?? '', '')
          .trim();
      if (productName.isEmpty) {
        setFeedback('Especifica qué producto deseas quitar');
        return;
      }
      try {
        final product = _catalog.firstWhere(
          (item) => item.nombre.toLowerCase().contains(productName),
        );
        cart.remove(product.id);
        setFeedback('Quitamos ${product.nombre}');
      } catch (_) {
        setFeedback('No encontramos ese producto');
      }
      return;
    }

    setFeedback('No entendí el comando.');
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
      messenger.showSnackBar(const SnackBar(content: Text('Tu carrito está vacío.')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final payload = CheckoutPayload(
        usuarioId: session.user!.id,
        items: cart.items
            .map((item) => CheckoutItemPayload(
                  productId: item.product.id,
                  quantity: item.quantity,
                ))
            .toList(),
        successUrl: 'https://electrostore-mobile-success.example',
        cancelUrl: 'https://electrostore-mobile-cancel.example',
      );
      final checkout = await _api.createCheckoutSession(payload);
      if (!context.mounted) return;
      navigator.pop();
      final url = checkout.url;
      final uri = Uri.tryParse(url);
      final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      }
    } catch (error) {
      if (!context.mounted) return;
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.record_voice_over),
                    const SizedBox(width: 8),
                    Text(
                      'Comandos rápidos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (_speechAvailable)
                      IconButton(
                        onPressed: _toggleListening,
                        icon: Icon(_isListening ? Icons.stop : Icons.mic),
                        tooltip: _isListening ? 'Detener voz' : 'Hablar',
                      )
                    else
                      const Text(
                        'Voz no disponible',
                        style: TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commandController,
                  decoration: InputDecoration(
                    hintText: 'Ej: agregar 2 laptops o quitar monitor',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => _interpretCommand(_commandController.text),
                    ),
                  ),
                ),
                if (_feedback != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _feedback!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (cart.isEmpty)
          Column(
            children: [
              const SizedBox(height: 48),
              Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade500),
              const SizedBox(height: 12),
              const Text('Tu carrito está vacío.'),
            ],
          )
        else ...[
          ...cart.items.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.product.nombre,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      item.product.descripcion ?? 'Sin descripción',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  final next = (item.quantity - 1).clamp(1, 999);
                                  cart.updateQuantity(item.product.id, next);
                                },
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${item.quantity}', style: const TextStyle(fontSize: 16)),
                              IconButton(
                                onPressed: () {
                                  cart.updateQuantity(item.product.id, item.quantity + 1);
                                },
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currencyFormatter.format(item.product.effectivePrice),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (item.product.activeDiscount?.estaActivo ?? false)
                              Text(
                                currencyFormatter.format(item.product.precio),
                                style: const TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormatter.format(item.subtotal),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => cart.remove(item.product.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
                    'Total: ${currencyFormatter.format(cart.total)}',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _startCheckout,
                      icon: const Icon(Icons.lock),
                      label: const Text('Pagar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
