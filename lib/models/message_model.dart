class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String type;
  final DateTime createdAt;
  final List<MessageReaction> reactions;
  final bool isEdited;
  final bool isDeleted;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.createdAt,
    this.reactions = const [],
    this.isEdited = false,
    this.isDeleted = false,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    // Processar reações
    List<MessageReaction> reactions = [];
    final reactionsData = map['message_reactions'] as List<dynamic>?;
    if (reactionsData != null) {
      for (final reactionMap in reactionsData) {
        try {
          final reaction = MessageReaction.fromMap(reactionMap as Map<String, dynamic>);
          reactions.add(reaction);
        } catch (e) {
          print('⚠️ Erro ao processar reação: $e');
        }
      }
    }

    // Processar conteúdo e tipo
    String content = '';
    String type = 'text';

    if (map.containsKey('content') && map['content'] != null) {
      content = map['content'] as String;
    } else if (map.containsKey('payload')) {
      final payload = map['payload'] as Map<String, dynamic>?;
      content = payload?['content']?.toString() ?? '';
      type = payload?['type']?.toString() ?? 'text';
    }

    // Processar data de criação
    DateTime createdAt;
    try {
      if (map['created_at'] is String) {
        createdAt = DateTime.parse(map['created_at'] as String).toLocal();
      } else if (map['inserted_at'] is String) {
        createdAt = DateTime.parse(map['inserted_at'] as String).toLocal();
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      createdAt = DateTime.now();
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
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'content': content,
      'type': type,
      'created_at': createdAt.toUtc().toIso8601String(),
      'is_edited': isEdited,
      'is_deleted': isDeleted,
    };
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    String? type,
    DateTime? createdAt,
    List<MessageReaction>? reactions,
    bool? isEdited,
    bool? isDeleted,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }

  // Helper methods
  bool get hasReactions => reactions.isNotEmpty;

  List<MessageReaction> getReactionsByEmoji(String emoji) {
    return reactions.where((reaction) => reaction.emoji == emoji).toList();
  }

  bool hasUserReacted(String userId) {
    return reactions.any((reaction) => reaction.userId == userId);
  }

  MessageReaction? getUserReaction(String userId, String emoji) {
    return reactions.firstWhere(
      (reaction) => reaction.userId == userId && reaction.emoji == emoji,
      orElse: () => MessageReaction(
        id: '',
        messageId: '',
        userId: '',
        emoji: '',
        createdAt: DateTime.now(),
      ),
    );
  }

  Message withReactionAdded(MessageReaction reaction) {
    final newReactions = List<MessageReaction>.from(reactions)..add(reaction);
    return copyWith(reactions: newReactions);
  }

  Message withReactionRemoved(String reactionId) {
    final newReactions = reactions.where((r) => r.id != reactionId).toList();
    return copyWith(reactions: newReactions);
  }

  Message withReactionToggled(MessageReaction reaction) {
    final existingIndex = reactions.indexWhere((r) => 
        r.userId == reaction.userId && r.emoji == reaction.emoji);
    
    if (existingIndex != -1) {
      // Remove se já existe
      final newReactions = List<MessageReaction>.from(reactions)
        ..removeAt(existingIndex);
      return copyWith(reactions: newReactions);
    } else {
      // Adiciona se não existe
      final newReactions = List<MessageReaction>.from(reactions)..add(reaction);
      return copyWith(reactions: newReactions);
    }
  }

  @override
  String toString() {
    return 'Message(id: $id, content: $content, type: $type, reactions: ${reactions.length}, isEdited: $isEdited, isDeleted: $isDeleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.conversationId == conversationId &&
        other.senderId == senderId &&
        other.content == content &&
        other.type == type &&
        other.createdAt == createdAt &&
        other.reactions.length == reactions.length &&
        other.isEdited == isEdited &&
        other.isDeleted == isDeleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      conversationId,
      senderId,
      content,
      type,
      createdAt,
      reactions.length,
      isEdited,
      isDeleted,
    );
  }
}

class MessageReaction {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  MessageReaction({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  factory MessageReaction.fromMap(Map<String, dynamic> map) {
    DateTime createdAt;
    try {
      if (map['created_at'] is String) {
        createdAt = DateTime.parse(map['created_at'] as String).toLocal();
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      createdAt = DateTime.now();
    }

    return MessageReaction(
      id: map['id'] as String,
      messageId: map['message_id'] as String,
      userId: map['user_id'] as String,
      emoji: map['emoji'] as String,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  MessageReaction copyWith({
    String? id,
    String? messageId,
    String? userId,
    String? emoji,
    DateTime? createdAt,
  }) {
    return MessageReaction(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      userId: userId ?? this.userId,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'MessageReaction(id: $id, emoji: $emoji, userId: $userId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageReaction &&
        other.id == id &&
        other.messageId == messageId &&
        other.userId == userId &&
        other.emoji == emoji &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(id, messageId, userId, emoji, createdAt);
  }
}

// Extension para funcionalidades úteis
extension MessageListExtensions on List<Message> {
  List<Message> get visibleMessages =>
      where((message) => !message.isDeleted).toList();

  List<Message> get editedMessages =>
      where((message) => message.isEdited).toList();

  List<Message> get messagesWithReactions =>
      where((message) => message.hasReactions).toList();

  Message? findById(String messageId) {
    try {
      return firstWhere((message) => message.id == messageId);
    } catch (e) {
      return null;
    }
  }

  List<Message> getBySender(String senderId) =>
      where((message) => message.senderId == senderId).toList();

  List<Message> getByType(String type) =>
      where((message) => message.type == type).toList();

  List<Message> getImages() => getByType('image');

  List<Message> getTextMessages() => getByType('text');

  // Ordenar por data (mais recente primeiro)
  List<Message> sortedByDate({bool ascending = false}) {
    final sorted = List<Message>.from(this);
    sorted.sort((a, b) => ascending
        ? a.createdAt.compareTo(b.createdAt)
        : b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  // Agrupar mensagens por data
  Map<DateTime, List<Message>> groupByDate() {
    final grouped = <DateTime, List<Message>>{};
    
    for (final message in this) {
      final date = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );
      
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(message);
    }
    
    return grouped;
  }
}

// Extension para reactions
extension ReactionListExtensions on List<MessageReaction> {
  List<MessageReaction> getByEmoji(String emoji) =>
      where((reaction) => reaction.emoji == emoji).toList();

  List<MessageReaction> getByUser(String userId) =>
      where((reaction) => reaction.userId == userId).toList();

  bool hasUserReacted(String userId) =>
      any((reaction) => reaction.userId == userId);

  MessageReaction? getUserReaction(String userId, String emoji) {
    try {
      return firstWhere(
        (reaction) => reaction.userId == userId && reaction.emoji == emoji,
      );
    } catch (e) {
      return null;
    }
  }

  // Agrupar reações por emoji
  Map<String, List<MessageReaction>> groupByEmoji() {
    final grouped = <String, List<MessageReaction>>{};
    
    for (final reaction in this) {
      if (!grouped.containsKey(reaction.emoji)) {
        grouped[reaction.emoji] = [];
      }
      grouped[reaction.emoji]!.add(reaction);
    }
    
    return grouped;
  }

  // Contar reações por emoji
  Map<String, int> countByEmoji() {
    final counts = <String, int>{};
    
    for (final reaction in this) {
      counts[reaction.emoji] = (counts[reaction.emoji] ?? 0) + 1;
    }
    
    return counts;
  }
}