import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/profile_service.dart';

class ProfileAvatar extends StatelessWidget {
  final double radius;
  final VoidCallback? onTap;
  final bool showEditIndicator;

  const ProfileAvatar({
    super.key,
    this.radius = 50,
    this.onTap,
    this.showEditIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileService>(
      builder: (context, profileService, child) {
        final profile = profileService.currentProfile;
        final avatarUrl = profile?['avatar_url'];
        
        return GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              // Avatar com cache busting
              CircleAvatar(
                radius: radius,
                backgroundImage: _getAvatarImage(avatarUrl),
                child: _getAvatarImage(avatarUrl) == null
                    ? Icon(
                        Icons.person,
                        size: radius * 0.8,
                        color: Colors.white,
                      )
                    : null,
              ),
              
              // Indicador de edição (câmera)
              if (showEditIndicator && onTap != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: radius * 0.25,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  ImageProvider? _getAvatarImage(String? avatarUrl) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      
      final cacheBusterUrl = '$avatarUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      return NetworkImage(cacheBusterUrl);
    }
    return null;
  }
}