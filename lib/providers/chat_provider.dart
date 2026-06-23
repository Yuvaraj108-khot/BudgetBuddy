import 'package:flutter/material.dart';
import '../core/api/api_client.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class ChatProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  String? _errorMessage;

  List<ChatMessage> get messages => _messages;
  bool get isTyping => _isTyping;
  String? get errorMessage => _errorMessage;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    _messages.add(ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));
    _isTyping = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await ApiClient.post('/ai/chat', {
        'query': text,
      });
      final data = ApiClient.processResponse(response);

      if (data['success'] == true) {
        _messages.add(ChatMessage(
          text: data['reply'],
          isUser: false,
          timestamp: DateTime.now(),
        ));
      } else {
        _errorMessage = 'Failed to generate a response';
      }
    } catch (e) {
      _messages.add(ChatMessage(
        text: '⚠️ Connection error. I am unable to access your transactions offline.',
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages.clear();
    notifyListeners();
  }
}
