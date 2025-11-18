import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_config.dart';
import '../models/message_model.dart';
import 'storage_service.dart';
import 'package:uuid/uuid.dart';
import '../models/user_models.dart';

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

  Stream<List<AppUser>> participantsStream(String conversationId) {
    final stream = _client
        .from('participants')
        .stream(primaryKey: ['id']).eq('conversation_id', conversationId);

    return stream.asyncMap((rows) async {
      final users = await Future.wait(
        rows.map((p) async {
          final data = await _client
              .from('profiles')
              .select()
              .eq('id', p['user_id'])
              .maybeSingle();

          return AppUser.fromMap(data!);
        }),
      );

      return users;
    });
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

  Future<void> addUserToGroup(String conversationId, String userId) async {
    try {
      // ✅ CORREÇÃO: Verifica se usuário já está no grupo
      final isAlreadyInGroup = await isUserInGroup(conversationId, userId);
      if (isAlreadyInGroup) {
        print('⚠️ Usuário $userId já está no grupo $conversationId');
        return;
      }

      await _client.from('participants').insert({
        'id': _uuid.v4(),
        'conversation_id': conversationId,
        'user_id': userId,
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });

      print('✅ Usuário $userId adicionado ao grupo $conversationId');
    } catch (e) {
      // ✅ CORREÇÃO: Trata erro de duplicação silenciosamente
      if (e.toString().contains('duplicate key')) {
        print('⚠️ Usuário $userId já está no grupo (erro capturado)');
        return;
      }
      print("❌ Erro ao adicionar usuário ao grupo: $e");
      throw Exception("Erro ao adicionar usuário ao grupo");
    }
  }

  Future<void> addMembersToGroup(
      String conversationId, List<String> userIds) async {
    try {
      print(
          '👥 Adicionando ${userIds.length} membros ao grupo: $conversationId');

      for (final userId in userIds) {
        try {
          // ✅ CORREÇÃO: Verifica se usuário já está no grupo
          final isAlreadyInGroup = await isUserInGroup(conversationId, userId);
          if (!isAlreadyInGroup) {
            await _client.from('participants').insert({
              'id': _uuid.v4(),
              'conversation_id': conversationId,
              'user_id': userId,
              'joined_at': DateTime.now().toUtc().toIso8601String(),
            });
            print('✅ Usuário $userId adicionado');
          } else {
            print('⚠️ Usuário $userId já está no grupo');
          }
        } catch (e) {
          // Ignora erro de duplicação
          if (e.toString().contains('duplicate key')) {
            print('⚠️ Usuário $userId já está no grupo');
            continue;
          }
          rethrow;
        }
      }

      // Envia mensagem apenas se novos usuários foram adicionados
      final currentUserId = _client.auth.currentUser!.id;
      final newUsersCount = userIds.length;

      if (newUsersCount > 0) {
        if (newUsersCount == 1) {
          await sendTextMessage(conversationId, currentUserId,
              'Novo membro adicionado ao grupo! 👋');
        } else {
          await sendTextMessage(conversationId, currentUserId,
              '$newUsersCount novos membros adicionados ao grupo! 👥');
        }
      }

      print('✅ Operação de adição de membros concluída');
    } catch (e) {
      print('❌ Erro ao adicionar membros ao grupo: $e');
      rethrow;
    }
  }

  Future<bool> isUserInGroup(String conversationId, String userId) async {
    try {
      final response = await _client
          .from('participants')
          .select()
          .eq('conversation_id', conversationId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ Erro ao verificar participação do usuário: $e');
      return false;
    }
  }

  Future<List<AppUser>> getAvailableUsers(String conversationId) async {
    try {
      // Primeiro, busca os participantes atuais do grupo
      final currentParticipants = await _client
          .from('participants')
          .select('user_id')
          .eq('conversation_id', conversationId);

      final currentUserIds = currentParticipants
          .map<String>((p) => p['user_id'] as String)
          .toList();

      // Busca todos os usuários exceto os que já estão no grupo
      final allUsers =
          await _client.from('profiles').select().order('full_name');

      return allUsers
          .where((user) => !currentUserIds.contains(user['id'] as String))
          .map<AppUser>((u) => AppUser.fromMap(u))
          .toList();
    } catch (e) {
      print('❌ Erro ao buscar usuários disponíveis: $e');
      return [];
    }
  }

  Future<void> addReaction(
      String messageId, String userId, String emoji) async {
    try {
      print('😊 Adicionando reação: $emoji à mensagem: $messageId');

      // Verifica se já existe uma reação igual do mesmo usuário
      final existingReaction = await _client
          .from('message_reactions')
          .select()
          .eq('message_id', messageId)
          .eq('user_id', userId)
          .eq('emoji', emoji)
          .maybeSingle();

      if (existingReaction != null) {
        // Se já existe, remove a reação (toggle)
        await _client
            .from('message_reactions')
            .delete()
            .eq('id', existingReaction['id'] as String);
        print('🗑️ Reação removida (toggle)');
      } else {
        // Se não existe, adiciona a reação
        await _client.from('message_reactions').insert({
          'id': _uuid.v4(),
          'message_id': messageId,
          'user_id': userId,
          'emoji': emoji,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
        print('✅ Reação adicionada');
      }

      notifyListeners();
    } catch (e) {
      print('❌ Erro ao adicionar/remover reação: $e');
      rethrow;
    }
  }

  Future<List<AppUser>> getAllUsers() async {
    try {
      final data = await _client.from('profiles').select().order('full_name');

      return data.map<AppUser>((u) {
        // ✅ CORREÇÃO: Tratamento seguro para campos null
        return AppUser(
          id: u['id'] as String? ?? '', // ✅ Evita erro de null
          email: u['email'] as String? ?? '',
          fullName: u['full_name'] as String?,
          avatarUrl: u['avatar_url'] as String?,
          online: u['online'] as bool? ?? false,
          lastSeen: u['last_seen'] != null
              ? DateTime.tryParse(u['last_seen'] as String)
              : null,
        );
      }).toList();
    } catch (e) {
      print("❌ Erro ao buscar usuários: $e");
      return [];
    }
  }

  Future<void> removeReaction(String reactionId) async {
    try {
      print('🗑️ Removendo reação: $reactionId');

      await _client.from('message_reactions').delete().eq('id', reactionId);

      print('✅ Reação removida com sucesso');
      notifyListeners();
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
      notifyListeners();
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

      // ✅ CORREÇÃO: Verifica se já existe conversa com esses participantes
      if (!isGroup && participantIds.length == 1) {
        // Para conversas 1:1, verifica se já existe
        final existingConversation = await _findExistingConversation(
            currentUserId, participantIds.first);
        if (existingConversation != null) {
          print('✅ Conversa já existe: $existingConversation');
          return existingConversation;
        }
      }

      await _client.from('conversations').insert({
        'id': conversationId,
        'name': name,
        'is_group': isGroup,
        'is_public': isPublic,
        'created_by': currentUserId,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      // ✅ CORREÇÃO: Remove duplicatas e adiciona criador
      final allParticipants = {...participantIds, currentUserId}.toList();

      for (final userId in allParticipants) {
        try {
          await _client.from('participants').insert({
            'id': _uuid.v4(),
            'conversation_id': conversationId,
            'user_id': userId,
            'joined_at': DateTime.now().toUtc().toIso8601String(),
          });
        } catch (e) {
          // Ignora erro de duplicação (usuário já está no grupo)
          if (e.toString().contains('duplicate key')) {
            print('⚠️ Usuário $userId já está na conversa');
            continue;
          }
          rethrow;
        }
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

// ✅ NOVO MÉTODO: Encontrar conversa existente para 1:1
  Future<String?> _findExistingConversation(String user1, String user2) async {
    try {
      final response = await _client
          .from('participants')
          .select('conversation_id')
          .inFilter('user_id', [user1, user2]).eq(
              'conversations.is_group', false);

      // Agrupa por conversation_id e conta participantes
      final conversationCounts = <String, int>{};
      for (final participant in response) {
        final convId = participant['conversation_id'] as String;
        conversationCounts[convId] = (conversationCounts[convId] ?? 0) + 1;
      }

      // Encontra conversas com exatamente 2 participantes (1:1)
      for (final entry in conversationCounts.entries) {
        if (entry.value == 2) {
          return entry.key;
        }
      }

      return null;
    } catch (e) {
      print('❌ Erro ao buscar conversa existente: $e');
      return null;
    }
  }
}
