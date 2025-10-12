import 'package:flutter/material.dart';
import '../models/social_user.dart';
import '../services/social_repository.dart';

class UserProfileView extends StatelessWidget {
  final String userId;
  final SocialRepository repository;
  const UserProfileView({super.key, required this.userId, required this.repository});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SocialUser?>(
      future: repository.getUser(userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final name = user?.displayName ?? 'Kullanıcı';
        final avatarUrl = user?.avatarUrl;
        return Scaffold(
          appBar: AppBar(title: Text(name)),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Kullanıcı ID: $userId', style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        );
      },
    );
  }
}


