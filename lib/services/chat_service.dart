import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/message_model.dart';
import 'storage_service.dart';
import 'package:uuid/uuid.dart';

class ChatService extends ChangeNotifier {
  final SupabaseClient _client = SupabaseConfig.client;
  final StorageService _storageService = StorageService();
  final _uuid = const Uuid();

  StreamSubscription<List<Message>>? _messagesSub;

  Future<List<Message>> fetchMessages(String conversationId) async {
    try {
      print('🔍 Buscando mensagens para: $conversationId');

      final res = await _client
          .from('messages')
          .select('''
      *,
      message_reactions(*)
    ''')
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      ;

      final data = res;
      print('📨 ${data.length} mensagens encontradas');

      final messages = data.map((e) {
        final map = e;

        String content = '';
        String type = 'text';

        if (map.containsKey('content') && map['content'] != null) {
          content = map['content'] as String;
        } else if (map.containsKey('payload')) {
          final payload = map['payload'] as Map<String, dynamic>?;
          content = payload?['content']?.toString() ?? '';
          type = payload?['type']?.toString() ?? 'text';
        }

        DateTime createdAt;
        try {
          if (map['created_at'] is String) {
            createdAt = DateTime.parse(map['created_at'] as String);
          } else if (map['inserted_at'] is String) {
            createdAt = DateTime.parse(map['inserted_at'] as String);
          } else {
            createdAt = DateTime.now();
          }
        } catch (e) {
          createdAt = DateTime.now();
        }

        // PROCESSAR REAÇÕES
        List<MessageReaction> reactions = [];
        final reactionsData = map['message_reactions'] as List<dynamic>?;
        if (reactionsData != null) {
          for (final reactionMap in reactionsData) {
            try {
              final reaction =
                  MessageReaction.fromMap(reactionMap as Map<String, dynamic>);
              reactions.add(reaction);
            } catch (e) {
              print('⚠️ Erro ao processar reação: $e');
            }
          }
        }

        return Message(
          id: map['id'] as String,
          conversationId: map['conversation_id'] as String,
          senderId: map['sender_id'] as String,
          content: content,
          type: type,
          createdAt: createdAt,
          reactions: reactions,
          isEdited: map['is_edited'] as bool? ?? false,
          isDeleted: map['is_deleted'] as bool? ?? false,
        );
      }).toList();

      return messages;
    } catch (e) {
      print('❌ Erro ao buscar mensagens: $e');
      return [];
    }
  }

  Stream<List<Message>> subscribeMessages(String conversationId) {
    try {
      return _client
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .asyncMap((events) async {
            final messagesWithReactions =
                await Future.wait(events.map((map) async {
              String content = '';
              String type = 'text';

              if (map.containsKey('content') && map['content'] != null) {
                content = map['content'] as String;
              } else if (map.containsKey('payload')) {
                final payload = map['payload'] as Map<String, dynamic>?;
                content = payload?['content']?.toString() ?? '';
                type = payload?['type']?.toString() ?? 'text';
              }

              DateTime createdAt;
              try {
                if (map['created_at'] is String) {
                  createdAt = DateTime.parse(map['created_at'] as String);
                } else if (map['inserted_at'] is String) {
                  createdAt = DateTime.parse(map['inserted_at'] as String);
                } else {
                  createdAt = DateTime.now();
                }
              } catch (e) {
                createdAt = DateTime.now();
              }

              List<MessageReaction> reactions = [];
              try {
                final reactionsResponse = await _client
                    .from('message_reactions')
                    .select()
                    .eq('message_id', map['id']);

                for (final reactionData in reactionsResponse) {
                  try {
                    final reaction = MessageReaction.fromMap(reactionData);
                    reactions.add(reaction);
                  } catch (e) {
                    print('⚠️ Erro ao processar reação individual: $e');
                  }
                }
              } catch (e) {
                print('❌ Erro ao BUSCAR reações para ${map['id']}: $e');
              }

              return Message(
                id: map['id'] as String,
                conversationId: map['conversation_id'] as String,
                senderId: map['sender_id'] as String,
                content: content,
                type: type,
                createdAt: createdAt,
                reactions: reactions,
                isEdited: map['is_edited'] as bool? ?? false,
                isDeleted: map['is_deleted'] as bool? ?? false,
              );
            }));

            return messagesWithReactions;
          });
    } catch (e) {
      print('❌ Erro GERAL na subscription: $e');
      return Stream.value([]);
    }
  }

