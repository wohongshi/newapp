import 'package:uuid/uuid.dart';

class Product {
  final String id;
  final String barcode;
  final String name;
  final String brand;
  final String category;
  final double price;
  final double cost;
  final int stock;
  final String createdAt;
  final String updatedAt;

  Product({
    String? id,
    required this.barcode,
    required this.name,
    this.brand = '',
    this.category = '',
    required this.price,
    this.cost = 0,
    this.stock = 0,
    String? createdAt,
    String? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'category': category,
        'price': price,
        'cost': cost,
        'stock': stock,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'],
        barcode: map['barcode'],
        name: map['name'],
        brand: map['brand'] ?? '',
        category: map['category'] ?? '',
        price: (map['price'] as num).toDouble(),
        cost: (map['cost'] as num).toDouble(),
        stock: map['stock'] ?? 0,
        createdAt: map['created_at'],
        updatedAt: map['updated_at'],
      );

  Product copyWith({
    String? barcode,
    String? name,
    String? brand,
    String? category,
    double? price,
    double? cost,
    int? stock,
  }) =>
      Product(
        id: id,
        barcode: barcode ?? this.barcode,
        name: name ?? this.name,
        brand: brand ?? this.brand,
        category: category ?? this.category,
        price: price ?? this.price,
        cost: cost ?? this.cost,
        stock: stock ?? this.stock,
        createdAt: createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );

  String get displayPrice => '¥${price.toStringAsFixed(2)}';
}
