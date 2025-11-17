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
    return Message(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String,
      type: map['type'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      isEdited: map['is_edited'] as bool? ?? false,
      isDeleted: map['is_deleted'] as bool? ?? false,
    );
  }

  Message copyWith({
    List<MessageReaction>? reactions,
    bool? isEdited,
    bool? isDeleted,
  }) {
    return Message(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      content: content,
      type: type,
      createdAt: createdAt,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
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
    return MessageReaction(
      id: map['id'] as String,
      messageId: map['message_id'] as String,
      userId: map['user_id'] as String,
      emoji: map['emoji'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}