  Future<void> sendTextMessage(
      String conversationId, String senderId, String text) async {
    try {
      final id = _uuid.v4();

      await _client.from('messages').insert({
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': text,
        'type': 'text',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      print('✅ Mensagem enviada: $text');
    } catch (e) {
      print('❌ Erro ao enviar mensagem: $e');
      rethrow;
    }
  }

  Future<String> uploadImage(Uint8List bytes, String filename) async {
    return await _storageService.uploadMessageImage(bytes, filename);
  }

  Future<void> sendImageMessage(String conversationId, String senderId,
      Uint8List imageBytes, String filename) async {
    try {
      print('📤 Iniciando envio de imagem...');

      // ✅ CORREÇÃO: Converter para Uint8List regular se necessário
      final Uint8List bytes = Uint8List.fromList(imageBytes);

      // Verificar se o bucket está pronto antes do upload
      await _storageService.ensureBucketReady();

      final imageUrl =
          await _storageService.uploadMessageImage(bytes, filename);

      final id = _uuid.v4();
      await _client.from('messages').insert({
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': imageUrl,
        'type': 'image',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      print('✅ Mensagem de imagem enviada: $imageUrl');
    } catch (e) {
      print('❌ Erro crítico ao enviar imagem: $e');
      rethrow;
    }
  }

  Future<void> addReaction(
      String messageId, String userId, String emoji) async {
    try {
      print('😊 Adicionando reação: $emoji à mensagem: $messageId');

      await _client.rpc('add_message_reaction', params: {
        'p_message_id': messageId,
        'p_user_id': userId,
        'p_emoji': emoji,
      });

      print('✅ Reação adicionada via função');

      notifyListeners();
    } catch (e) {
      print('❌ Erro ao adicionar reação: $e');
      rethrow;
    }
  }

  Future<void> removeReaction(String reactionId) async {
    try {
      print('🗑️ Removendo reação: $reactionId');

      await _client.from('message_reactions').delete().eq('id', reactionId);

      print('✅ Reação removida com sucesso');
    } catch (e) {
      print('❌ Erro ao remover reação: $e');
      rethrow;
    }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    try {
      print('✏️ Editando mensagem: $messageId');
      print('📝 Novo conteúdo: $newContent');

      final updateData = {
        'content': newContent,
        'is_edited': true,
      };

      try {
        updateData['updated_at'] = DateTime.now().toUtc().toIso8601String();
      } catch (e) {
        print('⚠️ Coluna updated_at não disponível');
      }

      await _client.from('messages').update(updateData).eq('id', messageId);

      print('✅ Mensagem editada com sucesso');
    } catch (e) {
      print('❌ Erro ao editar mensagem: $e');
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      print('🗑️ Excluindo mensagem: $messageId');

      await _client.from('messages').delete().eq('id', messageId);

      print('✅ Mensagem excluída com sucesso');

      notifyListeners();
    } catch (e) {
      print('❌ Erro ao excluir mensagem: $e');
      rethrow;
    }
  }

  Future<bool> isMessageDeleted(String messageId) async {
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('id', messageId)
          .maybeSingle();

      return response == null;
    } catch (e) {
      return true;
    }
  }

  Future<String> createConversation(String name, bool isGroup, bool isPublic,
      List<String> participantIds) async {
    try {
      final conversationId = _uuid.v4();
      final currentUserId = _client.auth.currentUser!.id;

      print('🆕 Criando conversa: $name');
      print('👥 Participantes: $participantIds');

      await _client.from('conversations').insert({
        'id': conversationId,
        'name': name,
        'is_group': isGroup,
        'is_public': isPublic,
        'created_by': currentUserId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      for (final userId in participantIds) {
        await _client.from('participants').insert({
          'id': _uuid.v4(),
          'conversation_id': conversationId,
          'user_id': userId,
          'joined_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      await sendTextMessage(conversationId, currentUserId,
          isGroup ? 'Grupo "$name" criado! 🎉' : 'Conversa iniciada! 👋');

      print('✅ Conversa criada com sucesso: $conversationId');
      return conversationId;
    } catch (e) {
      print('❌ Erro ao criar conversa: $e');
      rethrow;
    }
  }

  void refreshMessages() {
    print('🔄 Forçando atualização das mensagens...');
    notifyListeners();
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    super.dispose();
  }
}
