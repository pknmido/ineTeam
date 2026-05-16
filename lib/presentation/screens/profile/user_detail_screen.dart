import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/user_service.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/notifications/notification_provider.dart';
import '../../../features/chat/chat_provider.dart';
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
                  Column(
                    children: [
                      _buildActionButton(context, theme, profile),
                      if (context.watch<AuthProvider>().userProfile?.friends.contains(userId) ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final chat = await context.read<ChatProvider>().getOrCreateDirectChat(userId);
                                if (context.mounted) {
                                  context.push('/chat/${chat.id}');
                                }
                              },
                              icon: const Icon(Icons.message_outlined),
                              label: const Text('Message'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: theme.colorScheme.primary),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ),
                    ],
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

  Widget _buildActionButton(BuildContext context, ThemeData theme, UserModel profile) {
    final authProvider = context.watch<AuthProvider>();
    final currentUser = authProvider.userProfile;
    if (currentUser == null) return const SizedBox.shrink();

    final isFriend = currentUser.friends.contains(userId);
    final isPending = currentUser.sentFriendRequests.contains(userId);

    if (isFriend) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _showRemoveFriendConfirmation(context, profile),
          icon: const Icon(Icons.person_remove),
          label: const Text('Remove Friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    if (isPending) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: null, // Disabled
          icon: const Icon(Icons.hourglass_empty),
          label: const Text('Request Pending'),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: () async {
          final authId = authProvider.userId;
          if (authId == null) return;

          await _userService.updateUserProfile(authId, {
            'sentFriendRequests': FieldValue.arrayUnion([userId]),
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
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add Friend'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  void _showRemoveFriendConfirmation(BuildContext context, UserModel profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend?'),
        content: Text('Are you sure you want to remove ${profile.name} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final authId = Provider.of<AuthProvider>(context, listen: false).userId;
              if (authId != null) {
                await _userService.unfriend(authId, profile.uid);
                if (context.mounted) {
                  Navigator.pop(context);
                  Helpers.showSnackBar(context, 'Removed ${profile.name} from friends.');
                }
              }
            },
            child: Text('Remove', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
