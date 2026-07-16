import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'rule_editor_screen.dart';
import 'backup_screen.dart';
import '../db/database_helper.dart';
import '../models/pricing_rule.dart';
import '../models/product.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<PricingRule> _rules = [];
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final rules = await db.getAllRules();
    final theme = await db.getSetting('theme_mode');
    setState(() {
      _rules = rules;
      switch (theme) {
        case 'light':
          _themeMode = ThemeMode.light;
          break;
        case 'dark':
          _themeMode = ThemeMode.dark;
          break;
        default:
          _themeMode = ThemeMode.system;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // Pricing Rules Section
          _SectionHeader(title: '定价规则', icon: Icons.rule),
          if (_rules.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.rule, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  const Text('暂无定价规则'),
                  const SizedBox(height: 4),
                  Text('设置规则后可自动调整价格',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            )
          else
            ...(_rules.map((rule) => _RuleTile(
                  rule: rule,
                  onToggle: (enabled) async {
                    await DatabaseHelper.instance
                        .updateRule(rule.copyWith(enabled: enabled));
                    _loadData();
                  },
                  onEdit: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => RuleEditorScreen(rule: rule)));
                    _loadData();
                  },
                  onDelete: () async {
                    await DatabaseHelper.instance.deleteRule(rule.id);
                    _loadData();
                  },
                ))),
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RuleEditorScreen()));
                _loadData();
              },
              icon: const Icon(Icons.add),
              label: const Text('添加定价规则'),
            ),
          ),
          const Divider(),

          // Rule specification doc
          _SectionHeader(title: '规则编写规范', icon: Icons.description_outlined),
          _RuleDocTile(),

          const Divider(),

          // Theme
          _SectionHeader(title: '外观', icon: Icons.palette),
          ListTile(
            title: const Text('主题模式'),
            subtitle: Text(_getThemeModeName(_themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(),
          ),

          const Divider(),

          // Security
          _SectionHeader(title: '安全', icon: Icons.security),
          ListTile(
            title: const Text('应用密码'),
            subtitle: const Text('已启用（首次使用时设置）'),
            trailing: const Icon(Icons.lock, color: Colors.green),
          ),

          const Divider(),

          // Data
          _SectionHeader(title: '数据', icon: Icons.storage),
          ListTile(
            leading: const Icon(Icons.import_export),
            title: const Text('数据管理'),
            subtitle: const Text('导入/导出商品数据'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const BackupScreen()));
            },
          ),

          const Divider(),

          // About
          _SectionHeader(title: '关于', icon: Icons.info_outline),
          const ListTile(
            title: Text('智能收银台'),
            subtitle: Text('v1.0.0 · 纯本地版'),
          ),
          const ListTile(
            title: Text('技术栈'),
            subtitle: Text('Flutter + Rust · SQLite本地存储'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
  
  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '浅色模式';
      case ThemeMode.dark:
        return '深色模式（纯黑）';
      case ThemeMode.system:
        return '跟随系统';
    }
  }
  
  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('主题模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('跟随系统'),
              value: ThemeMode.system,
              groupValue: _themeMode,
              onChanged: (v) => _setThemeMode(v!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('浅色模式'),
              value: ThemeMode.light,
              groupValue: _themeMode,
              onChanged: (v) => _setThemeMode(v!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('深色模式（纯黑）'),
              value: ThemeMode.dark,
              groupValue: _themeMode,
              onChanged: (v) => _setThemeMode(v!),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _setThemeMode(ThemeMode mode) async {
    final db = DatabaseHelper.instance;
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
        value = 'system';
    }
    await db.setSetting('theme_mode', value);
    setState(() => _themeMode = mode);
    Navigator.pop(context);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final PricingRule rule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleTile({
    required this.rule,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: Switch(value: rule.enabled, onChanged: onToggle),
      title: Text(rule.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(rule.action.displayText, style: const TextStyle(fontSize: 12)),
      trailing: PopupMenuButton(
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('编辑')),
          const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(color: Colors.red))),
        ],
        onSelected: (v) {
          if (v == 'edit') onEdit();
          if (v == 'delete') onDelete();
        },
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 触发条件
              if (rule.conditions.isNotEmpty) ...[
                const Text('触发条件:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: rule.conditions.map((c) => Chip(
                    label: Text(c.displayText, style: const TextStyle(fontSize: 11)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  )).toList(),
                ),
                const SizedBox(height: 8),
              ],
              // 生效商品
              const Text('生效商品:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              _AffectedProductsWidget(rule: rule),
            ],
          ),
        ),
      ],
    );
  }
}

