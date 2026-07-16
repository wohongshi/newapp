import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/product.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  String _searchQuery = '';
  String _sortField = 'brand'; // 'brand' or 'price'
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    List<Product> products;
    if (_searchQuery.isNotEmpty) {
      products = await db.searchProducts(_searchQuery);
    } else {
      products = await db.getAllProducts();
    }

    // Auto-sort
    if (_sortField == 'price') {
      products.sort((a, b) => a.price.compareTo(b.price));
    } else {
      products.sort((a, b) {
        final brandComp = a.brand.compareTo(b.brand);
        if (brandComp != 0) return brandComp;
        return a.price.compareTo(b.price);
      });
    }

    setState(() {
      _products = products;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group by brand or show flat list
    final Map<String, List<Product>> grouped = {};
    for (final p in _products) {
      final key = _sortField == 'brand' ? (p.brand.isEmpty ? '未分类' : p.brand) : _priceRange(p.price);
      grouped.putIfAbsent(key, () => []).add(p);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('商品管理'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (v) {
              setState(() => _sortField = v);
              _loadProducts();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'brand', child: Text('按品牌分类')),
              const PopupMenuItem(value: 'price', child: Text('按价格分类')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索商品名/条码/品牌...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) {
                _searchQuery = v;
                _loadProducts();
              },
            ),
          ),
          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Text('共 ${_products.length} 件商品',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                size: 64, color: theme.colorScheme.outline),
                            const SizedBox(height: 12),
                            const Text('暂无商品'),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () => _addProduct(),
                              icon: const Icon(Icons.add),
                              label: const Text('添加商品'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: ListView.builder(
                          itemCount: _buildListItems(grouped).length,
                          itemBuilder: (ctx, i) {
                            final item = _buildListItems(grouped)[i];
                            if (item is String) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                color: theme.colorScheme.primaryContainer
                                    .withOpacity(0.3),
                                child: Text(item,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary)),
                              );
                            }
                            final p = item as Product;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Text(p.name.isNotEmpty ? p.name[0] : '?',
                                    style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
                              ),
                              title: Text(p.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${p.brand} · ${p.barcode}'),
                              trailing: Text('¥${p.price.toStringAsFixed(2)}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: theme.colorScheme.primary)),
                              onTap: () async {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            ProductFormScreen(product: p)));
                                _loadProducts();
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        child: const Icon(Icons.add),
      ),
    );
  }

  List<dynamic> _buildListItems(Map<String, List<Product>> grouped) {
    final items = <dynamic>[];
    for (final entry in grouped.entries) {
      items.add(entry.key);
      items.addAll(entry.value);
    }
    return items;
  }

  String _priceRange(double price) {
    if (price < 1) return '¥0 - ¥1';
    if (price < 5) return '¥1 - ¥5';
    if (price < 10) return '¥5 - ¥10';
    if (price < 50) return '¥10 - ¥50';
    if (price < 100) return '¥50 - ¥100';
    return '¥100+';
  }

  void _addProduct() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ProductFormScreen()));
    _loadProducts();
  }
}
