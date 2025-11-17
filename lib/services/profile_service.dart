import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import 'storage_service.dart';

class ProfileService extends ChangeNotifier {
  final SupabaseClient _client = SupabaseConfig.client;
  final StorageService _storageService = StorageService();
  Map<String, dynamic>? _currentProfile;
  String? _currentImageUrl;

  Map<String, dynamic>? get currentProfile => _currentProfile;

  Future<void> initializeProfile() async {
    try {
      final userId = _client.auth.currentUser!.id;
      final email = _client.auth.currentUser!.email!;
      
      print('🔍 Verificando perfil para: $email');
      
      _currentProfile = await getCurrentProfile();
      
      if (_currentProfile == null) {
        print('🆕 Criando perfil automaticamente...');
        await _client.from('profiles').insert({
          'id': userId,
          'full_name': _getNameFromEmail(email),
          'online': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        
        _currentProfile = await getCurrentProfile();
        print('✅ Perfil criado com sucesso');
      } else {
        print('✅ Perfil encontrado: ${_currentProfile!['full_name']}');
      }
      
      notifyListeners();
      
    } catch (e) {
      print('❌ Erro ao inicializar perfil: $e');
    }
  }

  String _getNameFromEmail(String email) {
    final namePart = email.split('@').first;
    return namePart[0].toUpperCase() + namePart.substring(1);
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    try {
      final userId = _client.auth.currentUser!.id;
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('❌ Erro ao buscar perfil: $e');
      return null;
    }
  }

  Future<String> uploadAvatar(Uint8List imageBytes, String filename) async {
    return await _storageService.uploadMessageImage(imageBytes, filename);
  }

  Future<void> updateProfile(String fullName, Uint8List? imageBytes) async {
    try {
      final userId = _client.auth.currentUser!.id;
      String? avatarUrl;

      if (imageBytes != null) {
        avatarUrl = await _storageService.uploadMessageImage(
          imageBytes, 
          'avatar_$userId.jpg'
        );
      }

      await _client.from('profiles').upsert({
        'id': userId,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'online': true,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _currentProfile = await getCurrentProfile();
      notifyListeners();
      
      print('✅ Perfil atualizado com sucesso');
    } catch (e) {
      print('❌ Erro ao atualizar perfil: $e');
      rethrow;
    }
  }

  Future<void> setUserOnline(bool online) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('profiles').upsert({
        'id': userId,
        'online': online,
        'last_seen': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Erro ao atualizar status online: $e');
    }
  }
}