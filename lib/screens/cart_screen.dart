import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/product.dart';
import '../models/pricing_rule.dart' as pr;
import '../models/sale.dart';
import '../services/cart_manager.dart';
import 'product_form_screen.dart';
import 'scanner_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartManager _cart = CartManager.instance;
  List<pr.PricingRule> _rules = [];
  double _discount = 0;
  List<String> _appliedRuleNames = [];

  @override
  void initState() {
    super.initState();
    _cart.addListener(_onCartChanged);
    _loadRules();
  }

  Future<void> _loadRules() async {
    _rules = await DatabaseHelper.instance.getAllRules();
  }

  void _onCartChanged() {
    setState(() {});
    _calculateDiscount();
  }

  void _calculateDiscount() {
    double discount = 0;
    _appliedRuleNames.clear();

    for (final rule in _rules.where((r) => r.enabled)) {
      // 检查规则是否适用于购物车中的商品
      bool ruleApplied = false;
      
      for (final item in _cart.items) {
        // 检查是否是选定的商品
        bool isSelected = rule.selectedProductIds.isEmpty || 
            rule.selectedProductIds.contains(item.productId);
        
        if (!isSelected) continue;
        
        // 检查条件是否满足
        if (!_evaluateConditions(item, rule.conditions)) continue;
        
        // 应用规则
        switch (rule.action.actionType) {
          case 'fixed_price':
            if (item.price > rule.action.value) {
              discount += (item.price - rule.action.value) * item.quantity;
              ruleApplied = true;
            }
            break;
          case 'percent_discount':
            discount += item.price * item.quantity * rule.action.value / 100;
            ruleApplied = true;
            break;
          case 'amount_discount':
            discount += rule.action.value * item.quantity;
            ruleApplied = true;
            break;
          case 'buy_n_get_n':
            // 买N赠N：每买buyCount件，送getCount件免费
            final buyCount = rule.action.buyCount;
            final getCount = rule.action.getCount;
            final sets = item.quantity ~/ (buyCount + getCount);
            final freeItems = sets * getCount;
            discount += item.price * freeItems;
            if (freeItems > 0) ruleApplied = true;
            break;
        }
      }
      
      if (ruleApplied) {
        _appliedRuleNames.add(rule.name);
      }
    }

    setState(() {
      _discount = discount;
    });
  }

  bool _evaluateConditions(pr.CartItem item, List<pr.RuleCondition> conditions) {
    for (final cond in conditions) {
      switch (cond.field) {
        case 'quantity':
          final val = (cond.value as num).toInt();
          switch (cond.operator) {
            case 'gte': if (item.quantity < val) return false;
            case 'lte': if (item.quantity > val) return false;
            case 'eq': if (item.quantity != val) return false;
            case 'gt': if (item.quantity <= val) return false;
            case 'lt': if (item.quantity >= val) return false;
          }
          break;
        case 'brand':
          final val = cond.value.toString();
          switch (cond.operator) {
            case 'eq': if (item.brand != val) return false;
            case 'neq': if (item.brand == val) return false;
            case 'contains': if (!item.brand.contains(val)) return false;
          }
          break;
        case 'price':
          final val = (cond.value as num).toDouble();
          switch (cond.operator) {
            case 'gte': if (item.price < val) return false;
            case 'lte': if (item.price > val) return false;
            case 'gt': if (item.price <= val) return false;
            case 'lt': if (item.price >= val) return false;
          }
          break;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _cart.total;
    final finalTotal = (total - _discount).clamp(0, double.infinity).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text('购物车 (${_cart.itemCount})'),
        actions: [
          if (_cart.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearCart,
            ),
        ],
      ),
      body: _cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_cart_outlined,
                      size: 80, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text('购物车为空', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 8),
                  const Text('扫描条码或手动添加商品'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ScannerScreen()));
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('开始扫码'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: _cart.items.length,
                    itemBuilder: (ctx, i) {
                      final item = _cart.items[i];
                      return Dismissible(
                        key: Key(item.productId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          color: Colors.red,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _cart.removeItem(item.productId),
                        child: ListTile(
                          title: Text(item.name,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${item.brand} · ¥${item.price.toStringAsFixed(2)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _cart.updateQuantity(
                                    item.productId, item.quantity - 1),
                              ),
                              Text('${item.quantity}',
                                  style: const TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => _cart.updateQuantity(
                                    item.productId, item.quantity + 1),
                              ),
                              const SizedBox(width: 8),
                              Text('¥${item.subtotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      _buildRow('商品合计', '¥${total.toStringAsFixed(2)}'),
                      if (_discount > 0) ...[
                        _buildRow(
                            '优惠减免',
                            '-¥${_discount.toStringAsFixed(2)}',
                            color: Colors.green),
                        if (_appliedRuleNames.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                                '适用规则: ${_appliedRuleNames.toSet().join(', ')}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant)),
                          ),
                      ],
                      const Divider(),
                      _buildRow('应付金额', '¥${finalTotal.toStringAsFixed(2)}',
                          bold: true, large: true),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _addManualItem,
                              icon: const Icon(Icons.add),
                              label: const Text('手动添加'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: _cart.items.isEmpty ? null : _checkout,
                              icon: const Icon(Icons.payment),
                              label: const Text('结账'),
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(0, 48)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRow(String label, String value,
      {bool bold = false, bool large = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: large ? 18 : 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontSize: large ? 22 : 14,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  void _addManualItem() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('选择商品',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProductFormScreen()));
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: products.length,
                itemBuilder: (_, i) {
                  final p = products[i];
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text('${p.brand} · ${p.barcode}'),
                    trailing: Text('¥${p.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    onTap: () {
                      _cart.addItem(pr.CartItem(
                        productId: p.id,
                        barcode: p.barcode,
                        name: p.name,
                        brand: p.brand,
                        price: p.price,
                      ));
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkout() async {
    final total = _cart.total;
    final finalTotal = (total - _discount).clamp(0, double.infinity).toDouble();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认结账'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('商品数量: ${_cart.itemCount}'),
            if (_discount > 0) Text('优惠: -¥${_discount.toStringAsFixed(2)}'),
            Text('应付: ¥${finalTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认收款')),
        ],
      ),
    );

    if (confirm == true) {
      final sale = Sale(
        total: finalTotal,
        originalTotal: total,
        discount: _discount,
      );

      final saleItems = _cart.items
          .map((item) => SaleItem(
                productId: item.productId,
                name: item.name,
                brand: item.brand,
                price: item.price,
                originalPrice: item.price,
                quantity: item.quantity,
                subtotal: item.subtotal,
              ))
          .toList();

      await DatabaseHelper.instance.insertSale(sale, saleItems);
      _cart.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('收款成功！'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  void _clearCart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空购物车'),
        content: const Text('确定要清空购物车吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              _cart.clear();
              Navigator.pop(ctx);
            },
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }
}
