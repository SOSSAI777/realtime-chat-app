import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import 'storage_service.dart';

class ProfileService extends ChangeNotifier {
  final SupabaseClient _client = SupabaseConfig.client;
  final StorageService _storageService = StorageService();
  Map<String, dynamic>? _currentProfile;

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

  Future<String?> _uploadAvatar(Uint8List imageBytes, String filename) async {
    try {
      return await _storageService.uploadAvatar(imageBytes, filename);
    } catch (e) {
      print('❌ Erro ao fazer upload do avatar: $e');
      return null;
    }
  }

  Future<void> updateProfile(String fullName, Uint8List? imageBytes) async {
    try {
      final userId = _client.auth.currentUser!.id;
      String? avatarUrl;

      // Upload da imagem se existir
      if (imageBytes != null) {
        avatarUrl = await _uploadAvatar(
          imageBytes, 
          'avatar_$userId.jpg'
        );
        
        if (avatarUrl == null) {
          throw Exception('Falha no upload da imagem');
        }
        
        print('📸 Avatar URL gerada: $avatarUrl');
      }

      // Atualizar perfil no banco
      final updates = {
        'id': userId,
        'full_name': fullName,
        'online': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Adicionar avatar_url apenas se foi feito upload
      if (avatarUrl != null) {
        updates['avatar_url'] = avatarUrl;
      }

      final response = await _client.from('profiles').upsert(updates);

      print('📊 Resposta do upsert: $response');

      // Recarregar perfil atualizado
      _currentProfile = await getCurrentProfile();
      
      print('🔄 Perfil após atualização: $_currentProfile');
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

  // Método para forçar recarregamento do perfil
  Future<void> refreshProfile() async {
    _currentProfile = await getCurrentProfile();
    notifyListeners();
  }
}