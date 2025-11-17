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
      id: map['id'] as String,
      email: map['email'] as String,
      fullName: map['full_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      online: map['online'] as bool? ?? false,
      lastSeen: map['last_seen'] != null 
          ? DateTime.parse(map['last_seen'] as String)
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