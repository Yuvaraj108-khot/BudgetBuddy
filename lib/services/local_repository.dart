import 'package:sqflite/sqflite.dart';
import '../core/db/local_database.dart';
import '../../models/transaction.dart' as model;

class LocalRepository {
  // TRANSACTIONS
  Future<model.Transaction> insertTransaction(model.Transaction transaction) async {
    final db = await LocalDatabase.instance.database;
    final id = await db.insert('transactions', transaction.toJson());
    return transaction.copyWith(id: id);
  }

  Future<List<model.Transaction>> getTransactionsByMonth(int month, int year) async {
    final db = await LocalDatabase.instance.database;
    final String monthStr = month.toString().padLeft(2, '0');
    final String yearStr = year.toString();

    final maps = await db.query(
      'transactions',
      where: "strftime('%m', transaction_date) = ? AND strftime('%Y', transaction_date) = ?",
      whereArgs: [monthStr, yearStr],
      orderBy: 'transaction_date DESC',
    );

    return maps.map((map) => model.Transaction.fromJson(map)).toList();
  }

  Future<int> deleteTransaction(int id) async {
    final db = await LocalDatabase.instance.database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // DASHBOARD AGGREGATION
  Future<double> getTotalIncome(int month, int year) async {
    final db = await LocalDatabase.instance.database;
    final String monthStr = month.toString().padLeft(2, '0');
    final String yearStr = year.toString();

    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'income' AND strftime('%m', transaction_date) = ? AND strftime('%Y', transaction_date) = ?",
      [monthStr, yearStr]
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<double> getTotalExpense(int month, int year) async {
    final db = await LocalDatabase.instance.database;
    final String monthStr = month.toString().padLeft(2, '0');
    final String yearStr = year.toString();

    final result = await db.rawQuery(
      "SELECT SUM(amount) as total FROM transactions WHERE type = 'expense' AND strftime('%m', transaction_date) = ? AND strftime('%Y', transaction_date) = ?",
      [monthStr, yearStr]
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  Future<Map<String, double>> getExpensesByCategory(int month, int year) async {
    final db = await LocalDatabase.instance.database;
    final String monthStr = month.toString().padLeft(2, '0');
    final String yearStr = year.toString();

    final result = await db.rawQuery(
      "SELECT category, SUM(amount) as total FROM transactions WHERE type = 'expense' AND strftime('%m', transaction_date) = ? AND strftime('%Y', transaction_date) = ? GROUP BY category",
      [monthStr, yearStr]
    );

    final Map<String, double> expenses = {};
    for (var row in result) {
      expenses[row['category'] as String] = (row['total'] as num).toDouble();
    }
    return expenses;
  }

  // SECURITY (PIN)
  Future<void> savePinHash(String hash) async {
    final db = await LocalDatabase.instance.database;
    await db.delete('security_settings'); // Only keep 1 active row
    await db.insert('security_settings', {
      'pin_hash': hash,
      'biometric_enabled': 0,
    });
  }

  Future<String?> getPinHash() async {
    final db = await LocalDatabase.instance.database;
    final result = await db.query('security_settings', limit: 1);
    if (result.isNotEmpty) {
      return result.first['pin_hash'] as String?;
    }
    return null;
  }

  Future<void> removePin() async {
    final db = await LocalDatabase.instance.database;
    await db.delete('security_settings');
  }
}
