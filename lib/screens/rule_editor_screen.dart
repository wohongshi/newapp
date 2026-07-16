import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/pricing_rule.dart';
import '../models/product.dart';

class RuleEditorScreen extends StatefulWidget {
  final PricingRule? rule;

  const RuleEditorScreen({super.key, this.rule});

  @override
  State<RuleEditorScreen> createState() => _RuleEditorScreenState();
}

class _RuleEditorScreenState extends State<RuleEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _valueCtrl;
  late final TextEditingController _buyCountCtrl;
  late final TextEditingController _getCountCtrl;
  int _priority = 0;
  String _actionType = 'fixed_price';
  final List<RuleCondition> _conditions = [];
  List<String> _selectedProductIds = [];
  List<Product> _allProducts = [];
  bool _loadingProducts = true;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _valueCtrl = TextEditingController(
        text: r != null ? r.action.value.toString() : '');
    _buyCountCtrl = TextEditingController(
        text: r != null ? r.action.buyCount.toString() : '1');
    _getCountCtrl = TextEditingController(
        text: r != null ? r.action.getCount.toString() : '1');
    _priority = r?.priority ?? 0;
    _actionType = r?.action.actionType ?? 'fixed_price';
    if (r != null) {
      _conditions.addAll(r.conditions);
      _selectedProductIds = List.from(r.selectedProductIds);
    }
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await DatabaseHelper.instance.getAllProducts();
    setState(() {
      _allProducts = products;
      _loadingProducts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.rule != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '编辑规则' : '新建规则'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 规则名称
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '规则名称 *',
                hintText: '例如：可乐满20件特价',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),

            // 优先级
            Row(
              children: [
                const Text('优先级: '),
                Expanded(
                  child: Slider(
                    value: _priority.toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: '$_priority',
                    onChanged: (v) => setState(() => _priority = v.toInt()),
                  ),
                ),
                Text('$_priority',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),

            // ===== 选定商品 =====
            _buildSectionTitle('选定商品'),
            _buildSelectedProducts(),
            const SizedBox(height: 16),

            // ===== 触发条件 =====
            _buildSectionTitle('触发条件（满多少件）'),
            ..._conditions.asMap().entries.map((e) {
              return Card(
                child: ListTile(
                  title: Text(e.value.displayText),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () {
                      setState(() => _conditions.removeAt(e.key));
                    },
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: _addCondition,
              icon: const Icon(Icons.add),
              label: const Text('添加条件'),
            ),
            const SizedBox(height: 24),

            // ===== 价格动作 =====
            _buildSectionTitle('价格动作'),
            DropdownButtonFormField<String>(
              value: _actionType,
              decoration: const InputDecoration(
                labelText: '动作类型',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'fixed_price', child: Text('固定价格')),
                DropdownMenuItem(value: 'percent_discount', child: Text('百分比折扣')),
                DropdownMenuItem(value: 'amount_discount', child: Text('立减金额')),
                DropdownMenuItem(value: 'buy_n_get_n', child: Text('买N赠N')),
              ],
              onChanged: (v) => setState(() => _actionType = v!),
            ),
            const SizedBox(height: 16),

            // 固定价格/折扣/立减的数值输入
            if (_actionType != 'buy_n_get_n')
              TextFormField(
                controller: _valueCtrl,
                decoration: InputDecoration(
                  labelText: _actionType == 'fixed_price'
                      ? '目标价格 (元)'
                      : _actionType == 'percent_discount'
                          ? '折扣百分比 (如10表示打9折)'
                          : '减免金额 (元)',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (_actionType == 'buy_n_get_n') return null;
                  if (v == null || v.isEmpty) return '请输入数值';
                  if (double.tryParse(v) == null) return '无效数字';
                  return null;
                },
              ),

            // 买N赠N的输入
            if (_actionType == 'buy_n_get_n')
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _buyCountCtrl,
                      decoration: const InputDecoration(
                        labelText: '买',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (_actionType != 'buy_n_get_n') return null;
                        if (v == null || v.isEmpty) return '请输入';
                        if (int.tryParse(v) == null || int.parse(v) < 1) return '至少1';
                        return null;
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('赠', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _getCountCtrl,
                      decoration: const InputDecoration(
                        labelText: '送',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (_actionType != 'buy_n_get_n') return null;
                        if (v == null || v.isEmpty) return '请输入';
                        if (int.tryParse(v) == null || int.parse(v) < 1) return '至少1';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 32),

            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52)),
              child: Text(isEdit ? '保存修改' : '创建规则'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  // ===== 选定商品组件 =====
  Widget _buildSelectedProducts() {
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }

    final selectedProducts = _allProducts
        .where((p) => _selectedProductIds.contains(p.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 已选商品列表
        if (selectedProducts.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: selectedProducts.map((p) => Chip(
              avatar: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text(p.name.isNotEmpty ? p.name[0] : '?', 
                    style: const TextStyle(fontSize: 12)),
              ),
              label: Text('${p.name} ¥${p.price.toStringAsFixed(2)}'),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() => _selectedProductIds.remove(p.id));
              },
            )).toList(),
          ),
        if (selectedProducts.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('未选择任何商品', style: TextStyle(color: Colors.grey)),
            ),
          ),
        const SizedBox(height: 8),
        // 添加商品按钮
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showProductSelector,
                icon: const Icon(Icons.add),
                label: const Text('选择商品'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _showBatchSelector,
                icon: const Icon(Icons.checklist),
                label: const Text('批量选择'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===== 单个选择商品 =====
  void _showProductSelector() {
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: _allProducts.length,
                itemBuilder: (_, i) {
                  final p = _allProducts[i];
                  final isSelected = _selectedProductIds.contains(p.id);
                  return ListTile(
                    leading: Checkbox(
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedProductIds.add(p.id);
                          } else {
                            _selectedProductIds.remove(p.id);
                          }
                        });
                        // 不关闭，继续选择
                      },
                    ),
                    title: Text(p.name),
                    subtitle: Text('${p.brand} · ${p.barcode}'),
                    trailing: Text('¥${p.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedProductIds.remove(p.id);
                        } else {
                          _selectedProductIds.add(p.id);
                        }
                      });
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

  // ===== 批量选择商品 =====
  void _showBatchSelector() {
    // 按品牌分组
    final Map<String, List<Product>> brandGroups = {};
    for (final p in _allProducts) {
      final brand = p.brand.isEmpty ? '未分类' : p.brand;
      brandGroups.putIfAbsent(brand, () => []).add(p);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('批量选择',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                children: brandGroups.entries.map((entry) {
                  final brand = entry.key;
                  final products = entry.value;
                  final allSelected = products.every((p) => _selectedProductIds.contains(p.id));
                  final someSelected = products.any((p) => _selectedProductIds.contains(p.id));

                  return ExpansionTile(
                    leading: Checkbox(
                      value: allSelected ? true : (someSelected ? null : false),
                      tristate: true,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            // 全选该品牌
                            for (final p in products) {
                              if (!_selectedProductIds.contains(p.id)) {
                                _selectedProductIds.add(p.id);
                              }
                            }
                          } else {
                            // 取消全选
                            for (final p in products) {
                              _selectedProductIds.remove(p.id);
                            }
                          }
                        });
                      },
                    ),
                    title: Text('$brand (${products.length}件)'),
                    children: products.map((p) {
                      final isSelected = _selectedProductIds.contains(p.id);
                      return ListTile(
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedProductIds.add(p.id);
                              } else {
                                _selectedProductIds.remove(p.id);
                              }
                            });
                          },
                        ),
                        title: Text(p.name),
                        trailing: Text('¥${p.price.toStringAsFixed(2)}'),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addCondition() {
    String field = 'quantity';
    String operator = 'gte';
    dynamic value = 0;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('添加条件'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: field,
                    decoration: const InputDecoration(
                        labelText: '字段', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'quantity', child: Text('数量')),
                      DropdownMenuItem(value: 'total_quantity', child: Text('总数量')),
                      DropdownMenuItem(value: 'brand', child: Text('品牌')),
                      DropdownMenuItem(value: 'price', child: Text('单价')),
                      DropdownMenuItem(value: 'total_amount', child: Text('总金额')),
                    ],
                    onChanged: (v) {
                      setDialogState(() {
                        field = v!;
                        if (field == 'brand') {
                          operator = 'eq';
                          value = '';
                        } else {
                          operator = 'gte';
                          value = 0;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: operator,
                    decoration: const InputDecoration(
                        labelText: '运算符', border: OutlineInputBorder()),
                    items: field == 'brand'
                        ? const [
                            DropdownMenuItem(value: 'eq', child: Text('= (等于)')),
                            DropdownMenuItem(value: 'neq', child: Text('≠ (不等于)')),
                            DropdownMenuItem(value: 'contains', child: Text('包含')),
                          ]
                        : const [
                            DropdownMenuItem(value: 'gte', child: Text('≥ (大于等于)')),
                            DropdownMenuItem(value: 'lte', child: Text('≤ (小于等于)')),
                            DropdownMenuItem(value: 'eq', child: Text('= (等于)')),
                            DropdownMenuItem(value: 'gt', child: Text('> (大于)')),
                            DropdownMenuItem(value: 'lt', child: Text('< (小于)')),
                          ],
                    onChanged: (v) => setDialogState(() => operator = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: field == 'brand' ? '品牌名称' : '数值',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      if (field == 'brand') {
                        value = v;
                      } else {
                        value = int.tryParse(v) ?? double.tryParse(v) ?? 0;
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消')),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _conditions.add(RuleCondition(
                        field: field,
                        operator: operator,
                        value: value,
                      ));
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final rule = PricingRule(
      id: widget.rule?.id,
      name: _nameCtrl.text.trim(),
      enabled: widget.rule?.enabled ?? true,
      priority: _priority,
      conditions: _conditions,
      selectedProductIds: _selectedProductIds,
      action: RuleAction(
        actionType: _actionType,
        value: _actionType == 'buy_n_get_n' ? 0 : (double.tryParse(_valueCtrl.text) ?? 0),
        buyCount: _actionType == 'buy_n_get_n' ? (int.tryParse(_buyCountCtrl.text) ?? 1) : 1,
        getCount: _actionType == 'buy_n_get_n' ? (int.tryParse(_getCountCtrl.text) ?? 1) : 1,
      ),
      createdAt: widget.rule?.createdAt,
    );

    final db = DatabaseHelper.instance;
    if (widget.rule != null) {
      await db.updateRule(rule);
    } else {
      await db.insertRule(rule);
    }

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.rule != null ? '规则已更新' : '规则已创建')),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    _buyCountCtrl.dispose();
    _getCountCtrl.dispose();
    super.dispose();
  }
}
