class Conversation {
  final String id;
  final String? name;
  final bool isGroup;
  final bool isPublic;
  final String createdBy;
  final DateTime createdAt;
  final List<Map<String, dynamic>> participants;

  Conversation({
    required this.id,
    this.name,
    this.isGroup = false,
    this.isPublic = true,
    required this.createdBy,
    required this.createdAt,
    this.participants = const [],
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      name: map['name'] as String?,
      isGroup: map['is_group'] as bool? ?? false,
      isPublic: map['is_public'] as bool? ?? true,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}