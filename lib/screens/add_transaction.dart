import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../providers/transaction_provider.dart';
import '../providers/dashboard_provider.dart';
import '../core/theme/app_theme.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();
  
  String _type = 'expense'; // expense, income
  String _category = 'Food & Dining';

  final List<String> _categories = [
    'Food & Dining', 'Transport', 'Shopping',
    'Education', 'Entertainment', 'Health', 'Utilities',
    'Friends/Family', 'Savings/Transfer', 'Uncategorized'
  ];

  // Speech-To-Text variables
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceText = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => debugPrint('STT status: $val'),
        onError: (val) => debugPrint('STT error: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _voiceText = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0) {
              // Once user finishes speaking, parse the command
              if (val.finalResult) {
                _isListening = false;
                _parseVoiceCommand(_voiceText);
              }
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  Future<void> _parseVoiceCommand(String text) async {
    if (text.isEmpty) return;

    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final parsed = await txProvider.parseVoiceText(text);

    if (parsed != null && mounted) {
      setState(() {
        _amountController.text = parsed['amount']?.toString() ?? '';
        _merchantController.text = parsed['merchant_or_sender'] ?? '';
        _type = parsed['type'] ?? 'expense';
        _category = parsed['category'] ?? 'Uncategorized';
        _noteController.text = parsed['note'] ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice command parsed successfully! Review before saving.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(txProvider.errorMessage ?? 'Failed to parse voice command. Enter manually.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final txProvider = Provider.of<TransactionProvider>(context, listen: false);
    final success = await txProvider.addTransaction(
      amount: double.parse(_amountController.text),
      type: _type,
      merchantOrSender: _merchantController.text.trim(),
      category: _category,
      note: _noteController.text.trim(),
    );

    if (success && mounted) {
      Provider.of<DashboardProvider>(context, listen: false).fetchDashboard();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction saved!'), backgroundColor: AppColors.success),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(txProvider.errorMessage ?? 'Failed to save transaction'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txProvider = Provider.of<TransactionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Transaction'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Voice input helper button
                  Card(
                    color: AppColors.surfaceSecondary,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text(
                            'AI VOICE TRANSACTION',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: _listen,
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: _isListening ? AppColors.danger : AppColors.primary,
                                  child: Icon(
                                    _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isListening
                                ? 'Listening... Speak now.'
                                : (_voiceText.isNotEmpty ? 'Recognized: "$_voiceText"' : 'Tap mic and say: "Spent 300 on canteen food"'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: _isListening ? AppColors.danger : AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Income / Expense selector
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Expense')),
                          selected: _type == 'expense',
                          onSelected: (val) => setState(() => _type = 'expense'),
                          selectedColor: AppColors.danger,
                          backgroundColor: AppColors.surface,
                          labelStyle: TextStyle(
                            color: _type == 'expense' ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ChoiceChip(
                          label: const Center(child: Text('Income')),
                          selected: _type == 'income',
                          onSelected: (val) => setState(() => _type = 'income'),
                          selectedColor: AppColors.success,
                          backgroundColor: AppColors.surface,
                          labelStyle: TextStyle(
                            color: _type == 'income' ? Colors.white : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Form Fields
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'Amount',
                      prefixIcon: Icon(Icons.currency_rupee_rounded, color: AppColors.textMuted),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter an amount';
                      if (double.tryParse(v) == null || double.parse(v) <= 0) {
                        return 'Amount must be positive';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _merchantController,
                    decoration: const InputDecoration(
                      hintText: 'Merchant / Sender (e.g. Cafe, Dad)',
                      prefixIcon: Icon(Icons.storefront_outlined, color: AppColors.textMuted),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Please enter merchant/sender' : null,
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: _category,
                    dropdownColor: AppColors.surface,
                    decoration: const InputDecoration(
                      hintText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined, color: AppColors.textMuted),
                    ),
                    items: _categories.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (val) => setState(() => _category = val!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Add notes...',
                      prefixIcon: Icon(Icons.edit_note_rounded, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 32),

                  txProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _submit,
                          child: const Text('Save Transaction'),
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
