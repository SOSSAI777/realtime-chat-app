import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import 'profile_service.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _client = SupabaseConfig.client;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email, 
        password: password
      );
      
      if (res.session != null) {
        final profileService = ProfileService();
        await profileService.initializeProfile();
      }
      
      notifyListeners();
      return res;
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signUp(String email, String password) async {
    try {
      final res = await _client.auth.signUp(
        email: email, 
        password: password
      );
      
      if (res.user != null) {
        print('✅ Usuário registrado - perfil será criado no primeiro login');
      }
      
      notifyListeners();
      return res;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      final profileService = ProfileService();
      await profileService.setUserOnline(false);
      
      await _client.auth.signOut();
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      print('✅ Link de redefinição enviado para: $email');
    } catch (e) {
      print('❌ Erro ao enviar email de redefinição: $e');
      rethrow;
    }
  }
}