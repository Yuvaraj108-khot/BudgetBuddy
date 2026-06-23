import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../core/theme/app_theme.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _budgetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final dash = Provider.of<DashboardProvider>(context, listen: false);
    final pocket = dash.balance['pocket_money'] ?? 0.0;
    if (pocket > 0) {
      _budgetController.text = pocket.toString();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final dash = Provider.of<DashboardProvider>(context, listen: false);
    final now = DateTime.now();
    final success = await dash.updateBudget(
      now.month,
      now.year,
      double.parse(_budgetController.text),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pocket money budget updated!'), backgroundColor: AppColors.success),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dash = Provider.of<DashboardProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Set Pocket Money',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Specify your starting pocket money or budget for the current month. BudgetBuddy will track your daily limits accordingly.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),
              TextFormField(
                controller: _budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Starting pocket money (e.g. ₹5,000)',
                  prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.textMuted),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Budget cannot be empty';
                  if (double.tryParse(v) == null || double.parse(v) <= 0) {
                    return 'Please enter a positive budget amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              dash.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save Budget'),
                    )
            ],
          ),
        ),
      ),
    );
  }
}
