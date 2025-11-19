import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/chat_service.dart';
import '../../../services/auth_service.dart';
// [ALTERAÇÃO]: Mantendo o import da nova tela
import '../../../ui/features/chat/add_participant_screen.dart'; 
import '../../../services/presence_service.dart';
import '../../../ui/widgets/message_bubble.dart';
import '../../../models/message_model.dart';
import '../../../models/user_models.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  
  const ChatScreen({super.key, required this.conversationId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // [SEUS MÉTODOS DE FORMATAÇÃO]
  String _formatTime(DateTime date) {
    final localDate = date.toLocal();
    return '${localDate.hour.toString().padLeft(2, '0')}:${localDate.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(localDate.year, localDate.month, localDate.day);

    if (messageDay == today) {
      return 'Hoje';
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Ontem';
    } else {
      return '${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}/${localDate.year}';
    }
  }

  // [SUAS VARIÁVEIS DE ESTADO]
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _typingSubscription;
  List<Message> _messages = [];
  String _conversationId = '';
  bool _isLoading = true;
  bool _isTyping = false;
  final Map<String, String> _typingUsers = {};

  ChatService get _chatService => Provider.of<ChatService>(context, listen: false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeChat();
  }

  void _initializeChat() async {
    _conversationId = widget.conversationId;

    if (_conversationId.isNotEmpty) {
      await _loadInitialMessages();
      _subscribeToMessages();
      _subscribeToTyping();
    }
  }

  // [MODIFICAÇÃO ESSENCIAL]: Substitui a lógica antiga do modal pela navegação para a nova tela.
  void _openAddUserModal() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddParticipantScreen(
          conversationId: _conversationId,
        ),
      ),
    );
  }

  Future<void> _loadInitialMessages() async {
    try {
      final chatService = Provider.of<ChatService>(context, listen: false);
      final messages = await chatService.fetchMessages(_conversationId);

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }

      _scrollToBottom();
    } catch (e) {
      print('❌ Erro ao carregar mensagens: $e');
      if (mounted) {
        _showErrorSnackbar('Erro ao carregar mensagens');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToMessages() {
    final chatService = Provider.of<ChatService>(context, listen: false);

    _messagesSubscription?.cancel();

    _messagesSubscription =
        chatService.subscribeMessages(_conversationId).listen(
      (newMessages) {
        print('🔄 Subscription atualizada: ${newMessages.length} mensagens');

        if (mounted) {
          setState(() {
            _messages = newMessages;
          });
        }

        _scrollToBottom();
      },
      onError: (error) {
        print('❌ Erro na subscription: $error');
        if (mounted) {
          _showErrorSnackbar('Erro na conexão em tempo real');
        }

        Future.delayed(const Duration(seconds: 3), () {
          if (_conversationId.isNotEmpty && mounted) {
            _subscribeToMessages();
          }
        });
      },
    );
  }

  void _subscribeToTyping() {
    final presenceService =
        Provider.of<PresenceService>(context, listen: false);

    _typingSubscription?.cancel();

    _typingSubscription =
        presenceService.subscribeToTyping(_conversationId).listen(
      (typingEvents) {
        if (mounted) {
          setState(() {
            _typingUsers.clear();
            for (final event in typingEvents) {
              _typingUsers[event['user_id']] = event['user_name'] ?? 'Usuário';
            }
          });
        }
      },
    );
  }

  void _startTyping() {
    if (!_isTyping) {
      _isTyping = true;
      final presenceService =
          Provider.of<PresenceService>(context, listen: false);
      presenceService.startTyping(_conversationId);
    }
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      final presenceService =
          Provider.of<PresenceService>(context, listen: false);
      presenceService.stopTyping(_conversationId);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _messages.isNotEmpty) {
        if (_scrollController.position.maxScrollExtent > 0) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }

        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final chatService = Provider.of<ChatService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.currentUser?.id ?? '';

    if (userId.isEmpty) {
      _showErrorSnackbar('Usuário não autenticado');
      return;
    }

    if (_conversationId.isEmpty) {
      _showErrorSnackbar('Conversa não encontrada');
      return;
    }

    try {
      _textController.clear();
      _stopTyping();

      await chatService.sendTextMessage(_conversationId, userId, text);
    } catch (e) {
      print('❌ Erro ao enviar mensagem: $e');
      _showErrorSnackbar('Erro ao enviar mensagem: $e');
      _textController.text = text;
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image != null) {
        final List<int> imageBytes = await image.readAsBytes();
        final Uint8List bytes = Uint8List.fromList(imageBytes);

        if (!mounted) return;
        final chatService = Provider.of<ChatService>(context, listen: false);
        final auth = Provider.of<AuthService>(context, listen: false);
        final userId = auth.currentUser?.id ?? '';

        if (userId.isEmpty || _conversationId.isEmpty) {
          _showErrorSnackbar('Erro: usuário ou conversa não encontrada');
          return;
        }

        await chatService.sendImageMessage(
            _conversationId, userId, bytes, image.name);

        _showSuccessSnackbar('Imagem enviada!');
      }
    } catch (e) {
      print('❌ Erro ao enviar imagem: $e');
      _showErrorSnackbar('Erro ao enviar imagem: $e');
    }
  }

  void _removeMessageLocally(String messageId) {
    if (mounted) {
      setState(() {
        _messages.removeWhere((message) => message.id == messageId);
      });
    }
  }

  Future<void> _forceRefreshMessages() async {
    _messagesSubscription?.cancel();
    await _loadInitialMessages();
    _subscribeToMessages();
  }

  void _showMessageOptions(Message message) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final isMyMessage = message.senderId == auth.currentUser?.id;
    final canEdit = isMyMessage &&
        DateTime.now().difference(message.createdAt).inMinutes <= 5;

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canEdit && message.type == 'text' && !message.isDeleted)
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Editar mensagem'),
              onTap: () {
                Navigator.pop(context);
                _editMessage(message);
              },
            ),
          if (isMyMessage)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Excluir mensagem',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
          ListTile(
            leading: const Icon(Icons.emoji_emotions),
            title: const Text('Adicionar reação'),
            onTap: () {
              Navigator.pop(context);
              _showReactionPicker(message);
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancelar'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _editMessage(Message message) {
    final TextEditingController editController =
        TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar mensagem'),
        content: TextField(
          controller: editController,
          maxLines: 3,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Digite a nova mensagem...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newContent = editController.text.trim();
              if (newContent.isNotEmpty && newContent != message.content) {
                try {
                  if (!mounted) return;
                  final chatService =
                      Provider.of<ChatService>(context, listen: false);
                  await chatService.editMessage(message.id, newContent);

                  _loadInitialMessages();

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _showSuccessSnackbar('Mensagem editada');
                } catch (e) {
                  _showErrorSnackbar('Erro ao editar mensagem: $e');
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _deleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir mensagem'),
        content: const Text(
            'Tem certeza que deseja excluir esta mensagem? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              _removeMessageLocally(message.id);

              try {
                if (!mounted) return;
                final chatService =
                    Provider.of<ChatService>(context, listen: false);

                await chatService.deleteMessage(message.id);

                await Future.delayed(const Duration(milliseconds: 1000));
                final isTrulyDeleted =
                    await chatService.isMessageDeleted(message.id);

                if (isTrulyDeleted) {
                  _showSuccessSnackbar('Mensagem excluída com sucesso');
                } else {
                  print('⚠️ Falha ao excluir a mensagem, recarregando...');
                  _showErrorSnackbar(
                      'Falha ao excluir. A mensagem será recarregada.');
                  await _forceRefreshMessages();
                }
              } catch (e) {
                print('❌ Erro ao excluir mensagem: $e');
                _showErrorSnackbar('Erro ao excluir mensagem: $e');

                _loadInitialMessages();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  void _showReactionPicker(Message message) {
    final emojis = ['👍', '❤️', '😄', '😮', '😢', '🙏'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar reação'),
        content: Wrap(
          spacing: 8,
          children: emojis
              .map((emoji) => GestureDetector(
                    onTap: () async {
                      try {
                        if (!mounted) return;
                        final chatService =
                            Provider.of<ChatService>(context, listen: false);
                        final auth =
                            Provider.of<AuthService>(context, listen: false);
                        final userId = auth.currentUser?.id ?? '';

                        await chatService.addReaction(
                            message.id, userId, emoji);

                        _loadInitialMessages();

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _showSuccessSnackbar('Reação adicionada!');
                      } catch (e) {
                        _showErrorSnackbar('Erro ao adicionar reação: $e');
                      }
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _removeReaction(MessageReaction reaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover Reação'),
        content: Text(
            'Tem certeza que deseja remover sua reação "${reaction.emoji}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (!mounted) return;
                final chatService =
                    Provider.of<ChatService>(context, listen: false);

                await chatService.removeReaction(reaction.id);

                _loadInitialMessages();

                if (!context.mounted) return;
                Navigator.pop(context);
                _showSuccessSnackbar('Reação removida');
              } catch (e) {
                _showErrorSnackbar('Erro ao remover reação: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _stopTyping();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final userId = auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat'),
            if (_typingUsers.isNotEmpty)
              Text(
                '${_typingUsers.values.join(', ')} ${_typingUsers.length == 1 ? 'está' : 'estão'} digitando...',
                style: const TextStyle(
                    fontSize: 12, color: Color.fromARGB(179, 0, 3, 14)),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _forceRefreshMessages,
          ),
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _openAddUserModal, // Chama o método modificado
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat,
                                  size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text(
                                'Nenhuma mensagem ainda',
                                style: TextStyle(color: Colors.grey),
                              ),
                              const Text(
                                'Seja o primeiro a enviar uma mensagem!',
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: _loadInitialMessages,
                                child: const Text('Recarregar'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _messages.length,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          reverse: false,
                          itemBuilder: (ctx, i) {
                            final message = _messages[i];
                            final isMine = message.senderId == userId;

                            bool showDate = false;
                            if (i == 0) {
                              showDate = true;
                            } else {
                              final previousMessage = _messages[i - 1];
                              final currentDate = DateTime(
                                message.createdAt.year,
                                message.createdAt.month,
                                message.createdAt.day,
                              );
                              final previousDate = DateTime(
                                previousMessage.createdAt.year,
                                previousMessage.createdAt.month,
                                previousMessage.createdAt.day,
                              );
                              showDate = currentDate != previousDate;
                            }

                            return Column(
                              children: [
                                if (showDate)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        _formatDate(message.createdAt),
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                GestureDetector(
                                  onLongPress: () =>
                                      _showMessageOptions(message),
                                  child: MessageBubble(
                                    message: message,
                                    isMine: isMine,
                                    currentUserId: userId,
                                    onReactionTap: (reaction) {
                                      _removeReaction(reaction);
                                    },
                                  ),
                                ),

                                if (i == _messages.length - 1)
                                  const SizedBox(height: 16),
                              ],
                            );
                          },
                        )),
          SafeArea(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _pickAndSendImage,
                      icon: const Icon(Icons.photo_library, color: Colors.blue),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _textController,
                          decoration: const InputDecoration(
                            hintText: 'Digite uma mensagem...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onChanged: (text) {
                            if (text.isNotEmpty) {
                              _startTyping();
                            } else {
                              _stopTyping();
                            }
                          },
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sendMessage,
                      icon: Icon(Icons.send,
                          color: _textController.text.trim().isEmpty
                              ? Colors.grey
                              : Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
