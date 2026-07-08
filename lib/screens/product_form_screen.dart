import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/product.dart';
import '../models/pricing_rule.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final String? barcode;

  const ProductFormScreen({super.key, this.product, this.barcode});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _costCtrl;
  late final TextEditingController _stockCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? widget.barcode ?? '');
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _brandCtrl = TextEditingController(text: p?.brand ?? '');
    _categoryCtrl = TextEditingController(text: p?.category ?? '');
    _priceCtrl = TextEditingController(text: p != null ? p.price.toString() : '');
    _costCtrl = TextEditingController(text: p != null ? p.cost.toString() : '');
    _stockCtrl = TextEditingController(text: p != null ? p.stock.toString() : '0');
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑商品' : '添加商品'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _deleteProduct,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _barcodeCtrl,
              decoration: const InputDecoration(
                labelText: '条码 *',
                prefixIcon: Icon(Icons.qr_code),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? '请输入条码' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '商品名称 *',
                prefixIcon: Icon(Icons.shopping_bag_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _brandCtrl,
              decoration: const InputDecoration(
                labelText: '品牌',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: '分类',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                      labelText: '售价 *',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请输入售价';
                      if (double.tryParse(v) == null) return '无效数字';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _costCtrl,
                    decoration: const InputDecoration(
                      labelText: '成本',
                      prefixIcon: Icon(Icons.money_off),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stockCtrl,
              decoration: const InputDecoration(
                labelText: '库存',
                prefixIcon: Icon(Icons.inventory_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(isEdit ? '保存修改' : '添加商品'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final db = DatabaseHelper.instance;
      final product = Product(
        id: widget.product?.id,
        barcode: _barcodeCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        brand: _brandCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        price: double.parse(_priceCtrl.text),
        cost: double.tryParse(_costCtrl.text) ?? 0,
        stock: int.tryParse(_stockCtrl.text) ?? 0,
        createdAt: widget.product?.createdAt,
      );

      if (widget.product != null) {
        await db.updateProduct(product);
      } else {
        await db.insertProduct(product);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.product != null ? '已更新' : '已添加')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteProduct() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${widget.product!.name} 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteProduct(widget.product!.id);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除')),
        );
      }
    }
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    super.dispose();
  }
}
