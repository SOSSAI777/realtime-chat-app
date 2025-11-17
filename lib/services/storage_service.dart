import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class StorageService {
  final SupabaseClient _client = SupabaseConfig.client;

  // Upload de avatar para o bucket 'avatars'
  Future<String> uploadAvatar(Uint8List imageBytes, String filename) async {
    try {
      print('📤 Iniciando upload do avatar: $filename');
      
      // Verificar se o bucket existe
      try {
        await _client.storage.from('avatars').list();
      } catch (e) {
        print('❌ Bucket avatars não encontrado: $e');
        throw Exception('Bucket avatars não configurado. Configure no Supabase Dashboard.');
      }
      
      // Fazer upload
      final uploadResponse = await _client.storage
          .from('avatars')
          .uploadBinary(
            filename, 
            imageBytes,
            fileOptions: FileOptions(
              upsert: true, // Sobrescrever se já existir
              contentType: 'image/jpeg',
            ),
          );

      print('✅ Upload realizado com sucesso');

      // Obter URL pública
      final imageUrl = _client.storage
          .from('avatars')
          .getPublicUrl(filename);

      print('🔗 URL pública: $imageUrl');

      return imageUrl;
    } catch (e) {
      print('❌ Erro no upload do avatar: $e');
      rethrow;
    }
  }

  // Upload de imagens de mensagens
  Future<String> uploadMessageImage(Uint8List imageBytes, String filename) async {
    try {
      final uploadResponse = await _client.storage
          .from('message_images')
          .uploadBinary(
            filename, 
            imageBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final imageUrl = _client.storage
          .from('message_images')
          .getPublicUrl(filename);

      return imageUrl;
    } catch (e) {
      print('❌ Erro no upload da imagem: $e');
      rethrow;
    }
  }

  // Método para deletar avatar (opcional)
  Future<void> deleteAvatar(String filename) async {
    try {
      await _client.storage
          .from('avatars')
          .remove([filename]);
      print('✅ Avatar deletado: $filename');
    } catch (e) {
      print('❌ Erro ao deletar avatar: $e');
      rethrow;
    }
  }

  Future<void> ensureBucketReady() async {}
}