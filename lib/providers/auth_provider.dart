import 'package:flutter/material.dart';
import '../services/local_repository.dart';
import '../core/storage/secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/user.dart';

enum AuthState { uninitialized, authenticated, unauthenticated, pinLocked }

class AuthProvider extends ChangeNotifier {
  final LocalRepository _repository = LocalRepository();
  
  AuthState _state = AuthState.uninitialized;
  User? _currentUser;
  String? _errorMessage;
  bool _isLoading = false;

  AuthState get state => _state;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  String _hashPin(String pin) {
    var bytes = utf8.encode(pin);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final pinHash = await _repository.getPinHash();
      
      final name = await SecureStorage.getUserName() ?? 'Local User';
      final email = await SecureStorage.getUserEmail() ?? 'local@device.com';
      
      _currentUser = User(id: 1, name: name, email: email, hasPin: pinHash != null);

      if (pinHash != null) {
        final verified = await SecureStorage.isPinVerified();
        _state = verified ? AuthState.authenticated : AuthState.pinLocked;
      } else {
        // No PIN set = treat as first launch setup needed
        _state = AuthState.unauthenticated;
      }
    } catch (e) {
      _state = AuthState.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Set PIN acts as the new "registration / login" for local app
  Future<bool> setPin(String pin, String? unusedPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final hash = _hashPin(pin);
      await _repository.savePinHash(hash);
      
      await SecureStorage.setPinConfigured(true);
      await SecureStorage.setPinVerified(true);
      
      final name = await SecureStorage.getUserName() ?? 'Local User';
      final email = await SecureStorage.getUserEmail() ?? 'local@device.com';
      _currentUser = User(id: 1, name: name, email: email, hasPin: true);
      _state = AuthState.authenticated;
      
      return true;
    } catch (e) {
      _errorMessage = 'Failed to set PIN locally';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyPin(String pin) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final storedHash = await _repository.getPinHash();
      final inputHash = _hashPin(pin);

      if (storedHash == inputHash) {
        await SecureStorage.setPinVerified(true);
        _state = AuthState.authenticated;
        return true;
      } else {
        _errorMessage = 'Incorrect PIN';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Verification failed. Try again.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removePin(String pin) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final storedHash = await _repository.getPinHash();
      final inputHash = _hashPin(pin);

      if (storedHash == inputHash) {
        await _repository.removePin();
        await SecureStorage.setPinConfigured(false);
        await SecureStorage.setPinVerified(false);
        
        final name = await SecureStorage.getUserName() ?? 'Local User';
        final email = await SecureStorage.getUserEmail() ?? 'local@device.com';
        _currentUser = User(id: 1, name: name, email: email, hasPin: false);
        return true;
      } else {
        _errorMessage = 'Incorrect PIN';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to remove PIN';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await SecureStorage.setPinVerified(false);
    _state = AuthState.pinLocked;
    notifyListeners();
  }

  Future<void> updateProfile(String name, String email) async {
    await SecureStorage.saveUserProfile(name, email);
    final pinHash = await _repository.getPinHash();
    _currentUser = User(id: 1, name: name, email: email, hasPin: pinHash != null);
    notifyListeners();
  }

  // Placeholder for old methods so UI doesn't crash immediately. 
  // Should refactor UI to bypass these entirely.
  Future<bool> login(String email, String password) async {
    return true; // Auto-pass local mock
  }

  Future<bool> register(String name, String email, String password, String? phone) async {
    return true; // Auto-pass local mock
  }
}
