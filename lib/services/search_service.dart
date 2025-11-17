import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class SearchService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .ilike('full_name', '%$query%')
          .limit(10);
      
      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Erro ao buscar usuários: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchGroups(String query) async {
    try {
      final response = await _client
          .from('conversations')
          .select()
          .eq('is_group', true)
          .eq('is_public', true)
          .ilike('name', '%$query%')
          .limit(10);
      
      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      print('Erro ao buscar grupos: $e');
      return [];
    }
  }
}