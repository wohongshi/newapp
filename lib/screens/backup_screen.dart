import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _loading = false;
  String? _lastBackupPath;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('备份与恢复')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Backup section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.cloud_upload_outlined,
                      size: 48, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  const Text('备份数据',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('将所有商品、销售记录、规则导出为JSON文件',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loading ? null : _backup,
                    icon: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.backup),
                    label: const Text('立即备份'),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Restore section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.cloud_download_outlined,
                      size: 48, color: theme.colorScheme.tertiary),
                  const SizedBox(height: 12),
                  const Text('恢复数据',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('从备份文件恢复数据（将覆盖当前数据）',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _restore,
                    icon: const Icon(Icons.restore),
                    label: const Text('选择备份文件恢复'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48)),
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
          const SizedBox(height: 16),

          // Export CSV
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.table_chart_outlined,
                      size: 48, color: theme.colorScheme.secondary),
                  const SizedBox(height: 12),
                  const Text('导出CSV',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('将商品数据导出为CSV表格文件',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _exportCSV,
                    icon: const Icon(Icons.download),
                    label: const Text('导出商品CSV'),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48)),
                  ),
                ],
              ),
            ),
          ),
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
                      const Text('备份说明',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('• 备份文件包含所有商品、交易记录和定价规则'),
                  const Text('• 备份文件为JSON格式，可直接查看'),
                  const Text('• 恢复数据将覆盖当前所有数据'),
                  const Text('• 建议定期备份以防数据丢失'),
                  const Text('• 所有数据纯本地存储，不上传任何服务器'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _backup() async {
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
        _status = '备份成功！文件: ${file.path}';
        _lastBackupPath = file.path;
      });
    } catch (e) {
      setState(() => _status = '备份失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认恢复'),
        content: const Text('恢复数据将覆盖当前所有数据，确定继续吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认恢复')),
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

      setState(() => _status = '恢复成功！已导入数据');
    } catch (e) {
      setState(() => _status = '恢复失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _exportCSV() async {
    setState(() {
      _loading = true;
      _status = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final products = await db.getAllProducts();

      final buffer = StringBuffer();
      buffer.writeln('ID,条码,名称,品牌,分类,售价,成本,库存');
      for (final p in products) {
        buffer.writeln(
            '${p.id},${p.barcode},${p.name},${p.brand},${p.category},${p.price},${p.cost},${p.stock}');
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/products_$timestamp.csv');
      await file.writeAsString(buffer.toString());

      setState(() => _status = 'CSV导出成功！文件: ${file.path}（共${products.length}件商品）');
    } catch (e) {
      setState(() => _status = '导出失败: $e');
    } finally {
      setState(() => _loading = false);
    }
  }
}
