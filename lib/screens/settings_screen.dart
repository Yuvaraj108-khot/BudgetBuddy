import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/storage/secure_storage.dart';
import '../services/sms_sync_service.dart';
import '../core/theme/app_theme.dart';
import 'pin_screen.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _smsSync = true;
  bool _hasPin = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final syncEnabled = await SecureStorage.isSmsSyncEnabled();
    final pinSet = await SecureStorage.isPinConfigured();
    setState(() {
      _smsSync = syncEnabled;
      _hasPin = pinSet;
    });
  }

  Future<void> _toggleSmsSync(bool value) async {
    if (value) {
      final granted = await SmsSyncService.requestPermissions();
      if (!granted) {
        _showErrorSnackBar('SMS Permissions are required to enable auto import.');
        return;
      }
    }
    await SecureStorage.setSmsSyncEnabled(value);
    setState(() {
      _smsSync = value;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Profile Info header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.surfaceSecondary),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: Text(
                      user?.name.substring(0, 1).toUpperCase() ?? 'S',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Student Name',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? 'student@university.edu',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        )
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                    onPressed: _showEditProfileDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Automation settings
            const Text('AUTOMATION & UTILITIES', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _smsSync,
                    onChanged: _toggleSmsSync,
                    title: const Text('Android SMS Auto Import', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Automatically extract transaction details from banking SMS notifications.', style: TextStyle(fontSize: 11)),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Security Settings
            const Text('SECURITY LOCK', style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Configure Security PIN', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      _hasPin ? 'App is protected by numeric lock PIN' : 'Add secondary lock screen on app startup',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Icon(
                      _hasPin ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                      color: _hasPin ? AppColors.success : AppColors.textMuted,
                    ),
                    onTap: () async {
                      if (!_hasPin) {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PinScreen(mode: PinMode.setup)),
                        );
                      } else {
                        // Option to delete PIN
                        _promptRemovePin();
                      }
                      _loadPreferences();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // Logout
            ElevatedButton(
              onPressed: () async {
                await authProvider.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const PinScreen(mode: PinMode.verify)),
                    (route) => false,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger.withOpacity(0.1),
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: AppColors.danger, width: 1),
              ),
              child: const Text('Sign Out'),
            )
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    final nameController = TextEditingController(text: user?.name);
    final emailController = TextEditingController(text: user?.email);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit Local Profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Full Name'),
                validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(hintText: 'Email (Optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                await auth.updateProfile(nameController.text.trim(), emailController.text.trim());
                if (mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profile updated'), backgroundColor: AppColors.success),
                  );
                }
              }
            },
            child: const Text('Save'),
          )
        ],
      ),
    );
  }

  void _promptRemovePin() {
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Disable PIN Lock?'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your current PIN to verify configuration removal:'),
              const SizedBox(height: 12),
              TextFormField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Current PIN'),
                validator: (v) => v == null || v.isEmpty ? 'PIN is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                final success = await auth.removePin(pinController.text);
                if (success && mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN security lock disabled'), backgroundColor: AppColors.success),
                  );
                  _loadPreferences();
                } else if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(auth.errorMessage ?? 'Verification failed'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            child: const Text('Disable'),
          )
        ],
      ),
    );
  }
}
