import 'package:flutter/foundation.dart';
import '../models/pricing_rule.dart';

class CartManager extends ChangeNotifier {
  static final CartManager instance = CartManager._();
  CartManager._();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  double get total => _items.fold(0, (sum, item) => sum + item.subtotal);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  void addItem(CartItem item) {
    final existing = _items.indexWhere((i) => i.productId == item.productId);
    if (existing >= 0) {
      _items[existing].quantity++;
    } else {
      _items.add(item);
    }
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  void updateQuantity(String productId, int quantity) {
    final idx = _items.indexWhere((i) => i.productId == productId);
    if (idx >= 0) {
      if (quantity <= 0) {
        _items.removeAt(idx);
      } else {
        _items[idx].quantity = quantity;
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