class _AffectedProductsWidget extends StatefulWidget {
  final PricingRule rule;
  
  const _AffectedProductsWidget({required this.rule});
  
  @override
  State<_AffectedProductsWidget> createState() => _AffectedProductsWidgetState();
}

class _AffectedProductsWidgetState extends State<_AffectedProductsWidget> {
  List<Product> _affectedProducts = [];
  bool _loading = true;
  
  @override
  void initState() {
    super.initState();
    _loadAffectedProducts();
  }
  
  Future<void> _loadAffectedProducts() async {
    final db = DatabaseHelper.instance;
    final allProducts = await db.getAllProducts();
    
    // 根据规则条件筛选受影响的商品
    final affected = allProducts.where((product) {
      for (final cond in widget.rule.conditions) {
        switch (cond.field) {
          case 'brand':
            final val = cond.value.toString();
            switch (cond.operator) {
              case 'eq': if (product.brand != val) return false;
              case 'neq': if (product.brand == val) return false;
              case 'contains': if (!product.brand.contains(val)) return false;
            }
            break;
          case 'price':
            final val = (cond.value as num).toDouble();
            switch (cond.operator) {
              case 'gte': if (product.price < val) return false;
              case 'lte': if (product.price > val) return false;
              case 'gt': if (product.price <= val) return false;
              case 'lt': if (product.price >= val) return false;
            }
            break;
          case 'category':
            final val = cond.value.toString();
            switch (cond.operator) {
              case 'eq': if (product.category != val) return false;
              case 'contains': if (!product.category.contains(val)) return false;
            }
            break;
        }
      }
      return true;
    }).toList();
    
    if (mounted) {
      setState(() {
        _affectedProducts = affected;
        _loading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 20, child: LinearProgressIndicator());
    
    if (_affectedProducts.isEmpty) {
      return const Text('暂无匹配商品', style: TextStyle(fontSize: 12, color: Colors.grey));
    }
    
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: _affectedProducts.take(10).map((p) => Chip(
        avatar: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(p.name.isNotEmpty ? p.name[0] : '?', style: const TextStyle(fontSize: 12)),
        ),
        label: Text('${p.name} ¥${p.price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      )).toList()
        ..addAll(_affectedProducts.length > 10 
          ? [Chip(label: Text('+${_affectedProducts.length - 10}件', style: const TextStyle(fontSize: 11)), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)]
          : []),
    );
  }
}

class _RuleDocTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.menu_book),
      title: const Text('查看详细规则文档'),
      trailing: IconButton(
        icon: const Icon(Icons.copy),
        tooltip: '复制文档',
        onPressed: () {
          final text = _getRuleDocText();
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已复制到剪贴板')),
          );
        },
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(_getRuleDocText()),
        ),
      ],
    );
  }
  
  String _getRuleDocText() {
    return '''📋 定价规则编写规范

一、规则结构
每条规则由以下部分组成：
  • 规则名称：简短描述规则用途
  • 优先级：数字越大越先执行
  • 条件(Conditions)：触发规则的前置条件
  • 动作(Action)：满足条件后的价格调整方式

二、条件类型
  • 数量(quantity)：单件商品购买数量
  • 总数量(total_quantity)：购物车所有商品总数量
  • 品牌(brand)：商品品牌名称
  • 单价(price)：商品原价
  • 总金额(total_amount)：购物车总金额

三、条件运算符
  • ≥(gte)：大于等于
  • ≤(lte)：小于等于
  • =(eq)：等于
  • ≠(neq)：不等于
  • >(gt)：大于
  • <(lt)：小于
  • 包含(contains)：字符串包含

四、动作类型
  • 固定价格(fixed_price)：将价格设为指定值
  • 百分比折扣(percent_discount)：按百分比折扣
  • 立减(amount_discount)：每件减免固定金额
  • 买一送一(bogo)：买N件送N/2件

五、作用范围
  • 单品(item)：仅对单个商品生效
  • 所有匹配商品(all_matching)：对所有满足条件的商品生效
  • 整单(cart)：对整个购物车按比例分摊

📝 示例规则

示例1：满20件单价0.8元商品调整为0.75元
  条件：数量 ≥ 20
  动作：固定价格 0.75（单品）

示例2：品牌A全场9折
  条件：品牌 = A
  动作：百分比折扣 10%（所有匹配商品）

示例3：满100元整单减5元
  条件：总金额 ≥ 100
  动作：立减 5（整单）

示例4：买一送一促销
  条件：(无条件或指定品牌)
  动作：买一送一（单品）''';
  }
}
