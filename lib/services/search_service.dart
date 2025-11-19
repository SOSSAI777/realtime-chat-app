import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';

class SearchService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Busca usuários por nome ou email, permitindo excluir uma lista de IDs (ex: membros do grupo)
  Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    List<String> excludeUserIds = const [], // ✅ Parâmetro novo adicionado
  }) async {
    try {
      // Cria o filtro de busca: nome OU email contendo o texto pesquisado
      final searchFilter = "full_name.ilike.%$query%,email.ilike.%$query%";
      
      var queryBuilder = _client
          .from('profiles')
          .select()
          .or(searchFilter);

      // ✅ Aplica o filtro de exclusão se houver IDs na lista
      if (excludeUserIds.isNotEmpty) {
        // Exclui usuários cujo ID esteja na lista 'excludeUserIds'
        queryBuilder = queryBuilder.not('id', 'in', excludeUserIds);
      }

      final response = await queryBuilder.limit(10);
      
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