import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> uploadMessageImage(Uint8List bytes, String filename) async {
    try {
      // Verificar se usuário está autenticado
      if (_client.auth.currentUser == null) {
        throw Exception('Usuário não autenticado');
      }

      final String finalFilename =
          '${DateTime.now().millisecondsSinceEpoch}_${_sanitizeFilename(filename)}';

      // ✅ CORREÇÃO: Usar uploadBinary para Uint8List
      await _client.storage
          .from('message-images')
          .uploadBinary(finalFilename, bytes);

      final publicUrl =
          _client.storage.from('message-images').getPublicUrl(finalFilename);

      return publicUrl;
    } catch (e) {
      rethrow;
    }
  }

  String _getMimeType(String filename) {
    if (filename.toLowerCase().endsWith('.png')) return 'image/png';
    if (filename.toLowerCase().endsWith('.jpg') ||
        filename.toLowerCase().endsWith('.jpeg')) return 'image/jpeg';
    if (filename.toLowerCase().endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  String _sanitizeFilename(String filename) {
    return filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  Future<void> ensureBucketReady() async {
    try {
      await _client.storage.from('message-images').list();
    } catch (e) {
      throw Exception(
          'Bucket message-images não está configurado corretamente: $e');
    }
  }
}
