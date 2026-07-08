import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/pricing_rule.dart';

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
  int _priority = 0;
  String _applyTo = 'item';
  String _actionType = 'fixed_price';
  final List<RuleCondition> _conditions = [];

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _valueCtrl = TextEditingController(
        text: r != null ? r.action.value.toString() : '');
    _priority = r?.priority ?? 0;
    _applyTo = r?.action.applyTo ?? 'item';
    _actionType = r?.action.actionType ?? 'fixed_price';
    if (r != null) {
      _conditions.addAll(r.conditions);
    }
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
            // Rule name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: '规则名称 *',
                hintText: '例如：满20件特价',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == null || v.isEmpty ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),

            // Priority
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

            // Conditions
            _buildSectionTitle('触发条件'),
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

            // Action
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
                DropdownMenuItem(value: 'bogo', child: Text('买一送一')),
              ],
              onChanged: (v) => setState(() => _actionType = v!),
            ),
            const SizedBox(height: 16),
            if (_actionType != 'bogo')
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
                  if (_actionType == 'bogo') return null;
                  if (v == null || v.isEmpty) return '请输入数值';
                  if (double.tryParse(v) == null) return '无效数字';
                  return null;
                },
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _applyTo,
              decoration: const InputDecoration(
                labelText: '作用范围',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'item', child: Text('单品（仅对单个商品）')),
                DropdownMenuItem(value: 'all_matching', child: Text('所有匹配商品')),
                DropdownMenuItem(value: 'cart', child: Text('整单（按比例分摊）')),
              ],
              onChanged: (v) => setState(() => _applyTo = v!),
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
      action: RuleAction(
        actionType: _actionType,
        value: _actionType == 'bogo' ? 0 : (double.tryParse(_valueCtrl.text) ?? 0),
        applyTo: _applyTo,
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
    super.dispose();
  }
}
