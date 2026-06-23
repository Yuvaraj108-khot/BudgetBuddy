import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/theme/app_theme.dart';
import 'dashboard_screen.dart';

enum PinMode { verify, setup, change, remove }

class PinScreen extends StatefulWidget {
  final PinMode mode;

  const PinScreen({super.key, required this.mode});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _onKeyPress(String val) {
    if (_pin.length >= 6) return;
    setState(() {
      _pin += val;
    });
    if (_pin.length == 4 || _pin.length == 6) {
      // Small delay for UX feel
      Future.delayed(const Duration(milliseconds: 200), () => _processPin());
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _processPin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (widget.mode == PinMode.verify) {
      final success = await authProvider.verifyPin(_pin);
      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        _showErrorSnackBar(authProvider.errorMessage ?? 'Wrong PIN entered');
        setState(() {
          _pin = '';
        });
      }
    } else if (widget.mode == PinMode.setup) {
      if (!_isConfirming) {
        setState(() {
          _confirmPin = _pin;
          _pin = '';
          _isConfirming = true;
        });
      } else {
        if (_pin == _confirmPin) {
          _promptPasswordConfirm((password) async {
            final success = await authProvider.setPin(_pin, password);
            if (success && mounted) {
              Navigator.of(context).pop();
              _showSuccessSnackBar('App PIN lock set successfully!');
            } else {
              _showErrorSnackBar(authProvider.errorMessage ?? 'Failed to set PIN');
              _resetSetup();
            }
          });
        } else {
          _showErrorSnackBar('PINs do not match. Restarting setup.');
          _resetSetup();
        }
      }
    }
  }

  void _resetSetup() {
    setState(() {
      _pin = '';
      _confirmPin = '';
      _isConfirming = false;
    });
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.success),
    );
  }

  void _promptPasswordConfirm(Function(String) onConfirm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Confirm Account Password'),
        content: Form(
          key: _formKey,
          child: TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Enter account password',
            ),
            validator: (v) => v == null || v.isEmpty ? 'Password is required' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _resetSetup();
            },
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                onConfirm(_passwordController.text);
                _passwordController.clear();
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Confirm'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    String titleText = 'Enter App PIN';
    if (widget.mode == PinMode.setup) {
      titleText = _isConfirming ? 'Confirm Your PIN' : 'Choose App PIN';
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.darkGradient),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (widget.mode != PinMode.verify)
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    else
                      const SizedBox(width: 48),
                    const Text('Security Lock', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                    if (widget.mode == PinMode.verify)
                      TextButton(
                        onPressed: () => authProvider.logout(),
                        child: const Text('Sign Out', style: TextStyle(color: AppColors.danger)),
                      )
                    else
                      const SizedBox(width: 48),
                  ],
                ),
              ),

              // Title and Code Dots
              Column(
                children: [
                  Icon(
                    widget.mode == PinMode.verify ? Icons.security_rounded : Icons.lock_outline_rounded,
                    size: 44,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    titleText,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.mode == PinMode.verify
                        ? 'Enter code to unlock your BudgetBuddy profile'
                        : 'Protect your financial logs with a 4 or 6-digit PIN',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 36),
                  // Dots representation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      bool active = _pin.length > index;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? AppColors.primary : Colors.transparent,
                          border: Border.all(color: AppColors.primary, width: 2),
                        ),
                      );
                    }),
                  ),
                ],
              ),

              // Custom Pad layout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                child: authProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: ['1', '2', '3'].map((n) => _padButton(n)).toList(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: ['4', '5', '6'].map((n) => _padButton(n)).toList(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: ['7', '8', '9'].map((n) => _padButton(n)).toList(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              const SizedBox(width: 72, height: 72),
                              _padButton('0'),
                              Container(
                                width: 72,
                                height: 72,
                                decoration: const BoxDecoration(shape: BoxShape.circle),
                                child: IconButton(
                                  icon: const Icon(Icons.backspace_outlined, color: AppColors.textPrimary, size: 24),
                                  onPressed: _onDelete,
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _padButton(String number) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.surfaceSecondary, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: () => _onKeyPress(number),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
