import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../services/chat_service.dart';
import '../../../services/search_service.dart';
import 'dart:async';
import '../../../models/user_models.dart';
import '../../../services/auth_service.dart'; // Para pegar o ID do usuário logado (se necessário)

class AddParticipantScreen extends StatefulWidget {
  final String conversationId;

  const AddParticipantScreen({super.key, required this.conversationId});

  @override
  State<AddParticipantScreen> createState() => _AddParticipantScreenState();
}

class _AddParticipantScreenState extends State<AddParticipantScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<AppUser> _searchResults = [];
  Timer? _debounce;
  bool _isLoadingSearch = false;

  ChatService get _chatService => Provider.of<ChatService>(context, listen: false);
  SearchService get _searchService => Provider.of<SearchService>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      } else {
        setState(() {
          _searchResults = [];
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoadingSearch = true;
    });

    try {
   
      final currentParticipants = await _chatService.getAvailableUsers(widget.conversationId);
      final participantIds = currentParticipants.map((u) => u.id).toList();

      // 2. Executa a busca no serviço, excluindo participantes atuais
      final rawResults = await _searchService.searchUsers(
        query,
        excludeUserIds: participantIds,
      );

      // 3. Converte os resultados para AppUser
      final newResults = rawResults.map((map) => AppUser.fromMap(map)).toList();

      setState(() {
        _searchResults = newResults;
        _isLoadingSearch = false;
      });
    } catch (e) {
      print('Erro ao pesquisar usuários: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao pesquisar usuários: $e')),
        );
      }
      setState(() {
        _isLoadingSearch = false;
      });
    }
  }

  Future<void> _addUser(AppUser user) async {
    try {
      await _chatService.addUserToGroup(widget.conversationId, user.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.fullName ?? user.email} adicionado ao grupo!')),
        );
        // Limpa a busca e volta para a tela inicial do chat
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar usuário: $e')),
        );
      }
    }
  }

  Widget _buildUserListTile(AppUser user, {required bool isMember}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
        child: user.avatarUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(user.fullName ?? user.email),
      subtitle: Text(isMember ? 'Membro do grupo' : user.email),
      trailing: isMember
          ? null // Não há ação para membros na listagem de participantes
          : IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
              onPressed: () => _addUser(user),
            ),
      onTap: isMember
          ? null
          : () => _addUser(user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adicionar participante'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          // Exibe os resultados da pesquisa
          if (_searchController.text.trim().isNotEmpty)
            Expanded(
              child: _isLoadingSearch
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty
                      ? const Center(child: Text('Nenhum usuário encontrado.'))
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            return _buildUserListTile(user, isMember: false);
                          },
                        ),
            )
          // Exibe a lista de membros do grupo (se não houver pesquisa)
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 16.0, top: 8.0, bottom: 4.0),
                    child: Text('Membros do Grupo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: StreamBuilder<List<AppUser>>(
                      // Usa o stream de participantes para exibir a lista de membros
                      stream: _chatService.participantsStream(widget.conversationId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Erro ao carregar membros: ${snapshot.error}'));
                        }
                        
                        final participants = snapshot.data ?? [];
                        
                        if (participants.isEmpty) {
                          return const Center(child: Text('O grupo ainda não possui membros.'));
                        }

                        // Filtra o próprio usuário logado da lista para exibir apenas outros membros.
                        final currentUserId = Provider.of<AuthService>(context, listen: false).currentUser?.id;
                        final displayParticipants = participants.where((u) => u.id != currentUserId).toList();

                        return ListView.builder(
                          itemCount: displayParticipants.length,
                          itemBuilder: (context, index) {
                            final user = displayParticipants[index];
                            return _buildUserListTile(user, isMember: true);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
}