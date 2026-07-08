import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../db/database_helper.dart';
import '../models/product.dart';
import '../models/pricing_rule.dart';
import 'cart_screen.dart';
import 'product_form_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _processing = false;
  String? _lastBarcode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描条码'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _cameraController.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
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
                );
              },
            ),
            onPressed: () => _cameraController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: _processing
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('处理中...'),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_scanner, size: 32),
                          const SizedBox(height: 8),
                          const Text('将条码对准框内自动扫描'),
                          if (_lastBarcode != null) ...[
                            const SizedBox(height: 4),
                            Text('上次扫描: $_lastBarcode',
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12)),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_processing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final code = barcode!.rawValue!;
    if (code == _lastBarcode) return;

    setState(() {
      _processing = true;
      _lastBarcode = code;
    });

    try {
      final db = DatabaseHelper.instance;
      final product = await db.getProductByBarcode(code);

      if (!mounted) return;

      if (product != null) {
        // Product exists, add to cart
        _showProductFound(product);
      } else {
        // Product not found, offer to create
        _showProductNotFound(code);
      }
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  void _showProductFound(Product product) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            Text(product.name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(product.brand, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text('¥${product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue)),
            Text('库存: ${product.stock}'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ProductFormScreen(product: product)));
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('编辑'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _addToCart(product);
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('加入购物车'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // Resume scanning after sheet closes
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _lastBarcode = null);
      });
    });
  }

  void _showProductNotFound(String barcode) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: Colors.orange, size: 48),
            const SizedBox(height: 12),
            const Text('商品未找到',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text('条码: $barcode'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ProductFormScreen(barcode: barcode)));
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('添加商品'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _lastBarcode = null);
      });
    });
  }

  void _addToCart(Product product) {
    CartManager.instance.addItem(CartItem(
      productId: product.id,
      barcode: product.barcode,
      name: product.name,
      brand: product.brand,
      price: product.price,
      cost: product.cost,
    ));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已添加: ${product.name}'),
        action: SnackBarAction(
          label: '查看购物车',
          onPressed: () {
            Navigator.push(
                context, MaterialPageRoute(builder: (_) => const CartScreen()));
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}
