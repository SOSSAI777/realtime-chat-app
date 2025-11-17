import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class PresenceService extends ChangeNotifier {
  final SupabaseClient _client = SupabaseConfig.client;
  final Map<String, bool> _typingUsers = {};
  final Map<String, bool> _onlineUsers = {};

  Map<String, bool> get typingUsers => _typingUsers;
  Map<String, bool> get onlineUsers => _onlineUsers;

  void setUserOnline() {
    final userId = _client.auth.currentUser!.id;
    _client.from('user_status').upsert({
      'user_id': userId,
      'online': true,
      'last_seen': DateTime.now().toIso8601String(),
    });
  }

  void setUserOffline() {
    final userId = _client.auth.currentUser!.id;
    _client.from('user_status').upsert({
      'user_id': userId,
      'online': false,
      'last_seen': DateTime.now().toIso8601String(),
    });
  }

  Stream<Map<String, dynamic>> subscribeToUserStatus(String userId) {
    return _client
        .from('user_status')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((events) {
          if (events.isNotEmpty) {
            return events.first;
          }
          return {};
        });
  }

  void startTyping(String conversationId) {
    final userId = _client.auth.currentUser!.id;
    _client.from('typing_indicators').upsert({
      'user_id': userId,
      'conversation_id': conversationId,
      'typing': true,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  void stopTyping(String conversationId) {
    final userId = _client.auth.currentUser!.id;
    _client.from('typing_indicators').upsert({
      'user_id': userId,
      'conversation_id': conversationId,
      'typing': false,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<Map<String, dynamic>>> subscribeToTyping(String conversationId) {
    final stream = _client
        .from('typing_indicators')
        .stream(primaryKey: ['user_id', 'conversation_id']);

    return stream.map((events) {
      return events.where((event) {
        return event['conversation_id'] == conversationId &&
            event['typing'] == true;
      }).toList();
    });
  }
}
