import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/user_service.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/notifications/notification_provider.dart';
import '../../widgets/player_avatar.dart';
import '../../widgets/skill_indicator.dart';
import '../../../core/utils/helpers.dart';

class UserDetailScreen extends StatelessWidget {
  final String userId;
  final UserService _userService = UserService();

  UserDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = context.read<AuthProvider>().userId;
    final isMe = currentUserId == userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Profile'),
      ),
      body: FutureBuilder<UserModel?>(
        future: _userService.getUserProfile(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('User not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                PlayerAvatar(
                  name: profile.name,
                  imageUrl: profile.profilePictureUrl,
                  radius: 50,
                  skillLevel: profile.skillLevel,
                ),
                const SizedBox(height: 16),
                Text(
                  profile.name,
                  style: theme.textTheme.displayMedium,
                ),
                const SizedBox(height: 24),

                if (!isMe)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final authId = context.read<AuthProvider>().userId;
                        final currentUser = context.read<AuthProvider>().userProfile;
                        if (currentUser != null && !currentUser.friends.contains(userId)) {
                          await _userService.updateUserProfile(authId, {
                            'sentFriendRequests': [...currentUser.sentFriendRequests, userId],
                          });
                          await context.read<NotificationProvider>().sendNotification(
                            userId: userId,
                            title: 'New Friend Request',
                            body: '${currentUser.name} sent you a friend request.',
                            type: 'friend_request',
                            data: {'requesterId': authId},
                          );
                          if (context.mounted) {
                            Helpers.showSnackBar(context, 'Friend request sent!');
                          }
                        }
                      },
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Friend'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Skill Ratings',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 12),
                if (profile.sports.isNotEmpty)
                  ...profile.sports.map((sport) {
                    final rating = profile.ratingForSport(sport);
                    final color = Helpers.sportColor(sport);
                    final skillColor = rating != null ? Helpers.skillColor(rating) : Colors.grey;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.withAlpha(25),
                              color.withAlpha(8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color.withAlpha(40)),
                        ),
                        child: Row(
                          children: [
                            Icon(Helpers.sportIcon(sport), size: 24, color: color),
                            const SizedBox(width: 12),
                            Text(
                              sport,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            SkillIndicator(
                              skillLevel: rating,
                              size: 36,
                              showLabel: false,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  rating != null ? '$rating/100' : 'Unrated',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: skillColor,
                                  ),
                                ),
                                if (rating != null)
                                  Text(
                                    Helpers.skillLabel(rating),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: skillColor.withAlpha(200),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  })
                else
                  const Text('No sports listed.'),
              ],
            ),
          );
        },
      ),
    );
  }
}
