import 'package:flutter/material.dart';
import 'rule_editor_screen.dart';
import 'backup_screen.dart';
import 'password_screen.dart';
import '../db/database_helper.dart';
import '../models/pricing_rule.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<PricingRule> _rules = [];
  bool _hasPassword = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper.instance;
    final rules = await db.getAllRules();
    final pwd = await db.getSetting('app_password');
    setState(() {
      _rules = rules;
      _hasPassword = pwd != null && pwd.isNotEmpty;
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

          // Security
          _SectionHeader(title: '安全', icon: Icons.security),
          SwitchListTile(
            title: const Text('应用密码'),
            subtitle: Text(_hasPassword ? '已启用' : '未设置'),
            value: _hasPassword,
            onChanged: (v) async {
              if (v) {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => PasswordScreen(
                              onAuthenticated: () => Navigator.pop(context),
                              isSetup: true,
                            )));
              } else {
                await DatabaseHelper.instance.setSetting('app_password', '');
              }
              _loadData();
            },
          ),

          const Divider(),

          // Backup
          _SectionHeader(title: '数据', icon: Icons.storage),
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('备份与恢复'),
            subtitle: const Text('导出/导入数据备份'),
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
    return ListTile(
      leading: Switch(value: rule.enabled, onChanged: onToggle),
      title: Text(rule.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rule.action.displayText, style: const TextStyle(fontSize: 12)),
          if (rule.conditions.isNotEmpty)
            Text(
                rule.conditions.map((c) => c.displayText).join(' 且 '),
                style: TextStyle(
                    fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
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
    );
  }
}

class _RuleDocTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.menu_book),
      title: const Text('查看详细规则文档'),
      children: const [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📋 定价规则编写规范', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 12),
              Text('一、规则结构', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('每条规则由以下部分组成：'),
              Text('  • 规则名称：简短描述规则用途'),
              Text('  • 优先级：数字越大越先执行'),
              Text('  • 条件(Conditions)：触发规则的前置条件'),
              Text('  • 动作(Action)：满足条件后的价格调整方式'),
              SizedBox(height: 8),
              Text('二、条件类型', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('  • 数量(quantity)：单件商品购买数量'),
              Text('  • 总数量(total_quantity)：购物车所有商品总数量'),
              Text('  • 品牌(brand)：商品品牌名称'),
              Text('  • 单价(price)：商品原价'),
              Text('  • 总金额(total_amount)：购物车总金额'),
              SizedBox(height: 8),
              Text('三、条件运算符', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('  • ≥(gte)：大于等于'),
              Text('  • ≤(lte)：小于等于'),
              Text('  • =(eq)：等于'),
              Text('  • ≠(neq)：不等于'),
              Text('  • >(gt)：大于'),
              Text('  • <(lt)：小于'),
              Text('  • 包含(contains)：字符串包含'),
              SizedBox(height: 8),
              Text('四、动作类型', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('  • 固定价格(fixed_price)：将价格设为指定值'),
              Text('  • 百分比折扣(percent_discount)：按百分比折扣'),
              Text('  • 立减(amount_discount)：每件减免固定金额'),
              Text('  • 买一送一(bogo)：买N件送N/2件'),
              SizedBox(height: 8),
              Text('五、作用范围', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('  • 单品(item)：仅对单个商品生效'),
              Text('  • 所有匹配商品(all_matching)：对所有满足条件的商品生效'),
              Text('  • 整单(cart)：对整个购物车按比例分摊'),
              SizedBox(height: 12),
              Text('📝 示例规则', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 8),
              Text('示例1：满20件单价0.8元商品调整为0.75元'),
              Text('  条件：数量 ≥ 20'),
              Text('  动作：固定价格 0.75（单品）'),
              SizedBox(height: 8),
              Text('示例2：品牌A全场9折'),
              Text('  条件：品牌 = A'),
              Text('  动作：百分比折扣 10%（所有匹配商品）'),
              SizedBox(height: 8),
              Text('示例3：满100元整单减5元'),
              Text('  条件：总金额 ≥ 100'),
              Text('  动作：立减 5（整单）'),
              SizedBox(height: 8),
              Text('示例4：买一送一促销'),
              Text('  条件：(无条件或指定品牌)'),
              Text('  动作：买一送一（单品）'),
            ],
          ),
        ),
      ],
    );
  }
}
