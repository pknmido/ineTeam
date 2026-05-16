import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/auth_provider.dart';
import '../../../features/chat/chat_provider.dart';
import '../../../data/models/chat_model.dart';
import '../../../data/services/user_service.dart';
import '../../../data/models/user_model.dart';
import '../../../core/utils/helpers.dart';
import '../../widgets/player_avatar.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final currentUserId = context.read<AuthProvider>().userId;
    final theme = Theme.of(context);

    // Get chat info
    final chat = chatProvider.chats.firstWhere(
      (c) => c.id == widget.chatId,
      orElse: () => ChatModel(
        id: widget.chatId,
        creatorId: '',
        participantIds: [],
        lastMessage: '',
        lastMessageTime: DateTime.now(),
      ),
    );

    if (chat.participantIds.isEmpty && widget.chatId.isNotEmpty) {
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: chat.isGroup ? () => _showGroupInfo(context, chat) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chat.isGroup ? chat.groupName ?? 'Group' : 'Chat',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (chat.isGroup)
                Text(
                  'Tap for info',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark 
            ? Colors.black.withAlpha(50) 
            : Colors.grey.withAlpha(20),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: chatProvider.getChatMessages(widget.chatId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final messages = snapshot.data!;
                  if (messages.isEmpty) {
                    return const Center(child: Text('No messages yet. Start the conversation!'));
                  }
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == currentUserId;
                      final timeStr = Helpers.formatTime(message.timestamp);

                      return Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isMe && chat.isGroup)
                            Padding(
                              padding: const EdgeInsets.only(left: 12, bottom: 2),
                              child: FutureBuilder<UserModel?>(
                                future: UserService().getUserProfile(message.senderId),
                                builder: (context, snap) => Text(
                                  snap.data?.name ?? '...',
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
                              decoration: BoxDecoration(
                                color: isMe 
                                  ? const Color(0xFF25D366) // WhatsApp Green
                                  : const Color(0xFF34B7F1), // Modern Blue
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(16),
                                  topRight: const Radius.circular(16),
                                  bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                                  bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(10),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    message.text,
                                    style: const TextStyle(color: Colors.white, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(180),
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            
            // ── Modern Input Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 4,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                    onPressed: () => _showEmojiPicker(context),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark 
                          ? Colors.white.withAlpha(20) 
                          : Colors.grey.withAlpha(20),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 4,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF25D366),
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: () async {
                        final text = _messageController.text.trim();
                        if (text.isNotEmpty) {
                          _messageController.clear();
                          await chatProvider.sendMessage(widget.chatId, text);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmojiPicker(BuildContext context) {
    final emojis = ['😀', '😃', '😄', '😁', '😅', '😂', '🤣', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰', '😘', '😗', '😙', '😚', '😋', '😛', '😝', '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🤩', '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁', '😣', '😖', '😫', '😩', '🥺', '😢', '😭', '😤', '😠', '😡', '🤬', '🤯', '😳', '🥵', '🥶', '😱', '😨', '😰', '😥', '😓', '🤗', '🤔', '🤭', '🤫', '🤥', '😶', '😐', '😑', '😬', '🙄', '😯', '😦', '😧', '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕', '🤑', '🤠', '😈', '👿', '👹', '👺', '🤡', '👻', '💀', '☠️', '👽', '👾', '🤖', '🎃', '😺', '😸', '😹', '😻', '😼', '😽', '🙀', '😿', '😾'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 300,
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      _messageController.text += emojis[index];
                      Navigator.pop(context);
                    },
                    child: Center(
                      child: Text(
                        emojis[index],
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGroupInfo(BuildContext context, ChatModel chat) {
    final userService = UserService();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(chat.groupName ?? 'Group Info'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Members:', style: TextStyle(fontWeight: FontWeight.bold)),
                  if (chat.creatorId == context.read<AuthProvider>().userId)
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                      onPressed: () => _showAddMemberDialog(context, chat),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: chat.participantIds.length,
                  itemBuilder: (context, index) {
                    final uid = chat.participantIds[index];
                    final isCreator = uid == chat.creatorId;
                    final isAdmin = chat.creatorId == context.read<AuthProvider>().userId;

                    return FutureBuilder<UserModel?>(
                      future: userService.getUserProfile(uid),
                      builder: (context, snapshot) {
                        final user = snapshot.data;
                        final name = user?.name ?? 'Loading...';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: PlayerAvatar(
                            name: name,
                            imageUrl: user?.profilePictureUrl,
                            radius: 18,
                          ),
                          title: Text(name),
                          onTap: () => context.push('/user/$uid'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCreator)
                                Chip(
                                  label: const Text('Admin', style: TextStyle(fontSize: 10)),
                                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                                ),
                              if (isAdmin && !isCreator)
                                IconButton(
                                  icon: const Icon(Icons.person_remove, size: 20, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await _showConfirmDialog(context, 'Kick Member', 'Are you sure you want to remove $name from the group?');
                                    if (confirm == true && context.mounted) {
                                      await context.read<ChatProvider>().kickMember(chat.id, uid);
                                    }
                                  },
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(),
              if (chat.creatorId == context.read<AuthProvider>().userId)
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete Group', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final confirm = await _showConfirmDialog(context, 'Delete Group', 'Are you sure you want to delete this group for everyone?');
                    if (confirm == true && context.mounted) {
                      await context.read<ChatProvider>().deleteGroup(chat.id);
                      if (context.mounted) {
                        Navigator.pop(context); // Close dialog
                        context.pop(); // Go back from chat
                      }
                    }
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.exit_to_app, color: Colors.red),
                  title: const Text('Leave Group', style: TextStyle(color: Colors.red)),
                  onTap: () async {
                    final confirm = await _showConfirmDialog(context, 'Leave Group', 'Are you sure you want to leave this group?');
                    if (confirm == true && context.mounted) {
                      await context.read<ChatProvider>().leaveGroup(chat.id);
                      if (context.mounted) {
                        Navigator.pop(context); // Close dialog
                        context.pop(); // Go back from chat
                      }
                    }
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, ChatModel chat) {
    final authProvider = context.read<AuthProvider>();
    final friends = authProvider.userProfile?.friends ?? [];
    final existingMembers = chat.participantIds.toSet();
    final potentialNewMembers = friends.where((f) => !existingMembers.contains(f)).toList();

    if (potentialNewMembers.isEmpty) {
      Helpers.showSnackBar(context, 'No new friends to add!');
      return;
    }

    final selectedIds = <String>{};
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateBuilder) => AlertDialog(
          title: const Text('Add Members'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: potentialNewMembers.length,
              itemBuilder: (context, index) {
                final uid = potentialNewMembers[index];
                return FutureBuilder<UserModel?>(
                  future: UserService().getUserProfile(uid),
                  builder: (context, snapshot) {
                    final name = snapshot.data?.name ?? '...';
                    return CheckboxListTile(
                      title: Text(name),
                      value: selectedIds.contains(uid),
                      onChanged: (val) {
                        setStateBuilder(() {
                          if (val == true) selectedIds.add(uid);
                          else selectedIds.remove(uid);
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: (selectedIds.isEmpty || isSubmitting) ? null : () async {
                setStateBuilder(() => isSubmitting = true);
                try {
                  await context.read<ChatProvider>().addMembers(chat.id, selectedIds.toList());
                  if (context.mounted) {
                    Navigator.pop(context);
                    Helpers.showSnackBar(context, 'Members added!');
                  }
                } catch (e) {
                  if (context.mounted) {
                    setStateBuilder(() => isSubmitting = false);
                    Helpers.showSnackBar(context, 'Error adding members: $e', isError: true);
                  }
                }
              },
              child: isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(BuildContext context, String title, String body) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(title, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
