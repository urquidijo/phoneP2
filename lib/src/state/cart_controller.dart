import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../core/session_storage.dart';

class CartController extends ChangeNotifier {
  CartController({SessionStorage? storage}) : _storage = storage ?? SessionStorage.instance;

  final SessionStorage _storage;
  final List<CartItem> _items = [];
  bool _initialized = false;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  double get total =>
      _items.fold<double>(0, (sum, item) => sum + item.product.effectivePrice * item.quantity);

  Future<void> load() async {
    if (_initialized) return;
    final saved = await _storage.loadCart();
    _items
      ..clear()
      ..addAll(saved);
    _initialized = true;
    notifyListeners();
  }

  Future<void> _syncStorage() => _storage.saveCart(_items);

  Future<void> add(Product product, {int quantity = 1}) async {
    await load();
    final existing = _items.where((item) => item.product.id == product.id).firstOrNull;
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    await _syncStorage();
    notifyListeners();
  }

  Future<void> updateQuantity(int productId, int quantity) async {
    await load();
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index == -1) return;
    _items[index].quantity = quantity.clamp(1, 999);
    await _syncStorage();
    notifyListeners();
  }

  Future<void> remove(int productId) async {
    await load();
    _items.removeWhere((item) => item.product.id == productId);
    await _syncStorage();
    notifyListeners();
  }

  Future<void> clear() async {
    _items.clear();
    await _storage.clearCart();
    notifyListeners();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
