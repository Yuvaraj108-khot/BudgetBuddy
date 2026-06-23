import 'package:flutter/material.dart';
import '../services/local_repository.dart';

class DashboardProvider extends ChangeNotifier {
  final LocalRepository _repository = LocalRepository();

  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic> _balance = {};
  Map<String, dynamic> _prediction = {};
  Map<String, dynamic> _discipline = {};
  Map<String, dynamic> _insights = {};
  List<dynamic> _merchants = [];
  List<dynamic> _categories = [];
  List<dynamic> _recentTransactions = [];

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Map<String, dynamic> get balance => _balance;
  Map<String, dynamic> get prediction => _prediction;
  Map<String, dynamic> get discipline => _discipline;
  Map<String, dynamic> get insights => _insights;
  List<dynamic> get merchants => _merchants;
  List<dynamic> get categories => _categories;
  List<dynamic> get recentTransactions => _recentTransactions;

  Future<void> fetchDashboard({int? month, int? year}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final m = month ?? now.month;
      final y = year ?? now.year;

      final totalIncome = await _repository.getTotalIncome(m, y);
      final totalExpense = await _repository.getTotalExpense(m, y);
      final balanceAmt = totalIncome - totalExpense;

      _balance = {
        'total_income': totalIncome,
        'total_expense': totalExpense,
        'net_balance': balanceAmt,
      };

      // Mock prediction & discipline for now (offline)
      _prediction = {'predicted_expense': totalExpense * 1.1};
      _discipline = {'score': balanceAmt > 0 ? 80 : 40};
      _insights = {};
      
      final catExp = await _repository.getExpensesByCategory(m, y);
      _categories = catExp.entries.map((e) => {'name': e.key, 'amount': e.value, 'percentage': totalExpense > 0 ? ((e.value / totalExpense) * 100).round() : 0}).toList();

      final txs = await _repository.getTransactionsByMonth(m, y);
      _recentTransactions = txs.take(5).map((t) => t.toJson()).toList();

    } catch (e) {
      _errorMessage = 'Failed to load dashboard statistics locally';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateBudget(int month, int year, double pocketMoney) async {
    _isLoading = true;
    notifyListeners();

    try {
      // In a full implementation, you would save this to the local 'budgets' or 'settings' table.
      // For now, we simulate success.
      await Future.delayed(const Duration(milliseconds: 300));
      await fetchDashboard(month: month, year: year);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update budget';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
