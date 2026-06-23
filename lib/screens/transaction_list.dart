import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../models/transaction.dart';
import '../core/theme/app_theme.dart';
import 'transaction_detail.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  String _filterType = 'all'; // all, income, expense
  String _searchQuery = '';
  String _filterCategory = 'All';

  final List<String> _categories = [
    'All', 'Food & Dining', 'Transport', 'Shopping',
    'Education', 'Entertainment', 'Health', 'Utilities',
    'Friends/Family', 'Savings/Transfer', 'Uncategorized'
  ];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await Provider.of<TransactionProvider>(context, listen: false).fetchTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);

    // Apply client-side search & filters
    final filtered = txProvider.transactions.where((tx) {
      final matchesSearch = tx.merchantOrSender.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (tx.note ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      
      final matchesType = _filterType == 'all' || tx.type == _filterType;
      
      final matchesCat = _filterCategory == 'All' || tx.category == _filterCategory;

      return matchesSearch && matchesType && matchesCat;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search merchant or notes...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              // Filter Chips Row (Income/Expense)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    _filterChip('All', 'all'),
                    const SizedBox(width: 8),
                    _filterChip('Expenses', 'expense'),
                    const SizedBox(width: 8),
                    _filterChip('Income', 'income'),
                  ],
                ),
              ),

              // Category scroll row
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, idx) {
                    final cat = _categories[idx];
                    final active = _filterCategory == cat;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _filterCategory = cat;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: active ? AppColors.primary : AppColors.surfaceSecondary),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 12,
                              color: active ? AppColors.textPrimary : AppColors.textSecondary,
                              fontWeight: active ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Transaction List
              Expanded(
                child: txProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _refreshData,
                        color: AppColors.primary,
                        child: filtered.isEmpty
                            ? const Center(
                                child: Text(
                                  'No transactions matching filters.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: filtered.length,
                                itemBuilder: (ctx, idx) {
                                  final tx = filtered[idx];
                                  final dateStr = DateFormat('MMM dd, yyyy').format(tx.transactionDate);
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(builder: (_) => TransactionDetailScreen(transaction: tx)),
                                        );
                                      },
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: (tx.isExpense ? AppColors.danger : AppColors.success).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          tx.isExpense ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
                                          color: tx.isExpense ? AppColors.danger : AppColors.success,
                                          size: 18,
                                        ),
                                      ),
                                      title: Text(tx.merchantOrSender, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      subtitle: Text('${tx.category} • $dateStr', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      trailing: Text(
                                        '${tx.isExpense ? '-' : '+'}₹${tx.amount.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          color: tx.isExpense ? AppColors.danger : AppColors.success,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filterType == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (val) {
        if (val) {
          setState(() {
            _filterType = value;
          });
        }
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        fontSize: 12,
        color: active ? AppColors.textPrimary : AppColors.textSecondary,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
