import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://ykxqeutmctmgsjnaoelp.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlreHFldXRtY3RtZ3NqbmFvZWxwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA3ODc2NDgsImV4cCI6MjA3NjM2MzY0OH0.IQmVuOWy0wZY_FKSOzC_pYg0hfPk0tiRoCOwcF-Ay9c';

  static Future<void> init() async {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      print('✅ Supabase inicializado com sucesso!');
    } catch (e) {
      print('❌ Erro ao inicializar Supabase: $e');
      rethrow;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
