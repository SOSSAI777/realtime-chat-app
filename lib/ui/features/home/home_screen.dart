import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/supabase_config.dart';
import '../../../core/app_routes.dart';
import '../../../services/auth_service.dart';
import '../../../services/presence_service.dart';
import '../../../services/chat_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient _client = SupabaseConfig.client;
  late Future<List<dynamic>> _conversationsFuture;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _setUserOnline();
  }

  void _setUserOnline() {
    final presenceService =
        Provider.of<PresenceService>(context, listen: false);
    presenceService.setUserOnline();
  }

  Future<void> _loadConversations() async {
    setState(() {
      _conversationsFuture = _fetchConversations();
    });
  }

  Future<List<dynamic>> _fetchConversations() async {
    try {
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId == null) return [];

      final response = await _client.from('participants').select('''
            conversation:conversations(
              id,
              name,
              created_at,
              created_by,
              is_group,
              is_public,
              participants!inner(user_id),
              messages(id, content, created_at, type, is_deleted)
            )
          ''').eq('user_id', currentUserId);

      final conversations = (response as List<dynamic>)
          .map((item) => item['conversation'] as Map<String, dynamic>)
          .toList();

      return conversations;
    } catch (e) {
      print('Erro ao carregar conversas: $e');
      return [];
    }
  }

  void _createNewConversation(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    bool isGroup = false;
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Nova Conversa'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da conversa',
                    hintText: 'Ex: Provas',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: isGroup,
                      onChanged: (value) {
                        setDialogState(() {
                          isGroup = value!;
                        });
                      },
                    ),
                    const Text('Conversa em grupo'),
                  ],
                ),
                if (isGroup) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: isPublic,
                        onChanged: (value) {
                          setDialogState(() {
                            isPublic = value!;
                          });
                        },
                      ),
                      const Text('Grupo público'),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  isGroup
                      ? 'Grupo ${isPublic ? 'público' : 'privado'} criado'
                      : 'Conversa individual criada',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();

                  if (name.isEmpty) {
                    _showSnackbar(context, 'Digite um nome para a conversa');
                    return;
                  }

                  setDialogState(() {});

                  try {
                    final chatService =
                        Provider.of<ChatService>(context, listen: false);
                    final currentUserId = _client.auth.currentUser!.id;

                    await chatService.createConversation(
                        name, isGroup, isPublic, [currentUserId]);
                    if (!context.mounted) return;

                    Navigator.pop(context);
                    _loadConversations();
                    _showSnackbar(context, 'Conversa criada com sucesso!',
                        isError: false);
                  } catch (e) {
                    _showSnackbar(context, 'Erro: $e');
                  }
                },
                child: const Text('Criar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSnackbar(BuildContext context, String message,
      {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'Agora';
      }
    } catch (e) {
      return '';
    }
  }

  String _getLastMessageText(List<dynamic> messages) {
    if (messages.isEmpty) return 'Nenhuma mensagem';

    final lastMessage = messages.last;
    final isDeleted = lastMessage['is_deleted'] == true;

    if (isDeleted) return 'Mensagem excluída';

    final type = lastMessage['type'] as String?;
    if (type == 'image') return '📷 Imagem';

    return lastMessage['content'] ?? 'Mensagem';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TalkOn - Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/edit-profile'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              final presenceService =
                  Provider.of<PresenceService>(context, listen: false);
              presenceService.setUserOffline();
              Provider.of<AuthService>(context, listen: false).signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
          )
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _conversationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Erro ao carregar conversas'),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadConversations,
                    child: const Text('Tentar Novamente'),
                  ),
                ],
              ),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma conversa encontrada',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Toque no botão + para iniciar uma conversa',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => _createNewConversation(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Criar Primeira Conversa'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadConversations,
            child: ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (ctx, i) {
                final conv = conversations[i];
                final name = conv['name'] ?? 'Chat';
                final id = conv['id'];
                final isGroup = conv['is_group'] == true;

                final messages = conv['messages'] as List<dynamic>? ?? [];
                final lastMessageText = _getLastMessageText(messages);

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isGroup ? Colors.green : Colors.blue,
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (isGroup) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.group, size: 16, color: Colors.grey),
                        ]
                      ],
                    ),
                    subtitle: Text(
                      lastMessageText,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    trailing: messages.isNotEmpty
                        ? Text(
                            _formatTime(messages.last['created_at']),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          )
                        : null,
                    onTap: () {
                      Navigator.pushNamed(context, RoutesEnum.chat,
                          arguments: {'conversationId': id});
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _createNewConversation(context),
      ),
    );
  }
}
