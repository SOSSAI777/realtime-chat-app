import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/supabase_config.dart';
import 'ui/features/auth/login_screen.dart';
import 'ui/features/auth/register_screen.dart';
import 'ui/features/auth/forgot_password_screen.dart';
import 'ui/features/home/home_screen.dart';
import 'ui/features/chat/chat_screen.dart';
import 'ui/features/profile/edit_profile_screen.dart';
import 'ui/features/search/search_screen.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/profile_service.dart';
import 'services/presence_service.dart';
import 'services/search_service.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => ProfileService()),
        ChangeNotifierProvider(create: (_) => PresenceService()),
        Provider(create: (_) => SearchService()),
        Provider(create: (_) => StorageService()),
      ],
      child: MaterialApp(
        title: 'TalkOn',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: LoginScreen(),
        debugShowCheckedModeBanner: false,
        routes: {
          '/login': (context) => LoginScreen(),
          '/register': (context) => RegisterScreen(),
          '/forgot-password': (context) => ForgotPasswordScreen(),
          '/home': (context) =>
              HomeScreen(), // ✅ CORRIGIDO - HomeScreen deve existir
          '/edit-profile': (context) => EditProfileScreen(),
          '/search': (context) => SearchScreen(),
        },
        onGenerateRoute: (settings) {
          // Rota dinâmica para ChatScreen
          if (settings.name == '/chat') {
            final args = settings.arguments as Map<String, dynamic>?;
            final conversationId = args?['conversationId'] as String? ?? '';

            return MaterialPageRoute(
              builder: (context) => ChatScreen(conversationId: conversationId),
            );
          }
          return null;
        },
        onUnknownRoute: (settings) {
          // ✅ ADICIONADO - Para rotas desconhecidas
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: Text('Página não encontrada')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Página ${settings.name} não encontrada'),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context, '/login', (route) => false),
                      child: Text('Voltar para Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
