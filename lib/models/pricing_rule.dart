import 'dart:convert';
import 'package:uuid/uuid.dart';

class PricingRule {
  final String id;
  final String name;
  final bool enabled;
  final int priority;
  final List<RuleCondition> conditions;
  final RuleAction action;
  final List<String> selectedProductIds; // 选定的商品ID列表
  final String createdAt;
  final String updatedAt;

  PricingRule({
    String? id,
    required this.name,
    this.enabled = true,
    this.priority = 0,
    required this.conditions,
    required this.action,
    this.selectedProductIds = const [],
    String? createdAt,
    String? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'enabled': enabled ? 1 : 0,
        'priority': priority,
        'rules_json': jsonEncode({
          'conditions': conditions.map((c) => c.toMap()).toList(),
          'action': action.toMap(),
          'selected_product_ids': selectedProductIds,
        }),
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory PricingRule.fromMap(Map<String, dynamic> map) {
    final data = jsonDecode(map['rules_json']);
    return PricingRule(
      id: map['id'],
      name: map['name'],
      enabled: map['enabled'] == 1,
      priority: map['priority'] ?? 0,
      conditions: (data['conditions'] as List?)
              ?.map((c) => RuleCondition.fromMap(c))
              .toList() ??
          [],
      action: RuleAction.fromMap(data['action'] ?? {}),
      selectedProductIds: (data['selected_product_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  PricingRule copyWith({
    String? name,
    bool? enabled,
    int? priority,
    List<RuleCondition>? conditions,
    RuleAction? action,
    List<String>? selectedProductIds,
  }) =>
      PricingRule(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        priority: priority ?? this.priority,
        conditions: conditions ?? this.conditions,
        action: action ?? this.action,
        selectedProductIds: selectedProductIds ?? this.selectedProductIds,
        createdAt: createdAt,
        updatedAt: DateTime.now().toIso8601String(),
      );
}

class RuleCondition {
  final String field;
  final String operator;
  final dynamic value;

  RuleCondition({
    required this.field,
    required this.operator,
    required this.value,
  });

  Map<String, dynamic> toMap() => {
        'field': field,
        'operator': operator,
        'value': value,
      };

  factory RuleCondition.fromMap(Map<String, dynamic> map) => RuleCondition(
        field: map['field'],
        operator: map['operator'],
        value: map['value'],
      );

  String get displayText {
    final fieldNames = {
      'quantity': '数量',
      'brand': '品牌',
      'price': '单价',
      'category': '分类',
      'total_quantity': '总数量',
      'total_amount': '总金额',
    };
    final opNames = {
      'gte': '≥',
      'lte': '≤',
      'eq': '=',
      'neq': '≠',
      'gt': '>',
      'lt': '<',
      'contains': '包含',
    };
    return '${fieldNames[field] ?? field} ${opNames[operator] ?? operator} $value';
  }
}

class RuleAction {
  final String actionType; // fixed_price, percent_discount, amount_discount, buy_n_get_n
  final double value;
  final int buyCount;   // 买N赠N：买几个
  final int getCount;   // 买N赠N：送几个

  RuleAction({
    required this.actionType,
    required this.value,
    this.buyCount = 1,
    this.getCount = 1,
  });

  Map<String, dynamic> toMap() => {
        'action_type': actionType,
        'value': value,
        'buy_count': buyCount,
        'get_count': getCount,
      };

  factory RuleAction.fromMap(Map<String, dynamic> map) => RuleAction(
        actionType: map['action_type'] ?? 'fixed_price',
        value: (map['value'] as num?)?.toDouble() ?? 0,
        buyCount: (map['buy_count'] as num?)?.toInt() ?? 1,
        getCount: (map['get_count'] as num?)?.toInt() ?? 1,
      );

  String get displayText {
    switch (actionType) {
      case 'fixed_price':
        return '固定价格 ¥${value.toStringAsFixed(2)}';
      case 'percent_discount':
        return '打${(100 - value).toStringAsFixed(0)}折';
      case 'amount_discount':
        return '立减¥${value.toStringAsFixed(2)}';
      case 'buy_n_get_n':
        return '买$buyCount赠$getCount';
      default:
        return '$actionType $value';
    }
  }
}

class CartItem {
  final String productId;
  final String barcode;
  final String name;
  final String brand;
  final double price;
  final double cost;
  int quantity;

  CartItem({
    required this.productId,
    required this.barcode,
    required this.name,
    this.brand = '',
    required this.price,
    this.cost = 0,
    this.quantity = 1,
  });

  double get subtotal => price * quantity;

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'barcode': barcode,
        'name': name,
        'brand': brand,
        'price': price,
        'cost': cost,
        'quantity': quantity,
      };
}
