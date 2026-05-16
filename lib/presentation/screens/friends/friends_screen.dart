import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/profile/user_provider.dart';
import '../../../features/chat/chat_provider.dart';
import '../../../features/notifications/notification_provider.dart';
import '../../../data/services/user_service.dart';
import '../../../data/models/user_model.dart';
import '../../../core/utils/helpers.dart';
import '../../widgets/player_avatar.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final UserService _userService = UserService();
  List<UserModel> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final userProfile = context.read<AuthProvider>().userProfile;
    if (userProfile != null && userProfile.friends.isNotEmpty) {
      final friends = await _userService.getUsersByIds(userProfile.friends);
      if (mounted) {
        setState(() {
          _friends = friends;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddFriendDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Friend'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Enter username or email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final query = controller.text.trim();
              if (query.isEmpty) return;

              final allUsersQuery = await _userService.userProfileStream(query).first; // This won't work well if query is email/username. We need to query by name or email.
              
              // To properly query by name/email, we need a method in UserService. Since we don't want to change much, let's just use firestore directly here or add a method.
              try {
                final snapshot = await _userService.usersCollection
                    .where('email', isEqualTo: query)
                    .get();
                
                if (snapshot.docs.isEmpty) {
                  final nameSnapshot = await _userService.usersCollection
                      .where('name', isEqualTo: query)
                      .get();
                  if (nameSnapshot.docs.isEmpty) {
                    if (context.mounted) {
                      Helpers.showSnackBar(context, 'No user found.', isError: true);
                    }
                    return;
                  }
                  _sendRequest(nameSnapshot.docs.first.id);
                } else {
                  _sendRequest(snapshot.docs.first.id);
                }
              } catch (e) {
                 if (context.mounted) {
                    Helpers.showSnackBar(context, 'Error finding user.', isError: true);
                 }
              }
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendRequest(String targetId) async {
    final authId = context.read<AuthProvider>().userId;
    if (authId == targetId) {
      if (mounted) Helpers.showSnackBar(context, 'Cannot add yourself!', isError: true);
      return;
    }
    
    final currentUser = context.read<AuthProvider>().userProfile;
    if (currentUser!.friends.contains(targetId)) {
      if (mounted) Helpers.showSnackBar(context, 'Already friends!', isError: true);
      return;
    }
    
    // Add targetId to sent requests
    await _userService.updateUserProfile(authId, {
      'sentFriendRequests': [...currentUser.sentFriendRequests, targetId],
    });

    // Send notification
    await context.read<NotificationProvider>().sendNotification(
      userId: targetId,
      title: 'New Friend Request',
      body: '${currentUser.name} sent you a friend request.',
      type: 'friend_request',
      data: {'requesterId': authId},
    );

    if (mounted) {
      Navigator.pop(context);
      Helpers.showSnackBar(context, 'Friend request sent!');
    }
  }

  void _showCreateGroupDialog() {
    final nameController = TextEditingController();
    final selectedFriends = <String>{};

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBuilder) {
          return AlertDialog(
            title: const Text('Create Group'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(hintText: 'Group Name'),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Members:'),
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: _friends.map((friend) {
                        final isSelected = selectedFriends.contains(friend.uid);
                        return CheckboxListTile(
                          title: Text(friend.name),
                          value: isSelected,
                          onChanged: (val) {
                            setStateBuilder(() {
                              if (val == true) {
                                selectedFriends.add(friend.uid);
                              } else {
                                selectedFriends.remove(friend.uid);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty || selectedFriends.isEmpty) {
                    Helpers.showSnackBar(context, 'Enter name and select at least 1 friend', isError: true);
                    return;
                  }
                  final chat = await context.read<ChatProvider>().createGroupChat(name, selectedFriends.toList());
                  if (context.mounted) {
                    Navigator.pop(context);
                    context.push('/chat/${chat.id}');
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Friends & Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Create Group',
            onPressed: _showCreateGroupDialog,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add Friend',
            onPressed: _showAddFriendDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (_friends.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Friends', style: theme.textTheme.titleLarge),
                  ),
                ..._friends.map((friend) => ListTile(
                      leading: PlayerAvatar(
                        name: friend.name,
                        imageUrl: friend.profilePictureUrl,
                        radius: 20,
                      ),
                      title: Text(friend.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.message),
                        onPressed: () async {
                          final chat = await context.read<ChatProvider>().getOrCreateDirectChat(friend.uid);
                          if (context.mounted) {
                            context.push('/chat/${chat.id}');
                          }
                        },
                      ),
                      onTap: () {
                        // TODO: Open profile
                      },
                    )),
                if (chatProvider.chats.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Recent Chats', style: theme.textTheme.titleLarge),
                  ),
                ...chatProvider.chats.map((chat) {
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(chat.isGroup ? Icons.group : Icons.chat),
                    ),
                    title: Text(chat.isGroup ? chat.groupName ?? 'Group' : 'Direct Chat'),
                    subtitle: Text(chat.lastMessage),
                    onTap: () => context.push('/chat/${chat.id}'),
                  );
                }),
              ],
            ),
    );
  }
}
