import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/transaction_provider.dart';
import '../providers/dashboard_provider.dart';
import '../core/storage/secure_storage.dart';

class SmsSyncService {
  static const EventChannel _smsEventChannel = EventChannel('com.yuvaraj.budget_buddy/sms');
  static StreamSubscription? _subscription;

  static Future<bool> requestPermissions() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static Future<void> startListening(BuildContext context) async {
    final hasPermission = await Permission.sms.isGranted;
    if (!hasPermission) return;

    final isSyncEnabled = await SecureStorage.isSmsSyncEnabled();
    if (!isSyncEnabled) return;

    // Cancel any active subscription before subscribing
    await _subscription?.cancel();

    _subscription = _smsEventChannel.receiveBroadcastStream().listen((dynamic event) async {
      if (event == null || event is! Map) return;

      final body = event['body'] as String?;
      if (body == null || body.trim().isEmpty) return;

      // Skip OTPs and promotional spam immediately on the client-side for performance
      final otpPattern = RegExp(r'\b(otp|one.time.password|verification.code)\b', caseSensitive: false);
      final promoPattern = RegExp(r'\b(offer|cashback|reward|discount|loyalty|win|congratulations)\b', caseSensitive: false);
      
      if (otpPattern.hasMatch(body) || promoPattern.hasMatch(body)) {
        debugPrint('SMS Sync Service: Skipping OTP or promotional spam');
        return;
      }

      // Send to backend for parsing and duplicate validation
      final txProvider = Provider.of<TransactionProvider>(context, listen: false);
      final parsedResult = await txProvider.parseRawSms(body);

      if (parsedResult != null && parsedResult['success'] == true && parsedResult['is_transaction'] == true) {
        final confidence = parsedResult['confidence'];
        final parsedData = parsedResult['parsed'];

        if (confidence == 'high') {
          // Auto save
          final autoSaved = await txProvider.syncSmsDirect(body);
          if (autoSaved) {
            Provider.of<DashboardProvider>(context, listen: false).fetchDashboard();
            _showNotificationSnackBar(
              context,
              'Auto-saved ₹${parsedData['amount']} spent at ${parsedData['merchant_or_sender']}',
            );
          }
        } else {
          // Medium/low confidence -> Prompt user to confirm details
          _showConfirmationDialog(context, parsedData, body);
        }
      }
    });
  }

  static void _showNotificationSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.flash_on_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  static void _showConfirmationDialog(BuildContext context, Map<String, dynamic> parsed, String rawSms) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.sms_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Transaction Detected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('We detected a new transaction SMS. Please confirm the details:'),
            const SizedBox(height: 16),
            Text('Amount: ₹${parsed['amount']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Merchant: ${parsed['merchant_or_sender']}'),
            Text('Type: ${parsed['type']}'),
            Text('Category: ${parsed['category']}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final txProvider = Provider.of<TransactionProvider>(context, listen: false);
              final saved = await txProvider.addTransaction(
                amount: double.parse(parsed['amount'].toString()),
                type: parsed['type'],
                merchantOrSender: parsed['merchant_or_sender'],
                category: parsed['category'],
                source: 'sms',
                rawSms: rawSms,
                referenceNumber: parsed['reference_number'],
              );
              if (saved) {
                Provider.of<DashboardProvider>(context, listen: false).fetchDashboard();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
