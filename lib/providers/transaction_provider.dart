import 'package:flutter/material.dart';
import '../services/local_repository.dart';
import '../models/transaction.dart';
import '../core/api/api_client.dart'; // Retained for AI parsing endpoints

class TransactionProvider extends ChangeNotifier {
  final LocalRepository _repository = LocalRepository();
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchTransactions({int? month, int? year}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final m = month ?? now.month;
      final y = year ?? now.year;

      _transactions = await _repository.getTransactionsByMonth(m, y);
    } catch (e) {
      _errorMessage = 'Failed to load transactions';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addTransaction({
    required double amount,
    required String type,
    required String merchantOrSender,
    required String category,
    String? source,
    String? note,
    DateTime? transactionDate,
    String? referenceNumber,
    String? rawSms,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newTx = Transaction(
        amount: amount,
        type: type,
        merchantOrSender: merchantOrSender,
        category: category,
        source: source ?? 'manual',
        note: note,
        transactionDate: transactionDate ?? DateTime.now(),
        referenceNumber: referenceNumber,
        rawSms: rawSms,
      );

      final insertedTx = await _repository.insertTransaction(newTx);
      _transactions.insert(0, insertedTx);
      
      // Sort by date descending
      _transactions.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
      
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add transaction';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteTransaction(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deletedCount = await _repository.deleteTransaction(id);
      if (deletedCount > 0) {
        _transactions.removeWhere((tx) => tx.id == id);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Failed to delete transaction';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Parses an SMS locally or via tiny backend AI proxy
  Future<Map<String, dynamic>?> parseRawSms(String rawSms) async {
    try {
      final response = await ApiClient.post('/ai/voice-parse', {
        'text': rawSms, // Re-using voice-parse since sms endpoint was removed in AI proxy (fallback can be used or we can route it correctly if we kept an sms endpoint)
      });
      return ApiClient.processResponse(response);
    } catch (e) {
      debugPrint('SMS parsing error: $e');
      return null;
    }
  }

  // Parse a natural language text command via AI proxy
  Future<Map<String, dynamic>?> parseVoiceText(String voiceText) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient.post('/ai/voice-parse', {
        'text': voiceText,
      });
      final data = ApiClient.processResponse(response);
      if (data['success'] == true) {
        return data['parsed'];
      }
      return null;
    } catch (e) {
      _errorMessage = 'Voice parsing failed';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Auto-sync direct from SMS (triggers background imports)
  Future<bool> syncSmsDirect(String rawSms) async {
    try {
      // 1. Parse via AI proxy
      final parsed = await parseRawSms(rawSms);
      if (parsed != null) {
        // 2. Insert locally
        return await addTransaction(
          amount: double.tryParse(parsed['amount']?.toString() ?? '0') ?? 0.0,
          type: parsed['type'] ?? 'expense',
          merchantOrSender: parsed['merchant_or_sender'] ?? 'Unknown',
          category: parsed['category'] ?? 'Uncategorized',
          source: 'sms',
          note: parsed['note'],
          rawSms: rawSms,
        );
      }
      return false;
    } catch (e) {
      debugPrint('Background SMS sync failed: $e');
      return false;
    }
  }
}
