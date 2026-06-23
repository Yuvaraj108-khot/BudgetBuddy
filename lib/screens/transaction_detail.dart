import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../providers/transaction_provider.dart';
import '../providers/dashboard_provider.dart';
import '../core/theme/app_theme.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Transaction?'),
        content: const Text('Are you sure you want to delete this transaction record? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await Provider.of<TransactionProvider>(context, listen: false)
                  .deleteTransaction(transaction.id!);
              if (success) {
                // Refresh dashboard too
                Provider.of<DashboardProvider>(context, listen: false).fetchDashboard();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction deleted'), backgroundColor: AppColors.success),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, MMMM dd, yyyy - hh:mm a').format(transaction.transactionDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount representation
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
                child: Column(
                  children: [
                    Text(
                      transaction.category.toUpperCase(),
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${transaction.isExpense ? '-' : '+'}₹${transaction.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: transaction.isExpense ? AppColors.danger : AppColors.success,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      transaction.merchantOrSender,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Metadata fields
            _detailRow(Icons.calendar_month_outlined, 'Date & Time', dateStr),
            const Divider(color: AppColors.surfaceSecondary, height: 24),
            _detailRow(
              Icons.source_outlined,
              'Source',
              transaction.source == 'sms' ? 'Automatic SMS sync' : 'Manually entered',
            ),
            if (transaction.referenceNumber != null) ...[
              const Divider(color: AppColors.surfaceSecondary, height: 24),
              _detailRow(Icons.pin_outlined, 'Reference / UTR ID', transaction.referenceNumber!),
            ],
            const Divider(color: AppColors.surfaceSecondary, height: 24),
            _detailRow(
              Icons.note_alt_outlined,
              'Note',
              transaction.note == null || transaction.note!.isEmpty ? 'No notes added.' : transaction.note!,
            ),
            if (transaction.rawSms != null) ...[
              const Divider(color: AppColors.surfaceSecondary, height: 24),
              _detailRow(Icons.sms_outlined, 'Raw SMS Text', transaction.rawSms!, isLongText: true),
            ],

            const Spacer(),
            ElevatedButton(
              onPressed: () => _confirmDelete(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger.withOpacity(0.1),
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1),
              ),
              child: const Text('Delete Log'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String val, {bool isLongText = false}) {
    return Row(
      crossAxisAlignment: isLongText ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text(
                val,
                style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              )
            ],
          ),
        ),
      ],
    );
  }
}
