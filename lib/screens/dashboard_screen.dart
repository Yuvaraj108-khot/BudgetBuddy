import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../core/theme/app_theme.dart';
import 'budget_screen.dart';
import 'transaction_list.dart';
import 'add_transaction.dart';
import 'ai_chat_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await Provider.of<DashboardProvider>(context, listen: false).fetchDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final dashProvider = Provider.of<DashboardProvider>(context);

    final List<Widget> children = [
      _buildDashboardHome(dashProvider),
      const TransactionListScreen(),
      const AiChatScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: dashProvider.isLoading && dashProvider.balance.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Expenses'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline_rounded), label: 'AI Coach'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, size: 28, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildDashboardHome(DashboardProvider dashProvider) {
    final balance = dashProvider.balance;
    final discipline = dashProvider.discipline;
    final prediction = dashProvider.prediction;
    final insights = dashProvider.insights;
    final recentTx = dashProvider.recentTransactions;
    final totalIncome = balance['total_income'] ?? 0.0;
    final totalExpense = balance['total_expense'] ?? 0.0;
    final remaining = balance['remaining'] ?? 0.0;
    final limit = balance['daily_safe_limit'] ?? 0.0;
    final score = discipline['score'] ?? 80;
    final rank = discipline['rank'] ?? 'Good 👍';

    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.primary,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Welcome back,', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                      Text(
                        Provider.of<AuthProvider>(context, listen: false).currentUser?.name ?? 'Student',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const BudgetScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Glassmorphic Pocket Money Remaining Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('REMAINING POCKET MONEY', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    Text('₹$remaining', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _infoColumn('Monthly Income', '₹$totalIncome'),
                        _infoColumn('Expenses', '₹$totalExpense'),
                        _infoColumn('Safe Daily Limit', '₹$limit'),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Discipline Score card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.surfaceSecondary),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(Icons.stars_rounded, color: AppColors.accent, size: 30),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Discipline Score', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            '$score/100 • $rank',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                          )
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
                      onPressed: () {
                        // show dialog with details of score bonuses & deductions
                        _showDisciplineDetails(discipline);
                      },
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Budget deficit warnings & predictions
              if (prediction['will_exceed_budget'] == true)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Exceeding budget! Projected shortfall is ₹${prediction['projected_shortfall']}. Try cutting spending.',
                          style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      )
                    ],
                  ),
                ),

              // Smart Insights Section
              if (insights['insights'] != null && (insights['insights'] as List).isNotEmpty) ...[
                const Text('SMART COACH INSIGHTS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: (insights['insights'] as List).length,
                    itemBuilder: (context, index) {
                      final item = insights['insights'][index];
                      return Container(
                        width: 280,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.surfaceSecondary),
                        ),
                        child: Text(
                          item.toString(),
                          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Charts section
              if (dashProvider.categories.isNotEmpty) ...[
                const Text('EXPENSE DISTRIBUTION', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.surfaceSecondary),
                  ),
                  child: PieChart(
                    PieChartData(
                      sections: dashProvider.categories.map((c) {
                        final val = double.parse(c['total_spent'].toString());
                        final pct = (val / totalExpense) * 100;
                        return PieChartSectionData(
                          value: val,
                          title: '${pct.toStringAsFixed(0)}%',
                          color: _getCategoryColor(c['category']),
                          radius: 40,
                          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        );
                      }).toList(),
                      centerSpaceRadius: 40,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Recent transaction list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('RECENT TRANSACTIONS', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _currentIndex = 1;
                      });
                    },
                    child: const Text('View All', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                  )
                ],
              ),
              const SizedBox(height: 8),

              if (recentTx.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Text('No transactions registered yet.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentTx.length > 5 ? 5 : recentTx.length,
                  itemBuilder: (ctx, idx) {
                    final tx = recentTx[idx];
                    final isExpense = tx['type'] == 'expense';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (isExpense ? AppColors.danger : AppColors.success).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpense ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
                          color: isExpense ? AppColors.danger : AppColors.success,
                          size: 20,
                        ),
                      ),
                      title: Text(tx['merchant_or_sender'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(tx['category'] ?? 'Uncategorized', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      trailing: Text(
                        '${isExpense ? '-' : '+'}₹${tx['amount']}',
                        style: TextStyle(
                          color: isExpense ? AppColors.danger : AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    );
                  },
                )
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoColumn(String title, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        const SizedBox(height: 4),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Food & Dining':
        return Colors.orange;
      case 'Transport':
        return Colors.blue;
      case 'Shopping':
        return Colors.pink;
      case 'Education':
        return Colors.teal;
      case 'Entertainment':
        return Colors.red;
      case 'Health':
        return Colors.green;
      case 'Utilities':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  void _showDisciplineDetails(Map<String, dynamic> discipline) {
    final deductions = discipline['deductions'] as List? ?? [];
    final bonuses = discipline['bonuses'] as List? ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Discipline Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Deductions:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
              const SizedBox(height: 8),
              if (deductions.isEmpty)
                const Text('None 🎉', style: TextStyle(color: AppColors.textSecondary))
              else
                ...deductions.map((d) => Text('• ${d['reason']} (${d['points']})', style: const TextStyle(fontSize: 13))),
              const SizedBox(height: 16),
              const Text('Bonuses:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
              const SizedBox(height: 8),
              if (bonuses.isEmpty)
                const Text('None', style: TextStyle(color: AppColors.textSecondary))
              else
                ...bonuses.map((b) => Text('• ${b['reason']} (+${b['points']})', style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }
}
