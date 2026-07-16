import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../db/database_helper.dart';
import '../models/product.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _loading = false;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('数据管理')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ====== 商品导出 ======
          _SectionHeader(title: '商品导出', icon: Icons.upload_file),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ExportButton(
                          icon: Icons.code,
                          label: '导出JSON',
                          color: Colors.blue,
                          onPressed: _loading ? null : _exportProductsJson,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExportButton(
                          icon: Icons.table_chart,
                          label: '导出CSV',
                          color: Colors.green,
                          onPressed: _loading ? null : _exportCSV,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ====== 商品导入 ======
          _SectionHeader(title: '商品导入', icon: Icons.download),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ImportButton(
                    icon: Icons.file_open,
                    label: '从本地文件导入',
                    subtitle: '支持 JSON 格式',
                    onPressed: _loading ? null : _importFromLocal,
                  ),
                  const Divider(height: 24),
                  _ImportButton(
                    icon: Icons.link,
                    label: '从网络导入',
                    subtitle: '输入URL下载商品数据',
                    onPressed: _loading ? null : _importFromNetwork,
                  ),
                  const Divider(height: 24),
                  _ImportButton(
                    icon: Icons.content_paste,
                    label: '从剪贴板导入',
                    subtitle: '粘贴JSON文本',
                    onPressed: _loading ? null : _importFromClipboard,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ====== 全量备份 ======
          _SectionHeader(title: '全量备份', icon: Icons.backup),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ExportButton(
                          icon: Icons.backup,
                          label: '备份全部',
                          color: Colors.orange,
                          onPressed: _loading ? null : _backupAll,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExportButton(
                          icon: Icons.restore,
                          label: '恢复备份',
                          color: Colors.purple,
                          onPressed: _loading ? null : _restoreAll,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '备份包含商品、交易记录、定价规则和设置',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status
          if (_status != null)
            Card(
              color: _status!.contains('成功')
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _status!.contains('成功')
                          ? Icons.check_circle
                          : Icons.error,
                      color: _status!.contains('成功')
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_status!)),
                  ],
                ),
              ),
            ),
          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 16),

          // Info
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('说明',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• JSON格式包含商品完整信息，推荐使用'),
                  const Text('• CSV格式可用Excel打开，但不含成本字段'),
                  const Text('• 网络导入支持直接粘贴URL链接'),
                  const Text('• 导入商品会合并到现有数据，不会覆盖'),
                  const Text('• 全量备份恢复会覆盖当前所有数据'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====== 导出商品JSON ======
  Future<void> _exportProductsJson() async {
    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final products = await db.getAllProducts();

      final productsJson = products.map((p) => {
        'barcode': p.barcode,
        'name': p.name,
        'brand': p.brand,
        'category': p.category,
        'price': p.price,
      }).toList();

      final jsonStr = const JsonEncoder.withIndent('  ').convert({
        'version': '1.0',
        'export_time': DateTime.now().toIso8601String(),
        'count': products.length,
        'products': productsJson,
      });

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/products_$timestamp.json');
      await file.writeAsString(jsonStr);

      setState(() {
        _status = '导出成功！\n文件: ${file.path}\n共 ${products.length} 件商品';
      });
    } catch (e) {
      setState(() => _status = '导出失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ====== 导出CSV ======
  Future<void> _exportCSV() async {
    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final products = await db.getAllProducts();

      final buffer = StringBuffer();
      buffer.writeln('条码,名称,品牌,分类,售价');
      for (final p in products) {
        buffer.writeln(
            '${_escapeCsv(p.barcode)},${_escapeCsv(p.name)},${_escapeCsv(p.brand)},${_escapeCsv(p.category)},${p.price}');
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/products_$timestamp.csv');
      await file.writeAsString(buffer.toString());

      setState(() {
        _status = '导出成功！\n文件: ${file.path}\n共 ${products.length} 件商品';
      });
    } catch (e) {
      setState(() => _status = '导出失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ====== 从本地文件导入 ======
  Future<void> _importFromLocal() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      final file = File(result.files.first.path!);
      final jsonStr = await file.readAsString();
      await _processImportData(jsonStr);
    } catch (e) {
      setState(() => _status = '导入失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ====== 从网络导入 ======
  Future<void> _importFromNetwork() async {
    final urlController = TextEditingController();
    
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('网络导入'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('输入商品数据的URL地址：'),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                hintText: 'https://example.com/products.json',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null) {
                  urlController.text = data!.text!;
                }
              },
              icon: const Icon(Icons.content_paste, size: 16),
              label: const Text('从剪贴板粘贴'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, urlController.text.trim()),
            child: const Text('导入'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;

    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        await _processImportData(response.body);
      } else {
        setState(() {
          _status = '下载失败: HTTP ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() => _status = '网络请求失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ====== 从剪贴板导入 ======
  Future<void> _importFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text == null || data!.text!.isEmpty) {
      setState(() => _status = '剪贴板为空');
      return;
    }

    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      await _processImportData(data.text!);
    } catch (e) {
      setState(() => _status = '导入失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ====== 处理导入数据 ======
  Future<void> _processImportData(String jsonStr) async {
    final data = jsonDecode(jsonStr);
    
    List<dynamic> productsList;
    
    // 兼容多种格式
    if (data is Map<String, dynamic>) {
      // 格式1: { products: [...] }
      if (data.containsKey('products')) {
        productsList = data['products'] as List<dynamic>;
      }
      // 格式2: 直接是单个商品
      else if (data.containsKey('barcode') || data.containsKey('name')) {
        productsList = [data];
      } else {
        throw Exception('不支持的数据格式');
      }
    } else if (data is List<dynamic>) {
      // 格式3: 直接是数组
      productsList = data;
    } else {
      throw Exception('不支持的数据格式');
    }

    final db = DatabaseHelper.instance;
    int imported = 0;
    int skipped = 0;

    for (final item in productsList) {
      final map = item as Map<String, dynamic>;
      final barcode = map['barcode']?.toString() ?? '';
      final name = map['name']?.toString() ?? '';

      if (barcode.isEmpty || name.isEmpty) {
        skipped++;
        continue;
      }

      // 检查是否已存在
      final existing = await db.getProductByBarcode(barcode);
      if (existing != null) {
        skipped++;
        continue;
      }

      // 创建商品
      final product = Product(
        barcode: barcode,
        name: name,
        brand: map['brand']?.toString() ?? '',
        category: map['category']?.toString() ?? '',
        price: (map['price'] as num?)?.toDouble() ?? 0,
      );

      await db.insertProduct(product);
      imported++;
    }

    setState(() {
      _status = '导入完成！\n成功导入: $imported 件\n跳过: $skipped 件';
    });
  }

  // ====== 全量备份 ======
  Future<void> _backupAll() async {
    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final data = await db.exportAllData();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/backup_$timestamp.json');
      await file.writeAsString(jsonStr);

      setState(() {
        _status = '备份成功！\n文件: ${file.path}';
      });
    } catch (e) {
      setState(() => _status = '备份失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ====== 恢复备份 ======
  Future<void> _restoreAll() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Text('恢复备份将覆盖当前所有数据，确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      final file = File(result.files.first.path!);
      final jsonStr = await file.readAsString();
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final db = DatabaseHelper.instance;
      await db.importAllData(data);

      setState(() => _status = '恢复成功！已导入所有数据');
    } catch (e) {
      setState(() => _status = '恢复失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

// ====== 组件 ======

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(color: color.withOpacity(0.5)),
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onPressed;

  const _ImportButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}
