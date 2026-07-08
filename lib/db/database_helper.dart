import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/pricing_rule.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pos.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        barcode TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        brand TEXT DEFAULT '',
        category TEXT DEFAULT '',
        price REAL NOT NULL DEFAULT 0,
        cost REAL NOT NULL DEFAULT 0,
        stock INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        total REAL NOT NULL,
        original_total REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0,
        payment_method TEXT DEFAULT 'cash',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id TEXT NOT NULL,
        product_id TEXT NOT NULL,
        name TEXT NOT NULL,
        brand TEXT DEFAULT '',
        price REAL NOT NULL,
        original_price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE pricing_rules (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        enabled INTEGER NOT NULL DEFAULT 1,
        priority INTEGER NOT NULL DEFAULT 0,
        rules_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_products_barcode ON products(barcode)');
    await db.execute('CREATE INDEX idx_products_brand ON products(brand)');
    await db.execute('CREATE INDEX idx_sales_date ON sales(created_at)');
    await db.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)');
  }

  // ===== Products =====
  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(String id) async {
    final db = await database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query('products',
        where: 'barcode = ?', whereArgs: [barcode]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<Product?> getProductById(String id) async {
    final db = await database;
    final maps = await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  Future<List<Product>> getAllProducts({String? orderBy}) async {
    final db = await database;
    final maps = await db.query('products',
        orderBy: orderBy ?? 'brand ASC, price ASC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final maps = await db.query('products',
        where: 'name LIKE ? OR barcode LIKE ? OR brand LIKE ?',
        whereArgs: ['%$query%', '%$query%', '%$query%'],
        orderBy: 'brand ASC, price ASC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  // ===== Sales =====
  Future<String> insertSale(Sale sale, List<SaleItem> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('sales', sale.toMap());
      for (final item in items) {
        await txn.insert('sale_items', item.toMap(sale.id));
        // Update stock
        await txn.rawUpdate(
            'UPDATE products SET stock = stock - ? WHERE id = ?',
            [item.quantity, item.productId]);
      }
    });
    return sale.id;
  }

  Future<List<Sale>> getSalesByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final maps = await db.query('sales',
        where: 'created_at >= ? AND created_at <= ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
        orderBy: 'created_at DESC');
    return maps.map((m) => Sale.fromMap(m)).toList();
  }

  Future<List<Sale>> getAllSales() async {
    final db = await database;
    final maps = await db.query('sales', orderBy: 'created_at DESC');
    return maps.map((m) => Sale.fromMap(m)).toList();
  }

  Future<List<SaleItem>> getSaleItems(String saleId) async {
    final db = await database;
    final maps = await db.query('sale_items',
        where: 'sale_id = ?', whereArgs: [saleId]);
    return maps.map((m) => SaleItem.fromMap(m)).toList();
  }

  // ===== Pricing Rules =====
  Future<int> insertRule(PricingRule rule) async {
    final db = await database;
    return await db.insert('pricing_rules', rule.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateRule(PricingRule rule) async {
    final db = await database;
    return await db.update('pricing_rules', rule.toMap(),
        where: 'id = ?', whereArgs: [rule.id]);
  }

  Future<int> deleteRule(String id) async {
    final db = await database;
    return await db.delete('pricing_rules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PricingRule>> getAllRules() async {
    final db = await database;
    final maps = await db.query('pricing_rules', orderBy: 'priority DESC');
    return maps.map((m) => PricingRule.fromMap(m)).toList();
  }

  // ===== Settings =====
  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query('settings',
        where: 'key = ?', whereArgs: [key]);
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ===== Export =====
  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    final products = await db.query('products');
    final sales = await db.query('sales');
    final saleItems = await db.query('sale_items');
    final rules = await db.query('pricing_rules');
    final settings = await db.query('settings');

    return {
      'products': products,
      'sales': sales,
      'sale_items': saleItems,
      'pricing_rules': rules,
      'settings': settings,
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('products');
      await txn.delete('sales');
      await txn.delete('sale_items');
      await txn.delete('pricing_rules');
      await txn.delete('settings');

      if (data['products'] != null) {
        for (final p in (data['products'] as List)) {
          await txn.insert('products', Map<String, dynamic>.from(p));
        }
      }
      if (data['sales'] != null) {
        for (final s in (data['sales'] as List)) {
          await txn.insert('sales', Map<String, dynamic>.from(s));
        }
      }
      if (data['sale_items'] != null) {
        for (final si in (data['sale_items'] as List)) {
          await txn.insert('sale_items', Map<String, dynamic>.from(si));
        }
      }
      if (data['pricing_rules'] != null) {
        for (final r in (data['pricing_rules'] as List)) {
          await txn.insert('pricing_rules', Map<String, dynamic>.from(r));
        }
      }
      if (data['settings'] != null) {
        for (final s in (data['settings'] as List)) {
          await txn.insert('settings', Map<String, dynamic>.from(s));
        }
      }
    });
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'pos.db');
  }
}
