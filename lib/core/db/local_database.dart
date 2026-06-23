import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();

  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('budgetbuddy.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT';
    const integerType = 'INTEGER NOT NULL';
    const integerNullableType = 'INTEGER';
    const realType = 'REAL NOT NULL';
    const realNullableType = 'REAL';

    await db.execute('''
CREATE TABLE transactions (
  id $idType,
  amount $realType,
  type $textType,
  merchant_or_sender $textType,
  category $textType,
  source $textType,
  note $textNullableType,
  transaction_date $textType,
  reference_number $textNullableType,
  raw_sms $textNullableType
)
''');

    await db.execute('''
CREATE TABLE categories (
  id $idType,
  name $textType,
  type $textType,
  icon $textNullableType,
  color $textNullableType
)
''');

    await db.execute('''
CREATE TABLE budgets (
  id $idType,
  category_id $integerType,
  amount $realType,
  month $integerType,
  year $integerType
)
''');

    await db.execute('''
CREATE TABLE settings (
  key $textType PRIMARY KEY,
  value $textType
)
''');

    await db.execute('''
CREATE TABLE security_settings (
  id $idType,
  pin_hash $textNullableType,
  biometric_enabled $integerNullableType
)
''');

    // Pre-populate some default categories if needed
    await _seedCategories(db);
  }

  Future<void> _seedCategories(Database db) async {
    final defaultExpenseCategories = [
      'Food & Dining',
      'Transport',
      'Shopping',
      'Education',
      'Entertainment',
      'Health',
      'Utilities'
    ];
    for (final cat in defaultExpenseCategories) {
      await db.insert('categories', {'name': cat, 'type': 'expense'});
    }
    await db.insert('categories', {'name': 'Salary', 'type': 'income'});
    await db.insert('categories', {'name': 'Savings/Transfer', 'type': 'income'});
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
