import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../db/database_helper.dart';
import '../models/product.dart';
import '../models/pricing_rule.dart' as pr;
import '../services/cart_manager.dart';
import 'cart_screen.dart';
import 'product_form_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _processing = false;
  String? _lastBarcode;
  DateTime _lastScanTime = DateTime(2000);
  List<pr.CartItem> _scannedItems = [];
  
  // 扫描线动画
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _scannedItems.fold<double>(
      0,
      (sum, item) => sum + item.price * item.quantity,
    );

    return Scaffold(
      body: Column(
        children: [
          // 摄像头扫描区域
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _cameraController,
                  onDetect: _onDetect,
                ),
                // 扫描框
                Center(
                  child: Container(
                    width: 280,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // 扫描线动画
                Center(
                  child: ClipRect(
                    child: SizedBox(
                      width: 280,
                      height: 200,
                      child: AnimatedBuilder(
                        animation: _animation,
                        builder: (context, child) {
                          return Stack(
                            children: [
                              Positioned(
                                top: _animation.value * 196,
                                child: Container(
                                  width: 280,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        theme.colorScheme.primary,
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // 提示文字
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Text(
                    '将商品条码放入框内',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
                // 闪光灯和切换摄像头
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 8,
                  child: Column(
                    children: [
                      IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: _cameraController.torchState,
                          builder: (context, state, child) {
                            return Icon(
                              state == TorchState.on
                                  ? Icons.flash_on
                                  : Icons.flash_off,
                              color: Colors.white,
                            );
                          },
                        ),
                        onPressed: () => _cameraController.toggleTorch(),
                      ),
                      IconButton(
                        icon: ValueListenableBuilder(
                          valueListenable: _cameraController.cameraFacingState,
                          builder: (context, state, child) {
                            return Icon(
                              state == CameraFacing.front
                                  ? Icons.camera_front
                                  : Icons.camera_rear,
                              color: Colors.white,
                            );
                          },
                        ),
                        onPressed: () => _cameraController.switchCamera(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 商品列表区域
          Expanded(
            flex: 5,
            child: Container(
              color: theme.colorScheme.surface,
              child: Column(
                children: [
                  // 标题栏
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Text(
                          '已扫描商品',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_scannedItems.length}件',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (_scannedItems.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          TextButton.icon(
                            onPressed: _clearAll,
                            icon: const Icon(Icons.delete_sweep, size: 18),
                            label: const Text('清空'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // 商品列表
                  Expanded(
                    child: _scannedItems.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner,
                                  size: 64,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '扫描商品条码',
                                  style: TextStyle(
                                    color: theme.colorScheme.outline,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _scannedItems.length,
                            itemBuilder: (ctx, i) {
                              final item = _scannedItems[i];
                              return _buildCartItem(item, i);
                            },
                          ),
                  ),
                  
                  // 底部结算栏
                  if (_scannedItems.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '合计',
                                style: theme.textTheme.bodySmall,
                              ),
                              Text(
                                '¥${total.toStringAsFixed(2)}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _checkout,
                            icon: const Icon(Icons.shopping_cart_checkout),
                            label: const Text('去结算'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(pr.CartItem item, int index) {
    final theme = Theme.of(context);
    
    return Dismissible(
      key: Key(item.productId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        setState(() {
          _scannedItems.removeAt(index);
        });
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 商品信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (item.brand.isNotEmpty)
                      Text(
                        item.brand,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              // 数量控制
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: () => _updateQuantity(index, -1),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    Text(
                      '${item.quantity}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => _updateQuantity(index, 1),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // 价格
              Text(
                '¥${(item.price * item.quantity).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    // 限流处理：2秒内不重复扫描
    final now = DateTime.now();
    if (now.difference(_lastScanTime).inMilliseconds < 2000) return;
    if (_processing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final code = barcode!.rawValue!;
    if (code == _lastBarcode) return;

    _lastScanTime = now;
    setState(() {
      _processing = true;
      _lastBarcode = code;
    });

    try {
      // 检查是否已存在
      final existingIndex = _scannedItems.indexWhere(
        (item) => item.barcode == code,
      );
      
      if (existingIndex >= 0) {
        // 已存在则增加数量
        setState(() {
          _scannedItems[existingIndex].quantity++;
        });
        _showSnackBar('已添加数量: ${_scannedItems[existingIndex].name}');
      } else {
        // 查询数据库
        final db = DatabaseHelper.instance;
        final product = await db.getProductByBarcode(code);

        if (!mounted) return;

        if (product != null) {
          // 商品存在，添加到列表
          setState(() {
            _scannedItems.add(pr.CartItem(
              productId: product.id,
              barcode: product.barcode,
              name: product.name,
              brand: product.brand,
              price: product.price,
              quantity: 1,
            ));
          });
          _showSnackBar('已添加: ${product.name}');
        } else {
          // 商品不存在，提示添加
          _showAddProductDialog(code);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAddProductDialog(String barcode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('商品未找到'),
        content: Text('条码: $barcode\n\n是否添加该商品？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductFormScreen(barcode: barcode),
                ),
              );
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _updateQuantity(int index, int change) {
    setState(() {
      final newQuantity = _scannedItems[index].quantity + change;
      if (newQuantity <= 0) {
        _scannedItems.removeAt(index);
      } else {
        _scannedItems[index].quantity = newQuantity;
      }
    });
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空商品'),
        content: const Text('确定要清空所有已扫描的商品吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _scannedItems.clear());
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  void _checkout() {
    // 将扫描的商品添加到购物车
    final cart = CartManager.instance;
    cart.clear();
    for (final item in _scannedItems) {
      for (int i = 0; i < item.quantity; i++) {
        cart.addItem(pr.CartItem(
          productId: item.productId,
          barcode: item.barcode,
          name: item.name,
          brand: item.brand,
          price: item.price,
        ));
      }
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartScreen()),
    ).then((_) {
      // 返回后清空扫描列表
      setState(() => _scannedItems.clear());
    });
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
