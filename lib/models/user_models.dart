class AppUser {
  final String id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final bool online;
  final DateTime? lastSeen;

  AppUser({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.online = false,
    this.lastSeen,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      // ✅ CORREÇÃO: Proteção contra nulos
      // Se 'id' vier nulo, converte para string vazia.
      id: map['id']?.toString() ?? '', 
      
      // Se 'email' vier nulo, coloca um texto padrão
      email: map['email']?.toString() ?? 'Sem email',
      
      fullName: map['full_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      online: map['online'] as bool? ?? false,
      
      // ✅ CORREÇÃO: DateTime.tryParse é mais seguro que parse
      lastSeen: map['last_seen'] != null 
          ? DateTime.tryParse(map['last_seen'].toString()) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'online': online,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }
}