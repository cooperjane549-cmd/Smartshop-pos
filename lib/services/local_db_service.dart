import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDbService {
  static final LocalDbService instance = LocalDbService._init();
  static Database? _database;

  LocalDbService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('smartshop.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        buyingPrice REAL NOT NULL,
        sellingPrice REAL NOT NULL,
        stockQuantity INTEGER NOT NULL,
        lowStockAlertThreshold INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        totalAmount REAL NOT NULL,
        paymentMethod TEXT NOT NULL,
        isPaid INTEGER NOT NULL,
        items TEXT NOT NULL,
        customerName TEXT,
        customerPhone TEXT,
        dueDate TEXT,
        mpesaCode TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> insertProduct(Map<String, dynamic> productMap) async {
    final db = await instance.database;
    await db.insert('products', productMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getProducts() async {
    final db = await instance.database;
    return await db.query('products');
  }

  Future<void> updateStock(String id, int newStock) async {
    final db = await instance.database;
    await db.update(
      'products',
      {'stockQuantity': newStock},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteProduct(String id) async {
    final db = await instance.database;
    await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertSale(Map<String, dynamic> saleMap) async {
    final db = await instance.database;
    await db.insert('sales', saleMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getSales() async {
    final db = await instance.database;
    return await db.query('sales', orderBy: 'createdAt DESC');
  }

  Future<void> markSalePaid(String saleId, String mpesaCode) async {
    final db = await instance.database;
    await db.update(
      'sales',
      {'isPaid': 1, 'mpesaCode': mpesaCode},
      where: 'id = ?',
      whereArgs: [saleId],
    );
  }
}
