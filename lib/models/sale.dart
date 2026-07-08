import 'package:uuid/uuid.dart';

class Sale {
  final String id;
  final double total;
  final double originalTotal;
  final double discount;
  final String paymentMethod;
  final String createdAt;

  Sale({
    String? id,
    required this.total,
    required this.originalTotal,
    this.discount = 0,
    this.paymentMethod = 'cash',
    String? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'total': total,
        'original_total': originalTotal,
        'discount': discount,
        'payment_method': paymentMethod,
        'created_at': createdAt,
      };

  factory Sale.fromMap(Map<String, dynamic> map) => Sale(
        id: map['id'],
        total: (map['total'] as num).toDouble(),
        originalTotal: (map['original_total'] as num).toDouble(),
        discount: (map['discount'] as num?)?.toDouble() ?? 0,
        paymentMethod: map['payment_method'] ?? 'cash',
        createdAt: map['created_at'],
      );
}

class SaleItem {
  final String productId;
  final String name;
  final String brand;
  final double price;
  final double originalPrice;
  final int quantity;
  final double subtotal;

  SaleItem({
    required this.productId,
    required this.name,
    this.brand = '',
    required this.price,
    required this.originalPrice,
    required this.quantity,
    required this.subtotal,
  });

  Map<String, dynamic> toMap(String saleId) => {
        'sale_id': saleId,
        'product_id': productId,
        'name': name,
        'brand': brand,
        'price': price,
        'original_price': originalPrice,
        'quantity': quantity,
        'subtotal': subtotal,
      };

  factory SaleItem.fromMap(Map<String, dynamic> map) => SaleItem(
        productId: map['product_id'],
        name: map['name'],
        brand: map['brand'] ?? '',
        price: (map['price'] as num).toDouble(),
        originalPrice: (map['original_price'] as num).toDouble(),
        quantity: map['quantity'],
        subtotal: (map['subtotal'] as num).toDouble(),
      );
}
