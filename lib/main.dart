import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/chat_provider.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/sms_sync_service.dart';

import 'core/db/local_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDatabase.instance.database; // Pre-initialize DB
  runApp(const BudgetBuddyApp());
}

class BudgetBuddyApp extends StatelessWidget {
  const BudgetBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        title: 'BudgetBuddy',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AppRoot(),
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  void initState() {
    super.initState();
    // Start listening for transaction SMS alerts once app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSmsSync();
    });
  }

  Future<void> _initSmsSync() async {
    // Initiate background SMS listener service in foreground mode
    await SmsSyncService.startListening(context);
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen();
  }
}
