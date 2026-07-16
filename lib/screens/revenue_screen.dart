import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/sale.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  String _period = 'day';
  List<Sale> _sales = [];
  bool _loading = true;

  double _totalRevenue = 0;
  double _totalDiscount = 0;
  int _totalTransactions = 0;
  int _totalItems = 0;
  Map<String, double> _dailyRevenue = {};
  Map<String, double> _brandRevenue = {};
  Map<String, int> _brandQuantity = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    final now = DateTime.now();

    DateTime start;
    switch (_period) {
      case 'day':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'week':
        start = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        start = DateTime(now.year, now.month - 1, now.day);
        break;
      case 'year':
        start = DateTime(now.year - 1, now.month, now.day);
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
    }

    final sales = await db.getSalesByDateRange(start, now);
    double revenue = 0;
    double discount = 0;
    int items = 0;
    final dailyRev = <String, double>{};
    final brandRev = <String, double>{};
    final brandQty = <String, int>{};

    for (final sale in sales) {
      revenue += sale.total;
      discount += sale.discount;
      final dateKey = DateFormat('MM/dd').format(DateTime.parse(sale.createdAt));
      dailyRev[dateKey] = (dailyRev[dateKey] ?? 0) + sale.total;

      final saleItems = await db.getSaleItems(sale.id);
      for (final item in saleItems) {
        items += item.quantity;
        brandRev[item.brand.isEmpty ? '未分类' : item.brand] =
            (brandRev[item.brand.isEmpty ? '未分类' : item.brand] ?? 0) + item.subtotal;
        brandQty[item.brand.isEmpty ? '未分类' : item.brand] =
            (brandQty[item.brand.isEmpty ? '未分类' : item.brand] ?? 0) + item.quantity;
      }
    }

    setState(() {
      _sales = sales;
      _totalRevenue = revenue;
      _totalDiscount = discount;
      _totalTransactions = sales.length;
      _totalItems = items;
      _dailyRevenue = dailyRev;
      _brandRevenue = brandRev;
      _brandQuantity = brandQty;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('收益分析')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Period selector
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'day', label: Text('今日')),
                      ButtonSegment(value: 'week', label: Text('本周')),
                      ButtonSegment(value: 'month', label: Text('本月')),
                      ButtonSegment(value: 'year', label: Text('今年')),
                    ],
                    selected: {_period},
                    onSelectionChanged: (v) {
                      setState(() => _period = v.first);
                      _loadData();
                    },
                  ),
                  const SizedBox(height: 20),

                  // Stats cards
                  _buildStatsGrid(theme),
                  const SizedBox(height: 24),

                  // Revenue chart
                  if (_dailyRevenue.isNotEmpty) ...[
                    Text('收入趋势',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: _buildRevenueChart(theme),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Brand breakdown
                  if (_brandRevenue.isNotEmpty) ...[
                    Text('品牌分布',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 200,
                      child: _buildBrandPieChart(theme),
                    ),
                    const SizedBox(height: 12),
                    ..._buildBrandList(theme),
                    const SizedBox(height: 24),
                  ],

                  // Recent transactions
                  Text('最近交易',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ..._sales.take(10).map((s) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: const Icon(Icons.receipt, size: 20),
                        ),
                        title: Text('¥${s.total.toStringAsFixed(2)}',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            DateFormat('yyyy-MM-dd HH:mm')
                                .format(DateTime.parse(s.createdAt))),
                        trailing: s.discount > 0
                            ? Text('省¥${s.discount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Colors.green, fontSize: 12))
                            : null,
                      )),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _StatCard(
          icon: Icons.attach_money,
          label: '总收入',
          value: '¥${_totalRevenue.toStringAsFixed(2)}',
          color: Colors.blue,
        ),
        _StatCard(
          icon: Icons.receipt_long,
          label: '交易数',
          value: '$_totalTransactions',
          color: Colors.orange,
        ),
        _StatCard(
          icon: Icons.shopping_bag,
          label: '商品数',
          value: '$_totalItems',
          color: Colors.green,
        ),
        _StatCard(
          icon: Icons.discount,
          label: '优惠总额',
          value: '¥${_totalDiscount.toStringAsFixed(2)}',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildRevenueChart(ThemeData theme) {
    final entries = _dailyRevenue.entries.toList();
    if (entries.isEmpty) return const SizedBox();

    final maxY = entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '¥${rod.toY.toStringAsFixed(2)}',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < entries.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(entries[idx].key,
                        style: const TextStyle(fontSize: 10)),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: entries.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                color: theme.colorScheme.primary,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBrandPieChart(ThemeData theme) {
    final entries = _brandRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    return PieChart(
      PieChartData(
        sections: entries.asMap().entries.map((e) {
          return PieChartSectionData(
            value: e.value.value,
            title: '${(e.value.value / _totalRevenue * 100).toStringAsFixed(0)}%',
            color: colors[e.key % colors.length],
            radius: 80,
            titleStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          );
        }).toList(),
        sectionsSpace: 2,
        centerSpaceRadius: 0,
      ),
    );
  }

  List<Widget> _buildBrandList(ThemeData theme) {
    final entries = _brandRevenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange,
      Colors.purple, Colors.teal, Colors.pink, Colors.amber,
    ];

    return entries.asMap().entries.map((e) {
      final color = colors[e.key % colors.length];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(width: 12, height: 12, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(e.value.key)),
            Text('¥${e.value.value.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Text('${_brandQuantity[e.value.key] ?? 0}件',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          ],
        ),
      );
    }).toList();
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 4),
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
