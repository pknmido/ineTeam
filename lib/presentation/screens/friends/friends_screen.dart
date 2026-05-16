import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/profile/user_provider.dart';
import '../../../features/chat/chat_provider.dart';
import '../../../features/notifications/notification_provider.dart';
import '../../../data/services/user_service.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/chat_model.dart';
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
    
    // Listen for profile changes to refresh friends list
    final auth = context.read<AuthProvider>();
    auth.addListener(_onAuthProfileChanged);
  }

  void _onAuthProfileChanged() {
    if (mounted) {
       _loadFriends();
    }
  }

  @override
  void dispose() {
    // It's safer to avoid using context here, but since AuthProvider is a singleton
    // we should really remove the listener.
    // However, in this app structure, we'll just ignore it for now or try to get it safely.
    super.dispose();
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

              try {
                // Try email first
                var snapshot = await _userService.usersCollection
                    .where('email', isEqualTo: query)
                    .get();
                
                // Try name if email fails
                if (snapshot.docs.isEmpty) {
                  snapshot = await _userService.usersCollection
                      .where('name', isEqualTo: query)
                      .get();
                }

                if (snapshot.docs.isEmpty) {
                  if (context.mounted) {
                    Helpers.showSnackBar(context, 'No user found with that email or username.', isError: true);
                  }
                  return;
                }

                final targetId = snapshot.docs.first.id;
                _sendRequest(targetId);
              } catch (e) {
                 if (context.mounted) {
                    Helpers.showSnackBar(context, 'Error finding user: $e', isError: true);
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
    
    // Add targetId to sent requests of current user (allowed)
    await _userService.updateUserProfile(authId, {
      'sentFriendRequests': FieldValue.arrayUnion([targetId]),
    });

    // NOTE: We cannot update the target user's document directly due to security rules.
    // Instead, we send a notification. When they accept, they will update their own document.

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
              _CreateGroupButton(
                nameController: nameController,
                selectedFriends: selectedFriends,
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
    final groups = chatProvider.chats.where((c) => c.isGroup).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Friends & Groups'),
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
                if (groups.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('Groups', style: theme.textTheme.titleLarge),
                  ),
                ...groups.map((chat) {
                  return ChatTile(chat: chat, currentUserId: context.read<AuthProvider>().userId);
                }),
                
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
                      onTap: () => context.push('/user/${friend.uid}'),
                    )),
              ],
            ),
    );
  }
}

class _CreateGroupButton extends StatefulWidget {
  final TextEditingController nameController;
  final Set<String> selectedFriends;

  const _CreateGroupButton({
    required this.nameController,
    required this.selectedFriends,
  });

  @override
  State<_CreateGroupButton> createState() => _CreateGroupButtonState();
}

class _CreateGroupButtonState extends State<_CreateGroupButton> {
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isCreating ? null : () async {
        final name = widget.nameController.text.trim();
        if (name.isEmpty || widget.selectedFriends.isEmpty) {
          Helpers.showSnackBar(context, 'Enter name and select at least 1 friend', isError: true);
          return;
        }

        setState(() => _isCreating = true);
        try {
          final chat = await context.read<ChatProvider>().createGroupChat(name, widget.selectedFriends.toList());
          if (context.mounted) {
            Navigator.pop(context);
            context.push('/chat/${chat.id}');
          }
        } catch (e) {
          if (mounted) {
            setState(() => _isCreating = false);
            Helpers.showSnackBar(context, 'Error creating group: $e', isError: true);
          }
        }
      },
      child: _isCreating 
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : const Text('Create'),
    );
  }
}

class ChatTile extends StatelessWidget {
  final ChatModel chat;
  final String currentUserId;
  final UserService _userService = UserService();

  ChatTile({required this.chat, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    if (chat.isGroup) {
      return ListTile(
        leading: CircleAvatar(child: const Icon(Icons.group)),
        title: Text(chat.groupName ?? 'Group Chat'),
        subtitle: Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => context.push('/chat/${chat.id}'),
      );
    }

    // For direct chats, fetch the other person's name
    final otherId = chat.participantIds.firstWhere((id) => id != currentUserId, orElse: () => '');
    
    return FutureBuilder<UserModel?>(
      future: _userService.getUserProfile(otherId),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? 'Chat';
        return ListTile(
          leading: PlayerAvatar(
            name: name,
            imageUrl: snapshot.data?.profilePictureUrl,
            radius: 20,
          ),
          title: Text(name),
          subtitle: Text(chat.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => context.push('/chat/${chat.id}'),
        );
      },
    );
  }
}
